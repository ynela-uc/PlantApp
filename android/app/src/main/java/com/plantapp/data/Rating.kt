package com.plantapp.data

import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** One customer's rating of a delivered order. */
@Serializable
data class Rating(
    val id: String,
    val stars: Int,
    val comment: String? = null,
    /** First name and last initial; empty when the customer deleted their account. */
    @SerialName("reviewer_name") val reviewerName: String = "",
    @SerialName("created_at") val createdAt: String = "",
)

object RatingsRepository {
    /** The latest ratings of a shop. */
    suspend fun forShop(shopId: String): List<Rating> =
        Backend.client.from("ratings")
            .select {
                filter { eq("seller_id", shopId) }
                order("created_at", Order.DESCENDING)
                limit(10)
            }
            .decodeList<Rating>()

    /** The rating of one order, or null when it was not rated yet. */
    suspend fun forOrder(orderId: String): Rating? =
        Backend.client.from("ratings")
            .select { filter { eq("order_id", orderId) } }
            .decodeSingleOrNull<Rating>()

    suspend fun rate(orderId: String, stars: Int, comment: String) {
        Backend.client.postgrest.rpc(
            "rate_order",
            buildJsonObject {
                put("p_order_id", orderId)
                put("p_stars", stars)
                if (comment.isNotBlank()) put("p_comment", comment)
            },
        )
    }
}
