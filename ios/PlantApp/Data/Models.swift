import Foundation
import Supabase

// MARK: - Accounts

enum Role: String {
    case customer, seller
    static func from(_ value: String?) -> Role { Role(rawValue: value ?? "") ?? .customer }
}

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    var role: String
    var firstName: String
    var lastName: String
    var phone: String
    var city: String
    var address: String
    var district: String
    var neighborhood: String
    var landmark: String
    var addressNotes: String

    enum CodingKeys: String, CodingKey {
        case id, role, phone, city, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case firstName = "first_name"
        case lastName = "last_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "customer"
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        neighborhood = try c.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        landmark = try c.decodeIfPresent(String.self, forKey: .landmark) ?? ""
        addressNotes = try c.decodeIfPresent(String.self, forKey: .addressNotes) ?? ""
    }

    var roleEnum: Role { Role.from(role) }
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
}

/// The fields a customer can change on their own profile (addresses live in the address book).
struct ProfileUpdate: Encodable {
    let firstName: String
    let lastName: String
    let phone: String

    enum CodingKeys: String, CodingKey {
        case phone
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct SignUpForm {
    var email = ""
    var password = ""
    var firstName = ""
    var lastName = ""
    var phone = ""
    var city = ""
    var address = ""
    var district = ""
    var neighborhood = ""
    var landmark = ""
    var addressNotes = ""
    var lat: Double?
    var lng: Double?
    var shopName = ""
    /// Which kinds of shop a seller runs (Catalog section keys).
    var shopTypes: [String] = []
}

// MARK: - Shops and plants

struct SellerInfo: Codable, Equatable {
    let id: String
    let name: String
    let city: String
    var deliveryScope: String
    var deliversTo: [String]?
    var rating: Double
    var ratingCount: Int
    var phone: String
    var bio: String
    var deliveryFeeIqd: Int
    /// City code -> fee, for cities that cost more or less than `deliveryFeeIqd`.
    var deliveryFees: [String: Int]
    var shopTypes: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, city, rating, phone, bio
        case ratingCount = "rating_count"
        case deliveryScope = "delivery_scope"
        case deliversTo = "delivers_to"
        case deliveryFeeIqd = "delivery_fee_iqd"
        case deliveryFees = "delivery_fees"
        case shopTypes = "shop_types"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decode(String.self, forKey: .city)
        deliveryScope = try c.decodeIfPresent(String.self, forKey: .deliveryScope) ?? "local"
        deliversTo = try c.decodeIfPresent([String].self, forKey: .deliversTo)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        ratingCount = try c.decodeIfPresent(Int.self, forKey: .ratingCount) ?? 0
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        deliveryFeeIqd = try c.decodeIfPresent(Int.self, forKey: .deliveryFeeIqd) ?? 0
        deliveryFees = try c.decodeIfPresent([String: Int].self, forKey: .deliveryFees) ?? [:]
        shopTypes = try c.decodeIfPresent([String].self, forKey: .shopTypes) ?? []
    }

    var isNationwide: Bool { deliveryScope == "nationwide" }

