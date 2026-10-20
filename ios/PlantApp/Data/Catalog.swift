import Foundation

/// A product type the shopper can pick on the home screen. Keys match listings.section in the database.
struct CatalogSection: Identifiable {
    let key: String
    let emoji: String
    let categories: [CatalogCategory]
    var id: String { key }
}

struct CatalogCategory: Identifiable {
    let key: String
    let emoji: String
    var id: String { key }
}

/// A reason to buy (birthday, Eid, ...). Keys match the values stored in listings.occasions.
struct CatalogOccasion: Identifiable {
    let key: String
    let emoji: String
    var id: String { key }
}

/// The fixed list of sections, categories and occasions. Keep in sync with docs/categories.md and the Android Catalog.kt.
enum Catalog {
    static let flowers = "flowers"
    static let plants = "plants"
    static let gifts = "gifts"

    static let sections: [CatalogSection] = [
        CatalogSection(key: flowers, emoji: "🌸", categories: [
            CatalogCategory(key: "bouquets", emoji: "💐"),
            CatalogCategory(key: "roses", emoji: "🌹"),
            CatalogCategory(key: "flower_boxes", emoji: "🌷"),
            CatalogCategory(key: "baskets", emoji: "🧺"),
            CatalogCategory(key: "weddings_events", emoji: "🎊"),
            CatalogCategory(key: "wreaths", emoji: "🏵️"),
            CatalogCategory(key: "dried_preserved", emoji: "🌾"),
            CatalogCategory(key: "artificial_flowers", emoji: "🌺"),
        ]),
        CatalogSection(key: plants, emoji: "🪴", categories: [
            CatalogCategory(key: "indoor", emoji: "🪴"),
            CatalogCategory(key: "outdoor", emoji: "🌳"),
            CatalogCategory(key: "succulents_cacti", emoji: "🌵"),
            CatalogCategory(key: "flowering", emoji: "🌼"),
            CatalogCategory(key: "trees_palms", emoji: "🌴"),
            CatalogCategory(key: "herbs", emoji: "🌿"),
            CatalogCategory(key: "bonsai", emoji: "🎋"),
            CatalogCategory(key: "soil", emoji: "🟤"),
            CatalogCategory(key: "fertilizer", emoji: "🧪"),
            CatalogCategory(key: "pots", emoji: "🏺"),
            CatalogCategory(key: "tools", emoji: "✂️"),
            CatalogCategory(key: "seeds_bulbs", emoji: "🌰"),
        ]),
        CatalogSection(key: gifts, emoji: "🎁", categories: [
            CatalogCategory(key: "gift_sets", emoji: "🎁"),
            CatalogCategory(key: "chocolate_sweets", emoji: "🍫"),
            CatalogCategory(key: "personalised", emoji: "✨"),
            CatalogCategory(key: "home_decor", emoji: "🏠"),
            CatalogCategory(key: "candles_fragrance", emoji: "🕯️"),
            CatalogCategory(key: "cards_wrapping", emoji: "💌"),
            CatalogCategory(key: "plush_toys", emoji: "🧸"),
            CatalogCategory(key: "accessories_jewelry", emoji: "💍"),
            CatalogCategory(key: "balloons_party", emoji: "🎈"),
        ]),
    ]

    static let occasions: [CatalogOccasion] = [
        CatalogOccasion(key: "birthday", emoji: "🎂"),
        CatalogOccasion(key: "anniversary", emoji: "💞"),
        CatalogOccasion(key: "love", emoji: "❤️"),
        CatalogOccasion(key: "new_baby", emoji: "👶"),
        CatalogOccasion(key: "get_well", emoji: "🌻"),
        CatalogOccasion(key: "congratulations", emoji: "🎉"),
        CatalogOccasion(key: "new_home", emoji: "🏡"),
        CatalogOccasion(key: "graduation", emoji: "🎓"),
        CatalogOccasion(key: "wedding", emoji: "🥂"),
        CatalogOccasion(key: "condolence", emoji: "🕊️"),
        CatalogOccasion(key: "mothers_day", emoji: "🌷"),
        CatalogOccasion(key: "eid", emoji: "🌙"),
        CatalogOccasion(key: "thank_you", emoji: "🙏"),
    ]

    static func section(_ key: String?) -> CatalogSection? { sections.first { $0.key == key } }

    static func categoryEmoji(_ key: String?) -> String {
        sections.flatMap(\.categories).first { $0.key == key }?.emoji ?? "🛍️"
    }

    static func occasionEmoji(_ key: String) -> String { occasions.first { $0.key == key }?.emoji ?? "🎀" }
}
