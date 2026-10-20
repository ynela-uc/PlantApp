import Foundation
import Supabase

/// Single shared Supabase client. URL and anon key are public by design (Row Level Security protects the data).
let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseAnonKey,
    options: SupabaseClientOptions(
        auth: .init(
            redirectToURL: Config.authRedirectURL,
            // Implicit flow: the reset link carries the tokens itself (same as the Android app).
            flowType: .implicit,
            emitLocalSessionAsInitialSession: true
        )
    )
)

private let listingColumns = "*, sellers(id,name,city,delivery_scope,delivers_to,rating,phone)"

// MARK: - Auth

enum AuthService {
    /// Signed-in user's id (lowercase, as the database stores it), if any.
    static var currentUserId: String? { supabase.auth.currentUser?.id.uuidString.lowercased() }

    /// True when a saved session exists (waits for it to be loaded from the keychain).
    static func hasSession() async -> Bool {
        (try? await supabase.auth.session) != nil
    }

    static func profile() async throws -> Profile? {
        guard let uid = currentUserId else { return nil }
        let rows: [Profile] = try await supabase.from("profiles")
            .select()
            .eq("id", value: uid)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    static func signUp(role: Role, form: SignUpForm) async throws {
        let response = try await supabase.auth.signUp(
            email: form.email,
            password: form.password,
            data: [
                "role": .string(role.rawValue),
                "first_name": .string(form.firstName),
                "last_name": .string(form.lastName),
                "phone": .string(form.phone),
                "city": .string(form.city),
                "address": .string(form.address),
            ]
        )
        guard response.session != nil else { throw AppError.noSession }
        if role == .seller {
            let uid = response.user.id.uuidString.lowercased()
            try await supabase.from("sellers").insert(
                NewSeller(
                    ownerId: uid,
                    name: form.shopName,
                    city: form.city,
                    deliveryScope: "local",
                    deliversTo: [form.city],
                    phone: form.phone,
                    bio: "",
                    plantsOffered: [],
                    shopTypes: form.shopTypes
                )
            ).execute()
        }
    }

    /// Emails a reset link; opening it on the phone launches the app (plantapp://auth-callback).
    static func sendResetLink(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email, redirectTo: Config.authRedirectURL)
    }

    /// Signs in with the tokens carried by a reset link (plantapp://auth-callback#access_token=...).
    static func importSession(accessToken: String, refreshToken: String) async throws {
        try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
    }

    static func setNewPassword(_ password: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: password))
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }
}

enum AppError: Error {
    case noSession
    case aiNotConfigured
    case aiLimitReached
    case network
    case failed
}

// MARK: - Customer side

enum ListingsService {
    /// All listings with their shop attached, newest first.
    static func fetchAll() async throws -> [Listing] {
        try await supabase.from("listings")
            .select(listingColumns)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}

private struct ReviewPhotoParams: Encodable {
    let pOrderId: String
    let pApprove: Bool
    let pNote: String?

    enum CodingKeys: String, CodingKey {
        case pOrderId = "p_order_id"
        case pApprove = "p_approve"
        case pNote = "p_note"
    }
}

enum OrdersService {
    static func create(_ order: NewOrder) async throws {
        try await supabase.from("orders").insert(order).execute()
    }

