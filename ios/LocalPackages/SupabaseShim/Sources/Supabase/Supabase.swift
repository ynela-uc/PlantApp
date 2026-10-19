import Foundation
import Security

// A real Supabase client, written against Supabase's documented REST (PostgREST),
// Auth (GoTrue), and Storage HTTP APIs via URLSession — not the official SDK.
//
// Why this exists: this project's Xcode (14.2, Swift 5.7, the max Xcode supports on
// macOS 12 Monterey) cannot resolve the official supabase-swift package. Every release
// in PlantApp's required range (2.55.4..<3.0.0) declares swift-tools-version 6.1, which
// Swift 5.7 cannot even parse — there's no in-range version old enough to resolve here.
//
// This is not a stand-in: it performs the same HTTP calls the SDK would, against the
// same backend, and persists the session the same way (Keychain). It keeps the exact
// public API PlantApp's own code already calls (SupabaseClient.from/rpc/auth/storage),
// so no other file needed to change. It works on any Xcode version — on a Mac with
// Xcode 16+, you can keep this or switch project.yml back to the official package
// (see the comment there); either works.

public enum SupabaseError: LocalizedError {
    case http(Int, String)
    case decoding(Error)
    case noSession
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .http(let code, let message): return "\(message) (\(code))"
        case .decoding(let error): return "Decoding failed: \(error)"
        case .noSession: return "Not signed in"
        case .invalidResponse: return "Invalid response from server"
        }
    }
}

// MARK: - JSON (for signUp's `data` dictionary)

public enum AnyJSON: Sendable, Encodable {
    case string(String)
    case double(Double)
    case integer(Int)
    case bool(Bool)
    case null

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - Auth models

public struct User: Sendable, Codable {
    public let id: UUID
}

public struct Session: Sendable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let user: User
}

public struct AuthResponse: Sendable {
    public let session: Session?
    public let user: User
}

public struct UserAttributes: Sendable {
    public var email: String?
    public var password: String?
    public init(email: String? = nil, password: String? = nil) {
        self.email = email
        self.password = password
    }

    fileprivate var jsonBody: [String: String] {
        var body: [String: String] = [:]
        if let email { body["email"] = email }
        if let password { body["password"] = password }
        return body
    }
}

public enum AuthFlowType: Sendable { case implicit, pkce }

// MARK: - Client options (kept for call-site compatibility; the implicit flow needs
// no client-side behavior beyond the redirect_to already passed on each call).

public struct SupabaseClientOptions: Sendable {
    public struct AuthOptions: Sendable {
        public var redirectToURL: URL?
        public var flowType: AuthFlowType
        public var emitLocalSessionAsInitialSession: Bool
        public init(
            redirectToURL: URL? = nil,
            flowType: AuthFlowType = .pkce,
            emitLocalSessionAsInitialSession: Bool = false
        ) {
            self.redirectToURL = redirectToURL
            self.flowType = flowType
            self.emitLocalSessionAsInitialSession = emitLocalSessionAsInitialSession
        }
    }

    public var auth: AuthOptions
    public init(auth: AuthOptions = AuthOptions()) {
        self.auth = auth
    }
}

// MARK: - Keychain-backed session storage

private enum SessionStore {
    static let service = "com.plantapp.supabase.session"