    /// What this shop charges to deliver to `city`.
    func feeFor(_ city: String) -> Int { deliveryFees[city] ?? deliveryFeeIqd }
}

/// The signed-in seller's own shop row.
struct Shop: Codable, Equatable {
    let id: String
    var name: String
    var city: String
    var deliveryScope: String
    var deliversTo: [String]?
    var rating: Double
    var phone: String
    var bio: String
    var shopTypes: [String]
    var deliveryFeeIqd: Int
    var deliveryFees: [String: Int]
    /// False until the owner of the app approves the shop; customers cannot see it before.
    var approved: Bool
    /// pending, changes_requested (see reviewNote), rejected (see reviewNote) or approved.
    var reviewStatus: String
    var reviewNote: String?
    /// The shop address: `city` is the governorate. Customers never see it; the admin and the owner do.
    var address: String
    var district: String
    var neighborhood: String
    var landmark: String
    var addressNotes: String
    var lat: Double?
    var lng: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, city, rating, phone, bio, approved, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case lat, lng
        case reviewStatus = "review_status"
        case reviewNote = "review_note"
        case deliveryScope = "delivery_scope"
        case deliversTo = "delivers_to"
        case shopTypes = "shop_types"
        case deliveryFeeIqd = "delivery_fee_iqd"
        case deliveryFees = "delivery_fees"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decode(String.self, forKey: .city)
        deliveryScope = try c.decodeIfPresent(String.self, forKey: .deliveryScope) ?? "local"
        deliversTo = try c.decodeIfPresent([String].self, forKey: .deliversTo)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        shopTypes = try c.decodeIfPresent([String].self, forKey: .shopTypes) ?? [Catalog.plants]
        deliveryFeeIqd = try c.decodeIfPresent(Int.self, forKey: .deliveryFeeIqd) ?? 0
        deliveryFees = try c.decodeIfPresent([String: Int].self, forKey: .deliveryFees) ?? [:]
        approved = try c.decodeIfPresent(Bool.self, forKey: .approved) ?? true
        reviewStatus = try c.decodeIfPresent(String.self, forKey: .reviewStatus) ?? "approved"
        reviewNote = try c.decodeIfPresent(String.self, forKey: .reviewNote)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        neighborhood = try c.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        landmark = try c.decodeIfPresent(String.self, forKey: .landmark) ?? ""
        addressNotes = try c.decodeIfPresent(String.self, forKey: .addressNotes) ?? ""
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
    }

    var isNationwide: Bool { deliveryScope == "nationwide" }
}

struct ShopUpdate: Encodable {
    let name: String
    let phone: String
    let bio: String
    let deliveryScope: String
    let deliversTo: [String]?
    let shopTypes: [String]
    let deliveryFeeIqd: Int
    let deliveryFees: [String: Int]
    let city: String
    let address: String
    let district: String
    let neighborhood: String
    let landmark: String
    let addressNotes: String
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case name, phone, bio, city, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case lat, lng
        case deliveryScope = "delivery_scope"
        case deliversTo = "delivers_to"
        case shopTypes = "shop_types"
        case deliveryFeeIqd = "delivery_fee_iqd"
        case deliveryFees = "delivery_fees"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(phone, forKey: .phone)
        try c.encode(bio, forKey: .bio)
        try c.encode(deliveryScope, forKey: .deliveryScope)
        try c.encode(deliversTo, forKey: .deliversTo) // nil is sent as null
        try c.encode(shopTypes, forKey: .shopTypes)
        try c.encode(deliveryFeeIqd, forKey: .deliveryFeeIqd)
        try c.encode(deliveryFees, forKey: .deliveryFees)
        try c.encode(city, forKey: .city)
        try c.encode(address, forKey: .address)
        try c.encode(district, forKey: .district)
        try c.encode(neighborhood, forKey: .neighborhood)
        try c.encode(landmark, forKey: .landmark)
        try c.encode(addressNotes, forKey: .addressNotes)
        try c.encode(lat, forKey: .lat) // nil is sent as null: removing the pin clears it
        try c.encode(lng, forKey: .lng)
    }
}

/// Row inserted into `sellers` when a seller creates an account.
struct NewSeller: Encodable {
    let ownerId: String
    let name: String
    let city: String
    let address: String
    let district: String
    let neighborhood: String
    let landmark: String
    let addressNotes: String
    let lat: Double?
    let lng: Double?
    let deliveryScope: String
    let deliversTo: [String]
    let phone: String
    let bio: String
    let plantsOffered: [String]
    let shopTypes: [String]
    let deliveryFeeIqd: Int

    enum CodingKeys: String, CodingKey {
        case name, city, phone, bio, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case lat, lng
        case ownerId = "owner_id"
        case deliveryScope = "delivery_scope"
        case deliversTo = "delivers_to"
        case plantsOffered = "plants_offered"
        case shopTypes = "shop_types"
        case deliveryFeeIqd = "delivery_fee_iqd"
    }
}

