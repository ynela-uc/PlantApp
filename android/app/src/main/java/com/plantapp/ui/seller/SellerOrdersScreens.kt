package com.plantapp.ui.seller

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.plantapp.R
import com.plantapp.data.FailedDeliveryReasons
import com.plantapp.data.Order
import com.plantapp.data.ShopCancelReasons
import com.plantapp.data.OrderStatus
import com.plantapp.data.localized
import com.plantapp.ui.cityLabel
import com.plantapp.ui.customer.Heading
import com.plantapp.ui.customer.StatusChip
import com.plantapp.ui.customer.TimelineRow
import com.plantapp.ui.customer.priceText
import com.plantapp.ui.customer.rememberLang
import com.plantapp.ui.customer.statusLabel
import com.plantapp.ui.customer.windowLabel
import com.plantapp.ui.rememberPhotoCapture
import com.plantapp.ui.rememberSignedPhotoUrl
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted

private val ErrorRed = Color(0xFFC62828)

@Composable
fun SellerOrdersTab(
    state: SellerState,
    onOpen: (String) -> Unit,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    Column(modifier = modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = stringResource(R.string.seller_orders_title),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = PlantGreenDark,
                )
                state.shop?.let { Text(it.name, color = TextMuted, style = MaterialTheme.typography.bodyMedium) }
            }
            TextButton(onClick = onRefresh) { Text("↻", fontSize = 22.sp, color = SellerAmber) }
        }
        if (state.newOrderCount > 0) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.seller_new_orders, state.newOrderCount),
                color = SellerAmber,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.height(12.dp))

        if (state.orders.isEmpty()) {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
                    Text("📦", fontSize = 56.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.seller_orders_empty), fontWeight = FontWeight.Bold)
                    Text(
                        stringResource(R.string.seller_orders_empty_hint),
                        color = TextMuted,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(state.orders, key = { it.id }) { order ->
                    SellerOrderCard(order, lang) { onOpen(order.id) }
                }
                item { Spacer(Modifier.height(12.dp)) }
            }
        }
    }
}

