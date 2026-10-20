package com.plantapp.data

/** A product type the shopper can pick on the home screen. Keys match listings.section in the database. */
data class Section(val key: String, val emoji: String, val categories: List<Category>)

data class Category(val key: String, val emoji: String)

/** A reason to buy (birthday, Eid, ...). Keys match the values stored in listings.occasions. */
data class Occasion(val key: String, val emoji: String)

/** The fixed list of sections, categories and occasions. Keep in sync with docs/categories.md and the iOS Catalog.swift. */
object Catalog {
    const val FLOWERS = "flowers"
    const val PLANTS = "plants"
    const val GIFTS = "gifts"

    val sections: List<Section> = listOf(
        Section(
            FLOWERS, "🌸",
            listOf(
                Category("bouquets", "💐"),
                Category("roses", "🌹"),
                Category("flower_boxes", "🌷"),
                Category("baskets", "🧺"),
                Category("weddings_events", "💒"),
                Category("condolence", "🕊️"),
                Category("dried_preserved", "🌾"),
                Category("artificial_flowers", "🌺"),
            ),
        ),
        Section(
            PLANTS, "🪴",
            listOf(
                Category("indoor", "🪴"),
                Category("outdoor", "🌳"),
                Category("succulents_cacti", "🌵"),
                Category("flowering", "🌼"),
                Category("trees_palms", "🌴"),
                Category("herbs", "🌿"),
                Category("bonsai_orchids", "🎋"),
                Category("soil", "🟤"),
                Category("fertilizer", "🧪"),
                Category("pots", "🏺"),
                Category("tools", "✂️"),
                Category("pest_care", "🐛"),
                Category("seeds_bulbs", "🌰"),
            ),
        ),
        Section(
            GIFTS, "🎁",
            listOf(
                Category("gift_sets", "🎁"),
                Category("chocolate_sweets", "🍫"),
                Category("cakes", "🎂"),
                Category("personalised", "✨"),
                Category("home_decor", "🏠"),
                Category("candles_fragrance", "🕯️"),
                Category("cards_wrapping", "💌"),
                Category("plush_toys", "🧸"),
                Category("accessories_jewelry", "💍"),
                Category("balloons_party", "🎈"),
            ),
        ),
    )

    val occasions: List<Occasion> = listOf(
        Occasion("birthday", "🎂"),
        Occasion("anniversary", "💞"),
        Occasion("love", "❤️"),
        Occasion("new_baby", "👶"),
        Occasion("get_well", "🌻"),
        Occasion("congratulations", "🎉"),
        Occasion("new_home", "🏡"),
        Occasion("graduation", "🎓"),
        Occasion("wedding", "💒"),
        Occasion("condolence", "🕊️"),
        Occasion("mothers_day", "🌷"),
        Occasion("eid", "🌙"),
        Occasion("thank_you", "🙏"),
    )

    fun section(key: String?): Section? = sections.firstOrNull { it.key == key }

    fun categoryEmoji(key: String?): String =
        sections.flatMap { it.categories }.firstOrNull { it.key == key }?.emoji ?: "🛍️"

    fun occasionEmoji(key: String): String = occasions.firstOrNull { it.key == key }?.emoji ?: "🎀"
}