/// One plant offered by one shop. Text fields are maps keyed by language code (en / ar / ckb).
struct Listing: Codable, Identifiable, Equatable {
    let id: String
    let sellerId: String
    /// flowers / plants / gifts (see Catalog). Rows from before sections existed are plants.
    var section: String
    var category: String?
    var occasions: [String]
    var plantKey: String?
    var name: [String: String]
    var scientificName: String?
    var description: [String: String]
    var care: [String: [String: String]]
    var heightCm: Int?
    var priceIqd: Int
    /// The price before a discount; shown crossed out next to `priceIqd`.
    var oldPriceIqd: Int?
    /// How many pieces are in this package, for sets and bundles.
    var pieces: Int?
    var options: [ListingOption]
    /// A named group in the shop (Autumn 2026, Ramadan, ...).
    var collection: String?
    var inStock: Bool
    var imagePath: String?
    var aiGenerated: Bool
    /// off / optional / required: whether the shop sends a photo for the customer to approve before delivery.
    var photoApproval: String
    var sellers: SellerInfo?

    enum CodingKeys: String, CodingKey {
        case id, name, description, care, sellers
        case section, category, occasions, pieces, options, collection
        case sellerId = "seller_id"
        case plantKey = "plant_key"
        case scientificName = "scientific_name"
        case heightCm = "height_cm"
        case priceIqd = "price_iqd"
        case oldPriceIqd = "old_price_iqd"
        case inStock = "in_stock"
        case imagePath = "image_path"
        case aiGenerated = "ai_generated"
        case photoApproval = "photo_approval"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sellerId = try c.decode(String.self, forKey: .sellerId)
        section = try c.decodeIfPresent(String.self, forKey: .section) ?? Catalog.plants
        category = try c.decodeIfPresent(String.self, forKey: .category)
        occasions = try c.decodeIfPresent([String].self, forKey: .occasions) ?? []
        plantKey = try c.decodeIfPresent(String.self, forKey: .plantKey)
        name = try c.decodeIfPresent([String: String].self, forKey: .name) ?? [:]
        scientificName = try c.decodeIfPresent(String.self, forKey: .scientificName)
        description = try c.decodeIfPresent([String: String].self, forKey: .description) ?? [:]
        care = try c.decodeIfPresent([String: [String: String]].self, forKey: .care) ?? [:]
        heightCm = try c.decodeIfPresent(Int.self, forKey: .heightCm)
        priceIqd = try c.decode(Int.self, forKey: .priceIqd)
        oldPriceIqd = try c.decodeIfPresent(Int.self, forKey: .oldPriceIqd)
        pieces = try c.decodeIfPresent(Int.self, forKey: .pieces)
        options = try c.decodeIfPresent([ListingOption].self, forKey: .options) ?? []
        collection = try c.decodeIfPresent(String.self, forKey: .collection)
        inStock = try c.decodeIfPresent(Bool.self, forKey: .inStock) ?? true
        imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath)
        aiGenerated = try c.decodeIfPresent(Bool.self, forKey: .aiGenerated) ?? false
        photoApproval = try c.decodeIfPresent(String.self, forKey: .photoApproval) ?? "off"
        sellers = try c.decodeIfPresent(SellerInfo.self, forKey: .sellers)
    }

    /// Public link to the shop's photo, or nil while the listing has none.
    var imageURL: URL? {
        guard let path = imagePath, !path.isEmpty else { return nil }
        return try? supabase.storage.from("plant-photos").getPublicURL(path: path)
    }

    /// Percent off when `oldPriceIqd` is above the current price, else nil.
    var discountPercent: Int? {
        guard let old = oldPriceIqd, old > priceIqd, old > 0 else { return nil }
        return (old - priceIqd) * 100 / old
    }

    /// Emoji shown as the picture until a shop uploads a photo.
    var placeholderEmoji: String {
        section == Catalog.plants ? plantEmoji(plantKey) : Catalog.categoryEmoji(category)
    }

    /// Whether this listing's shop delivers to `city`.
    func delivers(to city: String) -> Bool {
        guard let shop = sellers else { return false }
        return shop.city == city || shop.isNationwide || (shop.deliversTo?.contains(city) ?? false)
    }
}

struct NewListing: Encodable {
    let sellerId: String
    let section: String
    let category: String?
    let occasions: [String]
    let plantKey: String?
    let name: [String: String]
    let scientificName: String?
    let description: [String: String]
    let care: [String: [String: String]]
    let heightCm: Int?
    let priceIqd: Int
    let oldPriceIqd: Int?
    let pieces: Int?
    let options: [ListingOption]
    let collection: String?
    let imagePath: String?
    let inStock: Bool
    let aiGenerated: Bool
    let photoApproval: String