@Composable
private fun SellerOrderCard(order: Order, lang: String, onClick: () -> Unit) {
    val needsAction = order.statusEnum == OrderStatus.Placed || order.statusEnum == OrderStatus.Approved
    Surface(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = BorderStroke(if (needsAction) 2.dp else 1.dp, if (needsAction) SellerAmber else CardBorder),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = order.buyerName.ifBlank { "#" + order.id.take(6).uppercase() },
                    fontWeight = FontWeight.Bold,
                    color = PlantGreenDark,
                    modifier = Modifier.weight(1f),
                )
                StatusChip(order.statusEnum)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text = order.items.joinToString(", ") { com.plantapp.ui.customer.itemLabel(it, lang) },
                style = MaterialTheme.typography.bodyMedium,
                color = TextMuted,
            )
            Spacer(Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    text = "${cityLabel(order.city)}  ·  ${order.createdAt.take(10)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextMuted,
                )
                if (order.totalIqd > 0) Text(priceText(order.totalIqd), fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun SellerOrderDetailScreen(
    order: Order,
    busy: Boolean,
    actionFailed: Boolean,
    onStatus: (OrderStatus, String?) -> Unit,
    onPhoto: (ByteArray) -> Unit,
    onBack: () -> Unit,
) {
    val lang = rememberLang()
    val context = LocalContext.current
    val status = order.statusEnum
    val capture = rememberPhotoCapture(onPhoto)
    val photoUrl by rememberSignedPhotoUrl(order.preparationPhotoPath)
    val waMessage = stringResource(R.string.contact_customer_message, order.id.take(6).uppercase(), order.sellerName)
    /** Which list of reasons is being asked for: cancel ("shop") or failed delivery ("failed"); null = no question open. */
    var askReason by rememberSaveable { mutableStateOf<String?>(null) }

    fun dial(number: String) {
        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")))
    }

    Column(modifier = Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState())) {
        val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
        TextButton(onClick = onBack, modifier = Modifier.padding(horizontal = 8.dp)) {
            Text("$backArrow  ${stringResource(R.string.back)}", color = SellerAmber)
        }
        Column(modifier = Modifier.padding(horizontal = 20.dp)) {
            Text(
                text = stringResource(R.string.order_number, order.id.take(6).uppercase()),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Spacer(Modifier.height(6.dp))
            StatusChip(status)

            // Customer
            Spacer(Modifier.height(20.dp))
            Heading(R.string.seller_customer)
            Text(order.buyerName.ifBlank { "—" }, fontWeight = FontWeight.SemiBold)
            if (status == OrderStatus.Placed) {
                Text(stringResource(R.string.cancel_no_phone_yet), color = TextMuted, style = MaterialTheme.typography.bodySmall)
            } else if (order.buyerPhone.isNotBlank()) {
                CallRow(order.buyerPhone, waMessage) { dial(order.buyerPhone) }
            }

            // Items
            Spacer(Modifier.height(20.dp))
            Heading(R.string.order_items)
            order.items.forEach {
                Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(com.plantapp.ui.customer.itemLabel(it, lang), modifier = Modifier.weight(1f))
                    if (it.unitPriceIqd > 0) Text(priceText(it.unitPriceIqd * it.qty))
                }
            }
            if (order.deliveryFeeIqd > 0) {
                Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.delivery_fee_label), color = TextMuted)
                    Text(priceText(order.deliveryFeeIqd))
                }
            }
            if (order.totalIqd > 0) {
                Spacer(Modifier.height(8.dp))
                Surface(shape = RoundedCornerShape(12.dp), color = Color(0xFFFFF3E0)) {
                    Text(
                        text = stringResource(R.string.seller_collect, priceText(order.totalIqd)),
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        fontWeight = FontWeight.Bold,
                        color = SellerAmber,
                    )
                }
            }

            // Delivery
            Spacer(Modifier.height(20.dp))
            Heading(R.string.checkout_delivery)
            if (order.isGift) {
                Text(stringResource(R.string.order_gift_for, order.recipientName.orEmpty()), fontWeight = FontWeight.SemiBold)
                if (status != OrderStatus.Placed) order.recipientPhone?.takeIf { it.isNotBlank() }?.let { CallRow(it, waMessage) { dial(it) } }
                order.giftNote?.takeIf { it.isNotBlank() }?.let {
                    Spacer(Modifier.height(6.dp))
                    Text("“$it”", style = MaterialTheme.typography.bodyMedium)
                }
                Spacer(Modifier.height(6.dp))
            }
            Text("${cityLabel(order.city)}, ${order.address}")
            order.deliveryDate?.let {
                Text("$it  ·  ${stringResource(windowLabel(order.deliveryWindow))}", color = TextMuted)
            }

            // Photo
            if (photoUrl != null) {
                Spacer(Modifier.height(20.dp))
                Heading(R.string.seller_photo_sent)
                AsyncImage(
                    model = photoUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(16.dp)),
                )
            }

            // What the customer asked to change
            if (status == OrderStatus.Preparing && !order.changeRequest.isNullOrBlank()) {
                Spacer(Modifier.height(16.dp))
                Surface(shape = RoundedCornerShape(12.dp), color = Color(0xFFFFEBEE)) {
                    Column(Modifier.fillMaxWidth().padding(12.dp)) {
                        Text(stringResource(R.string.seller_change_requested), fontWeight = FontWeight.Bold, color = ErrorRed)
                        Text(order.changeRequest)
                    }
                }
            }

            // Progress
            if (status != OrderStatus.Cancelled) {
                Spacer(Modifier.height(24.dp))
                val reached = order.timeline.indexOf(status)
                order.timeline.forEachIndexed { index, step ->
                    TimelineRow(
                        label = stringResource(statusLabel(step)),
                        done = index <= reached,
                        current = index == reached,
                        last = index == order.timeline.lastIndex,
                    )
                }
            }

            // Actions
            Spacer(Modifier.height(24.dp))
            if (actionFailed) {
                Text(stringResource(R.string.seller_action_failed), color = ErrorRed)
                Spacer(Modifier.height(8.dp))
            }
            when (status) {
                OrderStatus.Placed -> {
                    ActionButton(R.string.act_accept, busy) { onStatus(OrderStatus.Preparing, null) }
                    Spacer(Modifier.height(8.dp))
                    DangerButton(R.string.act_decline, busy) { askReason = "shop" }
                }
                OrderStatus.Preparing -> if (!order.photoRequired) {
                    ActionButton(R.string.act_out_for_delivery, busy) { onStatus(OrderStatus.OutForDelivery, null) }
                    Spacer(Modifier.height(8.dp))
                    DangerButton(R.string.act_cancel_order, busy) { askReason = "shop" }
                } else {
                    Text(stringResource(R.string.photo_prompt_title), fontWeight = FontWeight.Bold, color = PlantGreenDark)
                    Text(stringResource(R.string.photo_prompt_body), color = TextMuted)
                    Spacer(Modifier.height(10.dp))
                    if (busy) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.size(22.dp), color = SellerAmber, strokeWidth = 2.dp)
                            Spacer(Modifier.size(10.dp))
                            Text(stringResource(R.string.photo_uploading))
                        }
                    } else {
                        ActionButton(R.string.photo_take, false) { capture.takePhoto() }
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(
                            onClick = capture.pickPhoto,
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                            shape = RoundedCornerShape(14.dp),
                        ) { Text(stringResource(R.string.photo_pick), color = SellerAmber) }
                        Spacer(Modifier.height(8.dp))
                        DangerButton(R.string.act_cancel_order, false) { askReason = "shop" }
                    }
                }
                OrderStatus.PhotoSent -> if (order.photoAnswerOverdue) {
                    Text(
                        stringResource(R.string.seller_waiting_approval_timeout),
                        color = TextMuted,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(8.dp))
                    ActionButton(R.string.act_continue_no_answer, busy) { onStatus(OrderStatus.Approved, null) }
                } else {
                    Text(
                        stringResource(R.string.seller_waiting_approval),
                        color = TextMuted,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(8.dp))
                    DangerButton(R.string.act_cancel_order, busy) { askReason = "shop" }
                }
                OrderStatus.Approved -> {
                    ActionButton(R.string.act_out_for_delivery, busy) { onStatus(OrderStatus.OutForDelivery, null) }
                    Spacer(Modifier.height(8.dp))
                    DangerButton(R.string.act_cancel_order, busy) { askReason = "shop" }
                }
                OrderStatus.OutForDelivery -> {
                    ActionButton(R.string.act_mark_delivered, busy) { onStatus(OrderStatus.Delivered, null) }
                    Spacer(Modifier.height(8.dp))
                    DangerButton(R.string.act_delivery_failed, busy) { askReason = "failed" }
                }
                OrderStatus.Delivered, OrderStatus.Cancelled -> Unit
            }
            Spacer(Modifier.height(40.dp))
        }
    }

    val reasons = if (askReason == "failed") FailedDeliveryReasons else ShopCancelReasons
    if (askReason != null) {
        AlertDialog(
            onDismissRequest = { askReason = null },
            title = { Text(stringResource(R.string.reason_title)) },
            text = {
                Column {
                    reasons.forEach { key ->
                        OutlinedButton(
                            onClick = {
                                askReason = null
                                onStatus(OrderStatus.Cancelled, key)
                            },
                            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                            shape = RoundedCornerShape(12.dp),
                        ) { Text(com.plantapp.ui.customer.cancelReasonLabel(key), color = PlantGreenDark) }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { askReason = null }) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
}

@Composable
private fun CallRow(number: String, whatsappMessage: String, onCall: () -> Unit) {
    val context = LocalContext.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(number, color = TextMuted, modifier = Modifier.weight(1f))
        TextButton(onClick = onCall) {
            Text("📞  " + stringResource(R.string.seller_call), color = PlantGreen, fontWeight = FontWeight.SemiBold)
        }
        TextButton(onClick = { com.plantapp.ui.openWhatsApp(context, number, whatsappMessage) }) {
            Text("💬  " + stringResource(R.string.contact_whatsapp), color = PlantGreen, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun ActionButton(labelRes: Int, busy: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = !busy,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = SellerAmber),
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
        else Text(stringResource(labelRes), fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun DangerButton(labelRes: Int, busy: Boolean, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        enabled = !busy,
        modifier = Modifier.fillMaxWidth().height(50.dp),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, ErrorRed),
    ) { Text(stringResource(labelRes), color = ErrorRed, fontWeight = FontWeight.SemiBold) }
}