    static func save(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Reads the `exp` claim out of a JWT without verifying its signature — used only to
/// know when to refresh, never to trust the token's contents.
private func jwtExpiry(_ token: String) -> Date? {
    let parts = token.split(separator: ".")
    guard parts.count == 3 else { return nil }
    var base64 = String(parts[1])
    while base64.count % 4 != 0 { base64 += "=" }
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = json["exp"] as? Double else { return nil }
    return Date(timeIntervalSince1970: exp)
}

// MARK: - Low-level HTTP core shared by Auth / PostgREST / Storage

final class SupabaseHTTP: @unchecked Sendable {
    let baseURL: URL
    let anonKey: String
    private var session: Session?
    private let lock = NSLock()

    init(baseURL: URL, anonKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.session = SessionStore.load()
    }

    var currentUser: User? {
        lock.lock(); defer { lock.unlock() }
        return session?.user
    }

    func setSession(_ newSession: Session?) {
        lock.lock()
        session = newSession
        lock.unlock()
        if let newSession {
            SessionStore.save(newSession)
        } else {
            SessionStore.clear()
        }
    }

    private func snapshotSession() -> Session? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    /// Returns a live session, refreshing it first if it's at or near expiry.
    func validSession() async throws -> Session {
        guard let current = snapshotSession() else { throw SupabaseError.noSession }
        if current.expiresAt.timeIntervalSinceNow > 30 {
            return current
        }
        return try await refresh(using: current.refreshToken)
    }

    @discardableResult
    func refresh(using refreshToken: String) async throws -> Session {
        let token = try await tokenRequest(grantType: "refresh_token", body: ["refresh_token": refreshToken])
        setSession(token)
        return token
    }

    /// The bearer token for authenticated calls: the live session's access token if
    /// signed in, otherwise the public anon key (works for anonymous/public-read RLS).
    func bearerToken() async -> String {
        if let token = try? await validSession() {
            return token.accessToken
        }
        return anonKey
    }

    // MARK: Auth HTTP

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Double?
        let expires_at: Double?
        let user: UserPayload?
    }

    private struct UserPayload: Decodable {
        let id: String
    }

    private func tokenRequest(grantType: String, body: [String: String]) async throws -> Session {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/token"))
        request.url = URL(string: request.url!.absoluteString + "?grant_type=\(grantType)")
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await send(request)
        let decoded = try decode(TokenResponse.self, from: data)
        let expiresAt = decoded.expires_at.map { Date(timeIntervalSince1970: $0) }
            ?? decoded.expires_in.map { Date().addingTimeInterval($0) }
            ?? jwtExpiry(decoded.access_token)
            ?? Date().addingTimeInterval(3600)
        guard let userIdString = decoded.user?.id, let uuid = UUID(uuidString: userIdString) else {
            throw SupabaseError.invalidResponse
        }
        return Session(accessToken: decoded.access_token, refreshToken: decoded.refresh_token, expiresAt: expiresAt, user: User(id: uuid))
    }

    func signIn(email: String, password: String) async throws {
        let session = try await tokenRequest(grantType: "password", body: ["email": email, "password": password])
        setSession(session)
    }

    func signUp(email: String, password: String, data: [String: AnyJSON]?) async throws -> AuthResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/signup"))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable {
            let email: String
            let password: String
            let data: [String: AnyJSON]?
        }
        request.httpBody = try JSONEncoder().encode(Body(email: email, password: password, data: data))

        let (responseData, _) = try await send(request)

        struct SignUpResponse: Decodable {
            let id: String?
            let access_token: String?
            let refresh_token: String?
            let expires_in: Double?
            let user: UserPayload?
        }
        let decoded = try decode(SignUpResponse.self, from: responseData)
        guard let userId = decoded.id ?? decoded.user?.id, let uuid = UUID(uuidString: userId) else {
            throw SupabaseError.invalidResponse
        }
        let user = User(id: uuid)

        var session: Session?
        if let accessToken = decoded.access_token, let refreshToken = decoded.refresh_token {
            let expiresAt = decoded.expires_in.map { Date().addingTimeInterval($0) }
                ?? jwtExpiry(accessToken)
                ?? Date().addingTimeInterval(3600)
            session = Session(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt, user: user)
            setSession(session)
        }
        return AuthResponse(session: session, user: user)
    }

    func resetPasswordForEmail(_ email: String, redirectTo: URL?) async throws {
        var urlString = baseURL.appendingPathComponent("/auth/v1/recover").absoluteString
        if let redirectTo {
            var components = URLComponents(string: urlString)!
            components.queryItems = [URLQueryItem(name: "redirect_to", value: redirectTo.absoluteString)]
            urlString = components.url!.absoluteString
        }
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        _ = try await send(request)
    }

    @discardableResult
    func setSession(accessToken: String, refreshToken: String) async throws -> Session {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/user"))
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await send(request)
        let user = try decode(UserPayload.self, from: data)
        guard let uuid = UUID(uuidString: user.id) else { throw SupabaseError.invalidResponse }
        let expiresAt = jwtExpiry(accessToken) ?? Date().addingTimeInterval(3600)
        let session = Session(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt, user: User(id: uuid))
        setSession(session)
        return session
    }

    @discardableResult
    func updateUser(_ attributes: UserAttributes) async throws -> User {
        let active = try await validSession()
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/user"))
        request.httpMethod = "PUT"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(active.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: attributes.jsonBody)
        _ = try await send(request)
        return active.user
    }

    func signOut() async throws {
        if let active = try? await validSession() {
            var request = URLRequest(url: baseURL.appendingPathComponent("/auth/v1/logout"))
            request.httpMethod = "POST"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(active.accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await send(request)
        }
        setSession(nil)
    }

    // MARK: Shared request plumbing

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.http(http.statusCode, Self.errorMessage(from: data))
        }
        return (data, http)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SupabaseError.decoding(error)
        }
    }

    private static func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "Request failed"
        }
        for key in ["error_description", "msg", "message", "error", "hint"] {
            if let value = json[key] as? String { return value }
        }
        return String(data: data, encoding: .utf8) ?? "Request failed"
    }
}