    enum CodingKeys: String, CodingKey {
        case name, description, care, section, category, occasions, pieces, options, collection
        case oldPriceIqd = "old_price_iqd"
        case photoApproval = "photo_approval"
        case sellerId = "seller_id"
        case plantKey = "plant_key"
        case scientificName = "scientific_name"
        case heightCm = "height_cm"
        case priceIqd = "price_iqd"
        case imagePath = "image_path"
        case inStock = "in_stock"
        case aiGenerated = "ai_generated"
    }
}

struct ListingUpdate: Encodable {
    let section: String
    let category: String?
    let occasions: [String]
    let plantKey: String?
    let name: [String: String]
    let scientificName: String?
    let description: [String: String]
    let care: [String: [String: String]]
    let heightCm: Int?
    let priceIqd: Int
    let oldPriceIqd: Int?
    let pieces: Int?
    let options: [ListingOption]
    let collection: String?
    let imagePath: String?
    let inStock: Bool
    let aiGenerated: Bool
    let photoApproval: String

    enum CodingKeys: String, CodingKey {
        case name, description, care, section, category, occasions, pieces, options, collection
        case oldPriceIqd = "old_price_iqd"
        case photoApproval = "photo_approval"
        case plantKey = "plant_key"
        case scientificName = "scientific_name"
        case heightCm = "height_cm"
        case priceIqd = "price_iqd"
        case imagePath = "image_path"
        case inStock = "in_stock"
        case aiGenerated = "ai_generated"
    }

    // Updates must send nil as an explicit null so a cleared field is really cleared.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(section, forKey: .section)
        try c.encode(category, forKey: .category)
        try c.encode(occasions, forKey: .occasions)
        try c.encode(plantKey, forKey: .plantKey)
        try c.encode(name, forKey: .name)
        try c.encode(scientificName, forKey: .scientificName)
        try c.encode(description, forKey: .description)
        try c.encode(care, forKey: .care)
        try c.encode(heightCm, forKey: .heightCm)
        try c.encode(priceIqd, forKey: .priceIqd)
        try c.encode(oldPriceIqd, forKey: .oldPriceIqd)
        try c.encode(pieces, forKey: .pieces)
        try c.encode(options, forKey: .options)
        try c.encode(collection, forKey: .collection)
        try c.encode(imagePath, forKey: .imagePath)
        try c.encode(inStock, forKey: .inStock)
        try c.encode(aiGenerated, forKey: .aiGenerated)
        try c.encode(photoApproval, forKey: .photoApproval)
    }
}

// MARK: - Orders

/// One line of an order. Defaults keep older prototype rows (different shape) decodable.
struct OrderItem: Codable, Equatable {
    var listingId: String
    var name: [String: String]
    var qty: Int
    var unitPriceIqd: Int
    /// The customer's choices for this line, option name -> chosen value.
    var options: [String: String]

    enum CodingKeys: String, CodingKey {
        case name, qty, options
        case listingId = "listing_id"
        case unitPriceIqd = "unit_price_iqd"
    }

    init(listingId: String, name: [String: String], qty: Int, unitPriceIqd: Int, options: [String: String] = [:]) {
        self.listingId = listingId
        self.name = name
        self.qty = qty
        self.unitPriceIqd = unitPriceIqd
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listingId = try c.decodeIfPresent(String.self, forKey: .listingId) ?? ""
        name = (try? c.decodeIfPresent([String: String].self, forKey: .name)) ?? [:]
        qty = try c.decodeIfPresent(Int.self, forKey: .qty) ?? 1
        unitPriceIqd = try c.decodeIfPresent(Int.self, forKey: .unitPriceIqd) ?? 0
        options = (try? c.decodeIfPresent([String: String].self, forKey: .options)) ?? [:]
    }

    /// "Name (Blue · Large) × 2"
    func label(_ name: String) -> String {
        let choices = options.isEmpty ? "" : " (" + options.keys.sorted().compactMap { options[$0] }.joined(separator: " · ") + ")"
        return "\(name)\(choices) × \(qty)"
    }
}

