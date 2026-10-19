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
    val phone: String = "",
) {
    val isNationwide: Boolean get() = deliveryScope == "nationwide"
}

/** One plant offered by one shop. Text fields are maps keyed by language code (en / ar / ckb). */
@Serializable
data class Listing(
    val id: String,
    @SerialName("seller_id") val sellerId: String,
    @SerialName("plant_key") val plantKey: String? = null,
    val name: Map<String, String> = emptyMap(),
    @SerialName("scientific_name") val scientificName: String? = null,
    val description: Map<String, String> = emptyMap(),
    val care: Map<String, Map<String, String>> = emptyMap(),
    @SerialName("height_cm") val heightCm: Int? = null,
    @SerialName("pot_size_cm") val potSizeCm: Int? = null,
    @SerialName("price_iqd") val priceIqd: Int,
    @SerialName("in_stock") val inStock: Boolean = true,
    @SerialName("image_path") val imagePath: String? = null,
    @SerialName("ai_generated") val aiGenerated: Boolean = false,
    val occasions: List<String> = emptyList(),
    val sellers: SellerInfo? = null,
) {
    /** Public URL of the shop's photo, or null when the listing has none yet. */
    val imageUrl: String?
        get() = imagePath?.takeIf { it.isNotBlank() }?.let(::plantPhotoUrl)
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