// MARK: - Auth client (thin facade over SupabaseHTTP matching the app's call sites)

public final class GoTrueClient: @unchecked Sendable {
    private let http: SupabaseHTTP
    init(http: SupabaseHTTP) { self.http = http }

    public var currentUser: User? { http.currentUser }

    public var session: Session {
        get async throws { try await http.validSession() }
    }

    public func signIn(email: String, password: String) async throws {
        try await http.signIn(email: email, password: password)
    }

    @discardableResult
    public func signUp(email: String, password: String, data: [String: AnyJSON]? = nil) async throws -> AuthResponse {
        try await http.signUp(email: email, password: password, data: data)
    }

    public func resetPasswordForEmail(_ email: String, redirectTo: URL? = nil) async throws {
        try await http.resetPasswordForEmail(email, redirectTo: redirectTo)
    }

    @discardableResult
    public func setSession(accessToken: String, refreshToken: String) async throws -> Session {
        try await http.setSession(accessToken: accessToken, refreshToken: refreshToken)
    }

    @discardableResult
    public func update(user: UserAttributes) async throws -> User {
        try await http.updateUser(user)
    }

    public func signOut() async throws {
        try await http.signOut()
    }
}

// MARK: - PostgREST query/filter builder

public struct PostgrestResponse<T> {
    public let value: T
}

public class PostgrestFilterBuilder: @unchecked Sendable {
    let http: SupabaseHTTP
    let path: String
    var method = "GET"
    var queryItems: [URLQueryItem] = [URLQueryItem(name: "select", value: "*")]
    var body: Data?
    var preferReturnMinimal = false

    init(http: SupabaseHTTP, path: String) {
        self.http = http
        self.path = path
    }

    @discardableResult
    public func select(_ columns: String = "*") -> PostgrestFilterBuilder {
        queryItems.removeAll { $0.name == "select" }
        queryItems.append(URLQueryItem(name: "select", value: columns))
        return self
    }

    @discardableResult
    public func eq(_ column: String, value: any Sendable) -> PostgrestFilterBuilder {
        queryItems.append(URLQueryItem(name: column, value: "eq.\(value)"))
        return self
    }

    @discardableResult
    public func order(_ column: String, ascending: Bool = true) -> PostgrestFilterBuilder {
        queryItems.append(URLQueryItem(name: "order", value: "\(column).\(ascending ? "asc" : "desc")"))
        return self
    }

    @discardableResult
    public func limit(_ count: Int) -> PostgrestFilterBuilder {
        queryItems.append(URLQueryItem(name: "limit", value: String(count)))
        return self
    }