/// Order progress, in the order a customer sees it.
enum OrderStatus: String, CaseIterable {
    case placed
    case preparing
    case photoSent = "photo_sent"
    case approved
    case outForDelivery = "out_for_delivery"
    case delivered
    case cancelled

    static func from(_ value: String?) -> OrderStatus { OrderStatus(rawValue: value ?? "") ?? .placed }

    /// Steps shown on the timeline (cancelled is shown on its own).
    static let timeline: [OrderStatus] = [.placed, .preparing, .photoSent, .approved, .outForDelivery, .delivered]

    /// Orders without a photo step go straight from preparing to out for delivery.
    static let timelineWithoutPhoto: [OrderStatus] = [.placed, .preparing, .outForDelivery, .delivered]

    var labelKey: String {
        switch self {
        case .placed: return "status_placed"
        case .preparing: return "status_preparing"
        case .photoSent: return "status_photo_sent"
        case .approved: return "status_approved"
        case .outForDelivery: return "status_out_for_delivery"
        case .delivered: return "status_delivered"
        case .cancelled: return "status_cancelled"
        }
    }
}

struct Order: Codable, Identifiable, Equatable {
    let id: String
    let sellerId: String
    var sellerName: String
    var items: [OrderItem]
    var status: String
    var city: String
    var address: String
    var district: String
    var neighborhood: String
    var landmark: String
    var addressNotes: String
    var lat: Double?
    var lng: Double?
    var createdAt: String
    var totalIqd: Int
    var deliveryFeeIqd: Int
    var isGift: Bool
    var recipientName: String?
    var recipientPhone: String?
    var giftNote: String?
    var deliveryDate: String?
    var deliveryWindow: String
    var preparationPhotoPath: String?
    var changeRequest: String?
    var buyerName: String
    var buyerPhone: String
    /// True when the shop must send a photo that the customer approves before delivery.
    var photoRequired: Bool
    var photoSentAt: String?
    /// Why a cancelled order was cancelled (see `shopCancelReasons`) and by whom: customer, shop or system.
    var cancelReason: String?
    var cancelledBy: String?

    enum CodingKeys: String, CodingKey {
        case id, items, status, city, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case lat, lng
        case photoRequired = "photo_required"
        case photoSentAt = "photo_sent_at"
        case cancelReason = "cancel_reason"
        case cancelledBy = "cancelled_by"
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case createdAt = "created_at"
        case totalIqd = "total_iqd"
        case deliveryFeeIqd = "delivery_fee_iqd"
        case isGift = "is_gift"
        case recipientName = "recipient_name"
        case recipientPhone = "recipient_phone"
        case giftNote = "gift_note"
        case deliveryDate = "delivery_date"
        case deliveryWindow = "delivery_window"
        case preparationPhotoPath = "preparation_photo_path"
        case changeRequest = "change_request"
        case buyerName = "buyer_name"
        case buyerPhone = "buyer_phone"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sellerId = try c.decode(String.self, forKey: .sellerId)
        sellerName = try c.decodeIfPresent(String.self, forKey: .sellerName) ?? ""
        items = (try? c.decodeIfPresent([OrderItem].self, forKey: .items)) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "placed"
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        neighborhood = try c.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        landmark = try c.decodeIfPresent(String.self, forKey: .landmark) ?? ""
        addressNotes = try c.decodeIfPresent(String.self, forKey: .addressNotes) ?? ""
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        totalIqd = try c.decodeIfPresent(Int.self, forKey: .totalIqd) ?? 0
        deliveryFeeIqd = try c.decodeIfPresent(Int.self, forKey: .deliveryFeeIqd) ?? 0
        isGift = try c.decodeIfPresent(Bool.self, forKey: .isGift) ?? false
        recipientName = try c.decodeIfPresent(String.self, forKey: .recipientName)
        recipientPhone = try c.decodeIfPresent(String.self, forKey: .recipientPhone)
        giftNote = try c.decodeIfPresent(String.self, forKey: .giftNote)
        deliveryDate = try c.decodeIfPresent(String.self, forKey: .deliveryDate)
        deliveryWindow = try c.decodeIfPresent(String.self, forKey: .deliveryWindow) ?? "any"
        preparationPhotoPath = try c.decodeIfPresent(String.self, forKey: .preparationPhotoPath)
        changeRequest = try c.decodeIfPresent(String.self, forKey: .changeRequest)
        buyerName = try c.decodeIfPresent(String.self, forKey: .buyerName) ?? ""
        buyerPhone = try c.decodeIfPresent(String.self, forKey: .buyerPhone) ?? ""
        photoRequired = try c.decodeIfPresent(Bool.self, forKey: .photoRequired) ?? false
        photoSentAt = try c.decodeIfPresent(String.self, forKey: .photoSentAt)
        cancelReason = try c.decodeIfPresent(String.self, forKey: .cancelReason)
        cancelledBy = try c.decodeIfPresent(String.self, forKey: .cancelledBy)
    }