    static func fetchMine(buyerId: String) async throws -> [Order] {
        try await supabase.from("orders")
            .select()
            .eq("buyer_id", value: buyerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Customer's answer to the preparation photo: approve it, or ask the shop to change something.
    static func reviewPhoto(orderId: String, approve: Bool, note: String?) async throws {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await supabase.rpc(
            "customer_review_photo",
            params: ReviewPhotoParams(
                pOrderId: orderId,
                pApprove: approve,
                pNote: (trimmed?.isEmpty ?? true) ? nil : trimmed
            )
        ).execute()
    }

    /// Short-lived link to the (private) preparation photo.
    static func signedPhotoURL(path: String) async throws -> URL {
        try await supabase.storage.from("order-photos").createSignedURL(path: path, expiresIn: 3600)
    }
}

// MARK: - Seller side

private struct SetStatusParams: Encodable {
    let pOrderId: String
    let pStatus: String
    let pPhotoPath: String?

    enum CodingKeys: String, CodingKey {
        case pOrderId = "p_order_id"
        case pStatus = "p_status"
        case pPhotoPath = "p_photo_path"
    }
}

private struct StockUpdate: Encodable {
    let inStock: Bool
    enum CodingKeys: String, CodingKey { case inStock = "in_stock" }
}

enum SellerService {
    static func fetchShop(ownerId: String) async throws -> Shop? {
        let rows: [Shop] = try await supabase.from("sellers")
            .select()
            .eq("owner_id", value: ownerId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func updateShop(shopId: String, update: ShopUpdate) async throws {
        try await supabase.from("sellers").update(update).eq("id", value: shopId).execute()
    }

    static func fetchListings(shopId: String) async throws -> [Listing] {
        try await supabase.from("listings")
            .select()
            .eq("seller_id", value: shopId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func createListing(_ listing: NewListing) async throws {
        try await supabase.from("listings").insert(listing).execute()
    }

    static func updateListing(id: String, update: ListingUpdate) async throws {
        try await supabase.from("listings").update(update).eq("id", value: id).execute()
    }

    static func setInStock(id: String, inStock: Bool) async throws {
        try await supabase.from("listings").update(StockUpdate(inStock: inStock)).eq("id", value: id).execute()
    }

    static func deleteListing(id: String) async throws {
        try await supabase.from("listings").delete().eq("id", value: id).execute()
    }

    static func fetchOrders(shopId: String) async throws -> [Order] {
        try await supabase.from("orders")
            .select()
            .eq("seller_id", value: shopId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Moves an order along its status steps; the database checks that the change is allowed.
    static func setOrderStatus(orderId: String, status: OrderStatus, photoPath: String? = nil) async throws {
        try await supabase.rpc(
            "seller_set_order_status",
            params: SetStatusParams(pOrderId: orderId, pStatus: status.rawValue, pPhotoPath: photoPath)
        ).execute()
    }

    /// Uploads a plant photo into the seller's own folder and returns its storage path.
    static func uploadPlantPhoto(ownerId: String, jpeg: Data) async throws -> String {
        let path = "\(ownerId)/\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage.from("plant-photos")
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        return path
    }

    /// Uploads (or replaces) the photo shown to the customer for approval.
    static func uploadOrderPhoto(orderId: String, jpeg: Data) async throws -> String {
        let path = "\(orderId)/photo.jpg"
        try await supabase.storage.from("order-photos")
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return path
    }
}

// MARK: - AI

enum AiService {
    private struct Body: Encodable {
        let imageBase64: String
        let mediaType: String
        enum CodingKeys: String, CodingKey {
            case imageBase64 = "image_base64"
            case mediaType = "media_type"
        }
    }

    private struct ErrorBody: Decodable { let error: String? }

    /// Sends one JPEG to the identify-plant edge function (which holds the AI key) and returns suggestions.
    static func identify(jpeg: Data) async throws -> PlantSuggestion {
        guard let token = try? await supabase.auth.session.accessToken else { throw AppError.failed }

        var request = URLRequest(url: Config.supabaseURL.appendingPathComponent("functions/v1/identify-plant"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(Body(imageBase64: jpeg.base64EncodedString(), mediaType: "image/jpeg"))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AppError.network
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(code) {
            guard let suggestion = try? JSONDecoder().decode(PlantSuggestion.self, from: data) else { throw AppError.failed }
            return suggestion
        }
        let errorCode = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
        if errorCode == "ai_not_configured" || code == 404 { throw AppError.aiNotConfigured }
        if errorCode == "daily_limit" { throw AppError.aiLimitReached }
        throw AppError.failed
    }
}