    private func buildRequest() async throws -> URLRequest {
        var components = URLComponents(url: http.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(http.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(await http.bearerToken())", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if preferReturnMinimal {
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        }
        return request
    }

    public func execute() async throws -> PostgrestResponse<Void> {
        let request = try await buildRequest()
        _ = try await http.send(request)
        return PostgrestResponse(value: ())
    }

    public func execute<U: Decodable>() async throws -> PostgrestResponse<U> {
        let request = try await buildRequest()
        let (data, _) = try await http.send(request)
        let value: U = try http.decode(U.self, from: data)
        return PostgrestResponse(value: value)
    }
}

public final class PostgrestQueryBuilder: PostgrestFilterBuilder {
    @discardableResult
    public func insert<U: Encodable>(_ value: U) -> PostgrestFilterBuilder {
        method = "POST"
        body = try? JSONEncoder().encode(value)
        preferReturnMinimal = true
        queryItems.removeAll { $0.name == "select" }
        return self
    }

    @discardableResult
    public func update<U: Encodable>(_ value: U) -> PostgrestFilterBuilder {
        method = "PATCH"
        body = try? JSONEncoder().encode(value)
        preferReturnMinimal = true
        queryItems.removeAll { $0.name == "select" }
        return self
    }

    @discardableResult
    public func delete() -> PostgrestFilterBuilder {
        method = "DELETE"
        preferReturnMinimal = true
        queryItems.removeAll { $0.name == "select" }
        return self
    }
}

// MARK: - Storage

public struct FileOptions: Sendable {
    public var contentType: String
    public var upsert: Bool
    public init(contentType: String, upsert: Bool = false) {
        self.contentType = contentType
        self.upsert = upsert
    }
}

public final class StorageFileApi: @unchecked Sendable {
    private let http: SupabaseHTTP
    private let bucket: String
    init(http: SupabaseHTTP, bucket: String) {
        self.http = http
        self.bucket = bucket
    }

    public func createSignedURL(path: String, expiresIn: Int) async throws -> URL {
        var request = URLRequest(url: http.baseURL.appendingPathComponent("/storage/v1/object/sign/\(bucket)/\(path)"))
        request.httpMethod = "POST"
        request.setValue(http.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(await http.bearerToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": expiresIn])
        let (data, _) = try await http.send(request)
        struct Signed: Decodable { let signedURL: String }
        let signed = try http.decode(Signed.self, from: data)
        guard let url = URL(string: http.baseURL.absoluteString + "/storage/v1" + signed.signedURL) else {
            throw SupabaseError.invalidResponse
        }
        return url
    }

    @discardableResult
    public func upload(_ path: String, data: Data, options: FileOptions) async throws -> String {
        var request = URLRequest(url: http.baseURL.appendingPathComponent("/storage/v1/object/\(bucket)/\(path)"))
        request.httpMethod = "POST"
        request.setValue(http.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(await http.bearerToken())", forHTTPHeaderField: "Authorization")
        request.setValue(options.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(options.upsert ? "true" : "false", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        _ = try await http.send(request)
        return path
    }

    public func getPublicURL(path: String) throws -> URL {
        guard let url = URL(string: http.baseURL.absoluteString + "/storage/v1/object/public/\(bucket)/\(path)") else {
            throw SupabaseError.invalidResponse
        }
        return url
    }
}

public final class SupabaseStorageClient: @unchecked Sendable {
    private let http: SupabaseHTTP
    init(http: SupabaseHTTP) { self.http = http }
    public func from(_ bucket: String) -> StorageFileApi { StorageFileApi(http: http, bucket: bucket) }
}

// MARK: - Client

public final class SupabaseClient: @unchecked Sendable {
    private let http: SupabaseHTTP
    public let auth: GoTrueClient
    public let storage: SupabaseStorageClient

    public init(supabaseURL: URL, supabaseKey: String, options: SupabaseClientOptions = SupabaseClientOptions()) {
        http = SupabaseHTTP(baseURL: supabaseURL, anonKey: supabaseKey)
        auth = GoTrueClient(http: http)
        storage = SupabaseStorageClient(http: http)
    }

    public func from(_ table: String) -> PostgrestQueryBuilder {
        PostgrestQueryBuilder(http: http, path: "/rest/v1/\(table)")
    }

    @discardableResult
    public func rpc<U: Encodable>(_ fn: String, params: U) -> PostgrestFilterBuilder {
        let builder = PostgrestFilterBuilder(http: http, path: "/rest/v1/rpc/\(fn)")
        builder.method = "POST"
        builder.body = try? JSONEncoder().encode(params)
        builder.queryItems = []
        return builder
    }
}
