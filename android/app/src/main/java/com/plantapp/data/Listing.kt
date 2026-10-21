package com.plantapp.data

import io.github.jan.supabase.storage.storage
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SellerInfo(
    val id: String,
    val name: String,
    val city: String,
    @SerialName("delivery_scope") val deliveryScope: String = "local",
    @SerialName("delivers_to") val deliversTo: List<String>? = null,
    val rating: Double = 0.0,
    @SerialName("rating_count") val ratingCount: Int = 0,
    val phone: String = "",
    val bio: String = "",
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int = 0,
    /** City code -> fee, for cities that cost more or less than [deliveryFeeIqd]. */
    @SerialName("delivery_fees") val deliveryFees: Map<String, Int> = emptyMap(),
    @SerialName("shop_types") val shopTypes: List<String> = emptyList(),
) {
    val isNationwide: Boolean get() = deliveryScope == "nationwide"

    /** What this shop charges to deliver to [city]. */
    fun feeFor(city: String): Int = deliveryFees[city] ?: deliveryFeeIqd
}

/** A choice the customer makes before adding a product to the cart, e.g. Colour: Blue / Black. */
@Serializable
data class ListingOption(val name: String, val values: List<String>)

/** One plant offered by one shop. Text fields are maps keyed by language code (en / ar / ckb). */
@Serializable
data class Listing(
    val id: String,
    @SerialName("seller_id") val sellerId: String,
    /** flowers / plants / gifts (see Catalog). Rows from before sections existed are plants. */
    val section: String = "plants",
    val category: String? = null,
    @SerialName("plant_key") val plantKey: String? = null,
    val name: Map<String, String> = emptyMap(),
    @SerialName("scientific_name") val scientificName: String? = null,
    val description: Map<String, String> = emptyMap(),
    val care: Map<String, Map<String, String>> = emptyMap(),
    @SerialName("height_cm") val heightCm: Int? = null,
    @SerialName("pot_size_cm") val potSizeCm: Int? = null,
    @SerialName("price_iqd") val priceIqd: Int,
    /** The price before a discount; shown crossed out next to [priceIqd]. */
    @SerialName("old_price_iqd") val oldPriceIqd: Int? = null,
    /** How many pieces are in this package, for sets and bundles. */
    val pieces: Int? = null,
    val options: List<ListingOption> = emptyList(),
    /** A named group in the shop (Autumn 2026, Ramadan, ...). */
    val collection: String? = null,
    @SerialName("in_stock") val inStock: Boolean = true,
    /** off / optional / required: whether the shop sends a photo for the customer to approve before delivery. */
    @SerialName("photo_approval") val photoApproval: String = "off",
    @SerialName("image_path") val imagePath: String? = null,
    @SerialName("ai_generated") val aiGenerated: Boolean = false,
    val occasions: List<String> = emptyList(),
    val sellers: SellerInfo? = null,
) {
    /** Public URL of the shop's photo, or null when the listing has none yet. */
    val imageUrl: String?
        get() = imagePath?.takeIf { it.isNotBlank() }?.let(::plantPhotoUrl)

    /** Percent off when [oldPriceIqd] is above the current price, else null. */
    val discountPercent: Int?
        get() = oldPriceIqd?.takeIf { it > priceIqd && it > 0 }?.let { (it - priceIqd) * 100 / it }

    /** Emoji shown as the picture until a shop uploads a photo. */
    val placeholderEmoji: String
        get() = if (section == Catalog.PLANTS) plantEmoji(plantKey) else Catalog.categoryEmoji(category)
}

/** Public link to a photo stored in the plant-photos bucket. */
fun plantPhotoUrl(path: String): String = Backend.client.storage.from("plant-photos").publicUrl(path)

/** Picks the text for [lang], falling back sensibly when a language is missing. */
fun Map<String, String>.localized(lang: String): String =
    this[lang]
        ?: (if (lang == "ckb") this["ar"] else null)
        ?: this["en"]
        ?: this["ar"]
        ?: values.firstOrNull()
        ?: ""

/** Whether this listing's shop delivers to [city]. */
fun Listing.deliversTo(city: String): Boolean {
    val shop = sellers ?: return false
    return shop.city == city || shop.isNationwide || shop.deliversTo?.contains(city) == true
}

/** Emoji used as the picture until a shop uploads a real photo. */
fun plantEmoji(key: String?): String = when (key) {
    "Cactus" -> "🌵"
    "Palm" -> "🌴"
    "Rose" -> "🌹"
    "Orchid" -> "🌸"
    "Jasmine" -> "🌼"
    "Bonsai" -> "🌳"
    "Mint", "Basil", "Fern" -> "🌿"
    "Aloe Vera", "Succulents" -> "🪴"
    else -> "🪴"
}