    var statusEnum: OrderStatus { OrderStatus.from(status) }

    /// The steps this order goes through (with or without the photo approval).
    var timeline: [OrderStatus] { photoRequired ? OrderStatus.timeline : OrderStatus.timelineWithoutPhoto }

    /// The customer has not answered the photo within an hour: the shop may continue (the database checks this too).
    var photoAnswerOverdue: Bool {
        guard statusEnum == .photoSent, let text = photoSentAt else { return false }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let sent = withFraction.date(from: text) ?? plain.date(from: text) else { return false }
        return Date().timeIntervalSince(sent) > 3600
    }
    var shortId: String { String(id.prefix(6)).uppercased() }
    var itemCount: Int { items.reduce(0) { $0 + $1.qty } }
}

/// Reasons a shop can give when it declines or cancels an order.
let shopCancelReasons = ["out_of_stock", "cant_deliver_day", "cant_make", "other"]

/// Reasons a shop can give when an order could not be delivered.
let failedDeliveryReasons = ["no_answer", "refused", "wrong_address", "other"]

/// The string key for the words of a cancel / failed-delivery reason.
func cancelReasonKey(_ key: String?) -> String {
    switch key {
    case "out_of_stock": return "reason_out_of_stock"
    case "cant_deliver_day": return "reason_cant_deliver_day"
    case "cant_make": return "reason_cant_make"
    case "no_answer": return "reason_no_answer"
    case "refused": return "reason_refused"
    case "wrong_address": return "reason_wrong_address"
    case "customer_cancelled": return "reason_customer_cancelled"
    case "no_response": return "reason_no_response"
    default: return "reason_other"
    }
}

struct NewOrder: Encodable {
    let buyerId: String
    let sellerId: String
    let sellerName: String
    let items: [OrderItem]
    let paymentMethod = "cod"
    let city: String
    let address: String
    let district: String
    let neighborhood: String
    let landmark: String
    let addressNotes: String
    let lat: Double?
    let lng: Double?
    let totalIqd: Int
    let deliveryFeeIqd: Int
    let buyerName: String
    let buyerPhone: String
    let isGift: Bool
    let recipientName: String?
    let recipientPhone: String?
    let giftNote: String?
    let deliveryDate: String
    let deliveryWindow: String
    let photoRequested: Bool

    enum CodingKeys: String, CodingKey {
        case items, city, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case lat, lng
        case photoRequested = "photo_requested"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case paymentMethod = "payment_method"
        case totalIqd = "total_iqd"
        case deliveryFeeIqd = "delivery_fee_iqd"
        case buyerName = "buyer_name"
        case buyerPhone = "buyer_phone"
        case isGift = "is_gift"
        case recipientName = "recipient_name"
        case recipientPhone = "recipient_phone"
        case giftNote = "gift_note"
        case deliveryDate = "delivery_date"
        case deliveryWindow = "delivery_window"
    }
}

/// What the cart-to-order step collects.
struct CheckoutForm {
    var isGift = false
    var recipientName = ""
    var recipientPhone = ""
    var city = ""
    var address = ""
    var district = ""
    var neighborhood = ""
    var landmark = ""
    var addressNotes = ""
    var lat: Double?
    var lng: Double?
    var giftNote = ""
    /// ISO date, yyyy-MM-dd
    var deliveryDate = ""
    /// any / morning / afternoon / evening
    var window = "any"
    /// The customer asked to approve a photo first (only counts for products where the shop offers it).
    var photoRequested = false
    /// The address was typed for this order: also keep it in the address book.
    var saveAsAddress = false
}

