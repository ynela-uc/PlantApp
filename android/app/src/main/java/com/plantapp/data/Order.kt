package com.plantapp.data

import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order as SortOrder
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.time.Duration.Companion.hours

/** One line of an order. Defaults keep older prototype rows (different shape) decodable. */
@Serializable
data class OrderItem(
    @SerialName("listing_id") val listingId: String = "",
    val name: Map<String, String> = emptyMap(),
    val qty: Int = 1,
    @SerialName("unit_price_iqd") val unitPriceIqd: Int = 0,
    /** The customer's choices for this line, option name -> chosen value. */
    val options: Map<String, String> = emptyMap(),
)

/** How long the customer has to answer a photo; after that the shop can continue (checked by the database too). */
const val PHOTO_WAIT_MINUTES = 60L

/** Reasons a shop can give when it declines or cancels an order. */
val ShopCancelReasons = listOf("out_of_stock", "cant_deliver_day", "cant_make", "other")

/** Reasons a shop can give when an order could not be delivered. */
val FailedDeliveryReasons = listOf("no_answer", "refused", "wrong_address", "other")

/** Order progress, in the order a customer sees it. */
enum class OrderStatus(val db: String) {
    Placed("placed"),
    Preparing("preparing"),
    PhotoSent("photo_sent"),
    Approved("approved"),
    OutForDelivery("out_for_delivery"),
    Delivered("delivered"),
    Cancelled("cancelled");

    companion object {
        fun fromDb(value: String?): OrderStatus = entries.firstOrNull { it.db == value } ?: Placed

        /** The steps shown on the timeline (cancelled is shown on its own). */
        val timeline = listOf(Placed, Preparing, PhotoSent, Approved, OutForDelivery, Delivered)

        /** Orders without a photo step go straight from preparing to out for delivery. */
        val timelineWithoutPhoto = listOf(Placed, Preparing, OutForDelivery, Delivered)
    }
}

@Serializable
data class Order(
    val id: String,
    @SerialName("seller_id") val sellerId: String,
    @SerialName("seller_name") val sellerName: String = "",
    val items: List<OrderItem> = emptyList(),
    @SerialName("payment_method") val paymentMethod: String = "cod",
    val status: String = "placed",
    val city: String = "",
    val address: String = "",
    val district: String = "",
    val neighborhood: String = "",
    val landmark: String = "",
    @SerialName("address_notes") val addressNotes: String = "",
    @SerialName("created_at") val createdAt: String = "",
    @SerialName("total_iqd") val totalIqd: Int = 0,
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int = 0,
    @SerialName("is_gift") val isGift: Boolean = false,
    @SerialName("recipient_name") val recipientName: String? = null,
    @SerialName("recipient_phone") val recipientPhone: String? = null,
    @SerialName("gift_note") val giftNote: String? = null,
    @SerialName("delivery_date") val deliveryDate: String? = null,
    @SerialName("delivery_window") val deliveryWindow: String = "any",
    @SerialName("preparation_photo_path") val preparationPhotoPath: String? = null,
    @SerialName("change_request") val changeRequest: String? = null,
    @SerialName("buyer_name") val buyerName: String = "",
    @SerialName("buyer_phone") val buyerPhone: String = "",
    /** True when the shop must send a photo that the customer approves before delivery. */
    @SerialName("photo_required") val photoRequired: Boolean = false,
    @SerialName("photo_sent_at") val photoSentAt: String? = null,
    /** Why a cancelled order was cancelled (see [ShopCancelReasons]) and by whom: customer, shop or system. */
    @SerialName("cancel_reason") val cancelReason: String? = null,
    @SerialName("cancelled_by") val cancelledBy: String? = null,
) {
    val statusEnum: OrderStatus get() = OrderStatus.fromDb(status)

    /** The steps this order goes through (with or without the photo approval). */
    val timeline: List<OrderStatus> get() = if (photoRequired) OrderStatus.timeline else OrderStatus.timelineWithoutPhoto

    /** The customer has not answered the photo within [PHOTO_WAIT_MINUTES]: the shop may continue. */
    val photoAnswerOverdue: Boolean
        get() = statusEnum == OrderStatus.PhotoSent && photoSentAt?.let {
            runCatching { java.time.OffsetDateTime.parse(it).toInstant().plusSeconds(PHOTO_WAIT_MINUTES * 60).isBefore(java.time.Instant.now()) }
                .getOrDefault(false)
        } == true
    val itemCount: Int get() = items.sumOf { it.qty }
}

@Serializable
data class NewOrder(
    @SerialName("buyer_id") val buyerId: String,
    @SerialName("seller_id") val sellerId: String,
    @SerialName("seller_name") val sellerName: String,
    val items: List<OrderItem>,
    @SerialName("payment_method") val paymentMethod: String = "cod",
    val city: String,
    val address: String,
    val district: String = "",
    val neighborhood: String = "",
    val landmark: String = "",
    @SerialName("address_notes") val addressNotes: String = "",
    @SerialName("total_iqd") val totalIqd: Int,
    @SerialName("delivery_fee_iqd") val deliveryFeeIqd: Int = 0,
    @SerialName("buyer_name") val buyerName: String,
    @SerialName("buyer_phone") val buyerPhone: String,
    @SerialName("is_gift") val isGift: Boolean,
    @SerialName("recipient_name") val recipientName: String? = null,
    @SerialName("recipient_phone") val recipientPhone: String? = null,
    @SerialName("gift_note") val giftNote: String? = null,
    @SerialName("delivery_date") val deliveryDate: String,
    @SerialName("delivery_window") val deliveryWindow: String,
    @SerialName("photo_requested") val photoRequested: Boolean = false,
)

class OrdersRepository {
    suspend fun create(order: NewOrder) {
        Backend.client.from("orders").insert(order)
    }

    /** Customer cancels an order the shop has not accepted yet. */
    suspend fun cancel(orderId: String) {
        Backend.client.postgrest.rpc("customer_cancel_order", buildJsonObject { put("p_order_id", orderId) })
    }

    /** Customer's answer to the preparation photo: approve it, or ask the shop to change something. */
    suspend fun reviewPhoto(orderId: String, approve: Boolean, note: String?) {
        Backend.client.postgrest.rpc(
            "customer_review_photo",
            buildJsonObject {
                put("p_order_id", orderId)
                put("p_approve", approve)
                if (!note.isNullOrBlank()) put("p_note", note)
            },
        )
    }

    /** Short-lived link to the (private) preparation photo. */
    suspend fun signedPhotoUrl(path: String): String =
        Backend.client.storage.from("order-photos").createSignedUrl(path, 1.hours)

    suspend fun fetchMine(buyerId: String): List<Order> =
        Backend.client.from("orders")
            .select {
                filter { eq("buyer_id", buyerId) }
                order("created_at", SortOrder.DESCENDING)
            }
            .decodeList<Order>()
}
