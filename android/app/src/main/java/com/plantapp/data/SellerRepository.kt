package com.plantapp.data

import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order as SortOrder
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID

/** The signed-in seller's own shop row. */
@Serializable
data class Shop(
    val id: String,
    val name: String,
    val city: String,
    @SerialName("delivery_scope") val deliveryScope: String = "local",
    @SerialName("delivers_to") val deliversTo: List<String>? = null,
    val rating: Double = 0.0,
    val phone: String = "",
    val bio: String = "",
    @SerialName("shop_types") val shopTypes: List<String> = listOf(Catalog.PLANTS),
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int = 0,
    @SerialName("delivery_fees") val deliveryFees: Map<String, Int> = emptyMap(),
) {
    val isNationwide: Boolean get() = deliveryScope == "nationwide"
}

@Serializable
data class ShopUpdate(
    val name: String,
    val phone: String,
    val bio: String,
    @SerialName("delivery_scope") val deliveryScope: String,
    @SerialName("delivers_to") val deliversTo: List<String>?,
    @SerialName("shop_types") val shopTypes: List<String>,
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int,
    @SerialName("delivery_fees") val deliveryFees: Map<String, Int>,
)

@Serializable
data class NewListing(
    @SerialName("seller_id") val sellerId: String,
    val section: String,
    val category: String?,
    val occasions: List<String>,
    @SerialName("plant_key") val plantKey: String?,
    val name: Map<String, String>,
    @SerialName("scientific_name") val scientificName: String?,
    val description: Map<String, String>,
    val care: Map<String, Map<String, String>>,
    @SerialName("height_cm") val heightCm: Int?,
    @SerialName("price_iqd") val priceIqd: Int,
    @SerialName("old_price_iqd") val oldPriceIqd: Int?,
    val pieces: Int?,
    val options: List<ListingOption>,
    val collection: String?,
    @SerialName("image_path") val imagePath: String?,
    @SerialName("in_stock") val inStock: Boolean,
    @SerialName("ai_generated") val aiGenerated: Boolean,
)

@Serializable
data class ListingUpdate(
    val section: String,
    val category: String?,
    val occasions: List<String>,
    @SerialName("plant_key") val plantKey: String?,
    val name: Map<String, String>,
    @SerialName("scientific_name") val scientificName: String?,
    val description: Map<String, String>,
    val care: Map<String, Map<String, String>>,
    @SerialName("height_cm") val heightCm: Int?,
    @SerialName("price_iqd") val priceIqd: Int,
    @SerialName("old_price_iqd") val oldPriceIqd: Int?,
    val pieces: Int?,
    val options: List<ListingOption>,
    val collection: String?,
    @SerialName("image_path") val imagePath: String?,
    @SerialName("in_stock") val inStock: Boolean,
    @SerialName("ai_generated") val aiGenerated: Boolean,
)

class SellerRepository {
    suspend fun fetchShop(ownerId: String): Shop? =
        Backend.client.from("sellers")
            .select { filter { eq("owner_id", ownerId) } }
            .decodeSingleOrNull<Shop>()

    suspend fun updateShop(shopId: String, update: ShopUpdate) {
        Backend.client.from("sellers").update(update) { filter { eq("id", shopId) } }
    }

    suspend fun fetchListings(shopId: String): List<Listing> =
        Backend.client.from("listings")
            .select {
                filter { eq("seller_id", shopId) }
                order("created_at", SortOrder.DESCENDING)
            }
            .decodeList<Listing>()

    suspend fun createListing(listing: NewListing) {
        Backend.client.from("listings").insert(listing)
    }

    suspend fun updateListing(id: String, listing: ListingUpdate) {
        Backend.client.from("listings").update(listing) { filter { eq("id", id) } }
    }

    suspend fun setInStock(id: String, inStock: Boolean) {
        Backend.client.from("listings").update({ set("in_stock", inStock) }) { filter { eq("id", id) } }
    }

    suspend fun deleteListing(id: String) {
        Backend.client.from("listings").delete { filter { eq("id", id) } }
    }

    suspend fun fetchOrders(shopId: String): List<Order> =
        Backend.client.from("orders")
            .select {
                filter { eq("seller_id", shopId) }
                order("created_at", SortOrder.DESCENDING)
            }
            .decodeList<Order>()

    /** Moves an order along its status steps; the database checks that the change is allowed. */
    suspend fun setOrderStatus(orderId: String, status: OrderStatus, photoPath: String? = null) {
        Backend.client.postgrest.rpc(
            "seller_set_order_status",
            buildJsonObject {
                put("p_order_id", orderId)
                put("p_status", status.db)
                if (photoPath != null) put("p_photo_path", photoPath)
            },
        )
    }

    /** Uploads a plant photo into the seller's own folder and returns its storage path. */
    suspend fun uploadPlantPhoto(ownerId: String, jpeg: ByteArray): String {
        val path = "$ownerId/${UUID.randomUUID()}.jpg"
        Backend.client.storage.from("plant-photos").upload(path, jpeg)
        return path
    }

    /** Uploads (or replaces) the photo shown to the customer for approval. */
    suspend fun uploadOrderPhoto(orderId: String, jpeg: ByteArray): String {
        val path = "$orderId/photo.jpg"
        Backend.client.storage.from("order-photos").upload(path, jpeg) { upsert = true }
        return path
    }
}