// MARK: - AI suggestions

struct Tri: Codable, Equatable {
    var en = ""
    var ar = ""
    var ckb = ""

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        en = try c.decodeIfPresent(String.self, forKey: .en) ?? ""
        ar = try c.decodeIfPresent(String.self, forKey: .ar) ?? ""
        ckb = try c.decodeIfPresent(String.self, forKey: .ckb) ?? ""
    }
    enum CodingKeys: String, CodingKey { case en, ar, ckb }

    /// Language -> text, skipping empty ones.
    var map: [String: String] {
        var result: [String: String] = [:]
        if !en.isEmpty { result["en"] = en }
        if !ar.isEmpty { result["ar"] = ar }
        if !ckb.isEmpty { result["ckb"] = ckb }
        return result
    }
}

struct AiCare: Codable {
    var water = Tri()
    var light = Tri()
    var fertilizer = Tri()

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        water = try c.decodeIfPresent(Tri.self, forKey: .water) ?? Tri()
        light = try c.decodeIfPresent(Tri.self, forKey: .light) ?? Tri()
        fertilizer = try c.decodeIfPresent(Tri.self, forKey: .fertilizer) ?? Tri()
    }
    enum CodingKeys: String, CodingKey { case water, light, fertilizer }
}

/// What the identify-plant function returns for one photo.
struct PlantSuggestion: Codable {
    var identified = false
    var confidence = "low"
    var plantKey = "Other"
    var scientificName = ""
    var name = Tri()
    var description = Tri()
    var care = AiCare()
    var heightCm = 0
    /// What kind of product the photo shows (Catalog keys); older function versions leave these empty.
    var section = ""
    var category = ""
    var occasions: [String] = []

    enum CodingKeys: String, CodingKey {
        case identified, confidence, name, description, care, section, category, occasions
        case plantKey = "plant_key"
        case scientificName = "scientific_name"
        case heightCm = "height_cm"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identified = try c.decodeIfPresent(Bool.self, forKey: .identified) ?? false
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence) ?? "low"
        plantKey = try c.decodeIfPresent(String.self, forKey: .plantKey) ?? "Other"
        scientificName = try c.decodeIfPresent(String.self, forKey: .scientificName) ?? ""
        name = try c.decodeIfPresent(Tri.self, forKey: .name) ?? Tri()
        description = try c.decodeIfPresent(Tri.self, forKey: .description) ?? Tri()
        care = try c.decodeIfPresent(AiCare.self, forKey: .care) ?? AiCare()
        heightCm = try c.decodeIfPresent(Int.self, forKey: .heightCm) ?? 0
        section = try c.decodeIfPresent(String.self, forKey: .section) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        occasions = try c.decodeIfPresent([String].self, forKey: .occasions) ?? []
    }
}

/// A choice the customer makes before adding a product to the cart, e.g. Colour: Blue / Black.
struct ListingOption: Codable, Equatable {
    var name: String
    var values: [String]
}

// MARK: - Ratings

