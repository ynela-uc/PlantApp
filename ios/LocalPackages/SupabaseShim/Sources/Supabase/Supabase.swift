import Foundation

// LOCAL STAND-IN for the real `supabase-swift` package.
//
// This machine's toolchain (Xcode 14.2 / Swift 5.7, the max Xcode supports on
// macOS 12 Monterey) cannot resolve supabase-swift >= 1.0.0: every release in
// PlantApp's required range (2.55.4..<3.0.0) declares swift-tools-version 6.1,
// which Swift 5.7 cannot even parse. There is no real version that is both
// within range and old enough to resolve here.
//
// This shim mirrors the real SDK's public API shape (same method names,
// labels, and generic signatures) closely enough that PlantApp's own source
// type-checks and links locally. It performs no real networking - every call
// throws `SupabaseShimError.notImplemented` at runtime. Swap `project.yml`'s
// `Supabase` package back to the real remote one on any machine with Xcode 16+
// before running the app for real.

public enum SupabaseShimError: Error {
    case notImplemented
}

// MARK: - JSON

public enum AnyJSON: Sendable {
    case string(String)
    case double(Double)
    case integer(Int)
    case bool(Bool)
    case null
}

// MARK: - Auth

public enum AuthFlowType: Sendable {
    case implicit
    case pkce
}

public struct User: Sendable {
    public let id: UUID
    public init(id: UUID = UUID()) { self.id = id }
}

public struct Session: Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let user: User
    public init(accessToken: String = "", refreshToken: String = "", user: User = User()) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
    }
}

public struct AuthResponse: Sendable {
    public let session: Session?
    public let user: User
}

public struct UserAttributes: Sendable {
    public var password: String?
    public var email: String?
    public init(email: String? = nil, password: String? = nil) {
        self.email = email
        self.password = password
    }
}

public final class GoTrueClient: @unchecked Sendable {
    public var currentUser: User? { nil }

    public var session: Session {
        get async throws { throw SupabaseShimError.notImplemented }
    }

    public func signIn(email: String, password: String) async throws {
        throw SupabaseShimError.notImplemented
    }

    @discardableResult
    public func signUp(email: String, password: String, data: [String: AnyJSON]? = nil) async throws -> AuthResponse {
        throw SupabaseShimError.notImplemented
    }

    public func resetPasswordForEmail(_ email: String, redirectTo: URL? = nil) async throws {
        throw SupabaseShimError.notImplemented
    }

    @discardableResult
    public func setSession(accessToken: String, refreshToken: String) async throws -> Session {
        throw SupabaseShimError.notImplemented
    }

    @discardableResult
    public func update(user: UserAttributes) async throws -> User {
        throw SupabaseShimError.notImplemented
    }

    public func signOut() async throws {
        throw SupabaseShimError.notImplemented
    }
}

// MARK: - Postgrest

public struct PostgrestResponse<T> {
    public let value: T
}

public class PostgrestFilterBuilder: @unchecked Sendable {
    @discardableResult
    public func select(_ columns: String = "*") -> PostgrestFilterBuilder { self }

    @discardableResult
    public func eq(_ column: String, value: any Sendable) -> PostgrestFilterBuilder { self }

    @discardableResult
    public func order(_ column: String, ascending: Bool = true) -> PostgrestFilterBuilder { self }

    @discardableResult
    public func limit(_ count: Int) -> PostgrestFilterBuilder { self }

    public func execute() async throws -> PostgrestResponse<Void> {
        throw SupabaseShimError.notImplemented
    }

    public func execute<U: Decodable>() async throws -> PostgrestResponse<U> {
        throw SupabaseShimError.notImplemented
    }
}

public final class PostgrestQueryBuilder: PostgrestFilterBuilder {
    @discardableResult
    public func insert<U: Encodable>(_ value: U) -> PostgrestFilterBuilder { self }

    @discardableResult
    public func update<U: Encodable>(_ value: U) -> PostgrestFilterBuilder { self }

    @discardableResult
    public func delete() -> PostgrestFilterBuilder { self }
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
    public func createSignedURL(path: String, expiresIn: Int) async throws -> URL {
        throw SupabaseShimError.notImplemented
    }

    @discardableResult
    public func upload(_ path: String, data: Data, options: FileOptions) async throws -> String {
        throw SupabaseShimError.notImplemented
    }

    public func getPublicURL(path: String) throws -> URL {
        throw SupabaseShimError.notImplemented
    }
}

public final class SupabaseStorageClient: @unchecked Sendable {
    public func from(_ id: String) -> StorageFileApi { StorageFileApi() }
}

// MARK: - Client

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

public final class SupabaseClient: @unchecked Sendable {
    public let auth = GoTrueClient()
    public let storage = SupabaseStorageClient()

    public init(supabaseURL: URL, supabaseKey: String, options: SupabaseClientOptions = SupabaseClientOptions()) {}

    public func from(_ table: String) -> PostgrestQueryBuilder { PostgrestQueryBuilder() }

    @discardableResult
    public func rpc<U: Encodable>(_ fn: String, params: U) -> PostgrestFilterBuilder { PostgrestFilterBuilder() }
}
