package com.plantapp.data

import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** A shop that is not approved yet, as the admin sees it. */
@Serializable
data class PendingShop(
    val id: String,
    val name: String,
    val city: String,
    val phone: String = "",
    val bio: String = "",
    @SerialName("shop_types") val shopTypes: List<String> = emptyList(),
    @SerialName("delivery_scope") val deliveryScope: String = "local",
    /** pending (waiting for the admin), changes_requested (waiting for the shop), rejected. */
    @SerialName("review_status") val reviewStatus: String = "pending",
    @SerialName("review_note") val reviewNote: String? = null,
    @SerialName("owner_name") val ownerName: String = "",
    @SerialName("owner_email") val ownerEmail: String = "",
    @SerialName("delivers_to") val deliversTo: List<String>? = null,
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int = 0,
    @SerialName("delivery_fees") val deliveryFees: Map<String, Int> = emptyMap(),
    @SerialName("product_count") val productCount: Int = 0,
)

/** The three things the admin can do with a shop. */
enum class ShopDecision(val db: String) { Approve("approve"), Changes("changes"), Reject("reject") }

/** Calls only the admin account may make; the database refuses everybody else. */
object AdminRepository {
    suspend fun isAdmin(): Boolean =
        Backend.client.postgrest.rpc("is_admin").decodeAs<Boolean>()

    suspend fun shops(): List<PendingShop> =
        Backend.client.postgrest.rpc("admin_pending_shops").decodeList<PendingShop>()

    /** All products of a shop, including shops that are not approved yet. */
    suspend fun listings(shopId: String): List<Listing> =
        Backend.client.postgrest.rpc("admin_shop_listings", buildJsonObject { put("p_shop_id", shopId) }).decodeList<Listing>()

    suspend fun review(shopId: String, decision: ShopDecision, note: String?) {
        Backend.client.postgrest.rpc(
            "admin_review_shop",
            buildJsonObject {
                put("p_shop_id", shopId)
                put("p_decision", decision.db)
                if (!note.isNullOrBlank()) put("p_note", note)
            },
        )
    }
}