/// One customer's rating of a delivered order.
struct Rating: Decodable, Identifiable {
    let id: String
    let stars: Int
    let comment: String?
    /// First name and last initial; empty when the customer deleted their account.
    let reviewerName: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, stars, comment
        case reviewerName = "reviewer_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        stars = try c.decode(Int.self, forKey: .stars)
        comment = try c.decodeIfPresent(String.self, forKey: .comment)
        reviewerName = try c.decodeIfPresent(String.self, forKey: .reviewerName) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

// MARK: - Shop review (admin)

/// A shop that is not approved yet, as the admin sees it.
struct PendingShop: Decodable, Identifiable {
    let id: String
    let name: String
    let city: String
    let phone: String
    let bio: String
    let shopTypes: [String]
    /// pending (waiting for the admin), changes_requested (waiting for the shop), rejected.
    let reviewStatus: String
    let reviewNote: String?
    let ownerName: String
    let ownerEmail: String
    let deliveryScope: String
    let deliversTo: [String]
    let deliveryFeeIqd: Int
    let deliveryFees: [String: Int]
    let productCount: Int
    let approved: Bool
    let rating: Double
    let ratingCount: Int
    let address: String
    let district: String
    let neighborhood: String
    let landmark: String
    let addressNotes: String
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, city, phone, bio, address, district, neighborhood, landmark
        case addressNotes = "address_notes"
        case lat, lng
        case deliveryScope = "delivery_scope"
        case deliversTo = "delivers_to"
        case deliveryFeeIqd = "delivery_fee_iqd"
        case deliveryFees = "delivery_fees"
        case productCount = "product_count"
        case approved, rating
        case ratingCount = "rating_count"
        case shopTypes = "shop_types"
        case reviewStatus = "review_status"
        case reviewNote = "review_note"
        case ownerName = "owner_name"
        case ownerEmail = "owner_email"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decode(String.self, forKey: .city)
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        shopTypes = try c.decodeIfPresent([String].self, forKey: .shopTypes) ?? []
        reviewStatus = try c.decodeIfPresent(String.self, forKey: .reviewStatus) ?? "pending"
        reviewNote = try c.decodeIfPresent(String.self, forKey: .reviewNote)
        ownerName = try c.decodeIfPresent(String.self, forKey: .ownerName) ?? ""
        ownerEmail = try c.decodeIfPresent(String.self, forKey: .ownerEmail) ?? ""
        deliveryScope = try c.decodeIfPresent(String.self, forKey: .deliveryScope) ?? "local"
        deliversTo = try c.decodeIfPresent([String].self, forKey: .deliversTo) ?? []
        deliveryFeeIqd = try c.decodeIfPresent(Int.self, forKey: .deliveryFeeIqd) ?? 0
        deliveryFees = try c.decodeIfPresent([String: Int].self, forKey: .deliveryFees) ?? [:]
        productCount = try c.decodeIfPresent(Int.self, forKey: .productCount) ?? 0
        approved = try c.decodeIfPresent(Bool.self, forKey: .approved) ?? false
        rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        ratingCount = try c.decodeIfPresent(Int.self, forKey: .ratingCount) ?? 0
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        neighborhood = try c.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        landmark = try c.decodeIfPresent(String.self, forKey: .landmark) ?? ""
        addressNotes = try c.decodeIfPresent(String.self, forKey: .addressNotes) ?? ""
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
    }
}

/// The three things the admin can do with a shop.
enum ShopDecision: String {
    case approve, changes, reject
}

// MARK: - Address book

/// One address saved by a customer. `label` is home / work / apartment (shown in the app language) or the customer's own text.
struct SavedAddress: Decodable, Identifiable, Equatable {
    let id: String
    let label: String
    let city: String
    let district: String
    let neighborhood: String
    let street: String
    let landmark: String
    let notes: String
    let lat: Double?
    let lng: Double?
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, city, district, neighborhood, street, landmark, notes, lat, lng
        case isDefault = "is_default"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        neighborhood = try c.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        street = try c.decodeIfPresent(String.self, forKey: .street) ?? ""
        landmark = try c.decodeIfPresent(String.self, forKey: .landmark) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}

/// What is sent to the database when an address is saved.
struct AddressInput: Encodable {
    let userId: String
    let label: String
    let city: String
    let district: String
    let neighborhood: String
    let street: String
    let landmark: String
    let notes: String
    let lat: Double?
    let lng: Double?
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case label, city, district, neighborhood, street, landmark, notes, lat, lng
        case userId = "user_id"
        case isDefault = "is_default"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(label, forKey: .label)
        try c.encode(city, forKey: .city)
        try c.encode(district, forKey: .district)
        try c.encode(neighborhood, forKey: .neighborhood)
        try c.encode(street, forKey: .street)
        try c.encode(landmark, forKey: .landmark)
        try c.encode(notes, forKey: .notes)
        try c.encode(lat, forKey: .lat) // nil is sent as null: removing the pin clears it
        try c.encode(lng, forKey: .lng)
        try c.encode(isDefault, forKey: .isDefault)
    }
}

/// A customer can save this many addresses (the database enforces it too).
let maxAddresses = 10
