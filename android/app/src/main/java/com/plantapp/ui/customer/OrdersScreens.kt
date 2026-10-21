package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.layout.ContentScale
import coil3.compose.AsyncImage
import com.plantapp.ui.TapToZoomImage
import com.plantapp.ui.rememberSignedPhotoUrl
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Order
import com.plantapp.data.OrderStatus
import com.plantapp.data.localized
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.TextMuted

private val CancelledRed = Color(0xFFC62828)

/** "Name (Blue · Large) × 2" */
internal fun itemLabel(item: com.plantapp.data.OrderItem, lang: String): String {
    val choices = if (item.options.isEmpty()) "" else " (" + item.options.values.joinToString(" · ") + ")"
    return "${item.name.localized(lang)}$choices × ${item.qty}"
}

internal fun statusLabel(status: OrderStatus): Int = when (status) {
    OrderStatus.Placed -> R.string.status_placed
    OrderStatus.Preparing -> R.string.status_preparing
    OrderStatus.PhotoSent -> R.string.status_photo_sent
    OrderStatus.Approved -> R.string.status_approved
    OrderStatus.OutForDelivery -> R.string.status_out_for_delivery
    OrderStatus.Delivered -> R.string.status_delivered
    OrderStatus.Cancelled -> R.string.status_cancelled
}

internal fun windowLabel(window: String): Int = when (window) {
    "morning" -> R.string.window_morning
    "afternoon" -> R.string.window_afternoon
    "evening" -> R.string.window_evening
    else -> R.string.window_any
}

@Composable
fun OrdersTab(
    state: CustomerState,
    onOpen: (String) -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    Column(modifier = modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.orders_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(12.dp))
        when {
            state.ordersLoading && state.orders.isEmpty() -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = PlantGreen)
            }
            state.ordersFailed && state.orders.isEmpty() -> Column(
                Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                Text(stringResource(R.string.orders_load_failed), color = TextMuted, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                Button(onClick = onRetry) { Text(stringResource(R.string.retry)) }
            }
            state.orders.isEmpty() -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("📦", fontSize = 56.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.orders_empty), fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.orders_empty_hint), color = TextMuted, textAlign = TextAlign.Center)
                }
            }
            else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(state.orders, key = { it.id }) { order -> OrderCard(order, lang) { onOpen(order.id) } }
                item { Spacer(Modifier.height(12.dp)) }
            }
        }
    }
}

@Composable
private fun OrderCard(order: Order, lang: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(order.sellerName, fontWeight = FontWeight.Bold, color = PlantGreenDark, modifier = Modifier.weight(1f))
                StatusChip(order.statusEnum)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text = order.items.joinToString(", ") { "${it.name.localized(lang)} × ${it.qty}" },
                style = MaterialTheme.typography.bodyMedium,
                color = TextMuted,
            )
            Spacer(Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(order.createdAt.take(10), style = MaterialTheme.typography.bodySmall, color = TextMuted)
                if (order.totalIqd > 0) Text(priceText(order.totalIqd), fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
internal fun StatusChip(status: OrderStatus) {
    val cancelled = status == OrderStatus.Cancelled
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (cancelled) Color(0xFFFFEBEE) else PlantGreenSoft)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(
            text = stringResource(statusLabel(status)),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = if (cancelled) CancelledRed else PlantGreenDark,
        )
    }
}

@Composable
fun OrderDetailScreen(
    order: Order,
    reviewBusy: Boolean,
    onReview: (approve: Boolean, note: String?) -> Unit,
    onCancel: () -> Unit,
    shopPhone: String?,
    onBack: () -> Unit,
) {
    val lang = rememberLang()
    val status = order.statusEnum
    val photoUrl by rememberSignedPhotoUrl(order.preparationPhotoPath)
    var askingChange by rememberSaveable { mutableStateOf(false) }
    var changeNote by rememberSaveable { mutableStateOf("") }
    var confirmCancel by rememberSaveable { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState())) {
        val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
        TextButton(onClick = onBack, modifier = Modifier.padding(horizontal = 8.dp)) {
            Text("$backArrow  ${stringResource(R.string.back)}", color = PlantGreen)
        }
        Column(modifier = Modifier.padding(horizontal = 20.dp)) {
            Text(
                text = stringResource(R.string.order_number, order.id.take(6).uppercase()),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Text(order.sellerName, color = TextMuted)
            Spacer(Modifier.height(20.dp))

            // The shop's photo of the prepared order, waiting for the customer's answer
            if (status == OrderStatus.PhotoSent) {
                Surface(shape = RoundedCornerShape(18.dp), color = PlantGreenSoft) {
                    Column(modifier = Modifier.fillMaxWidth().padding(14.dp)) {
                        Text(
                            text = stringResource(R.string.review_title),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = PlantGreenDark,
                        )
                        Text(stringResource(R.string.review_body), color = TextMuted, style = MaterialTheme.typography.bodyMedium)
                        Text(stringResource(R.string.review_timeout_note), color = TextMuted, style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(10.dp))
                        if (photoUrl != null) {
                            TapToZoomImage(photoUrl, shape = RoundedCornerShape(14.dp))
                        } else {
                            Box(Modifier.fillMaxWidth().height(120.dp), Alignment.Center) {
                                CircularProgressIndicator(color = PlantGreen)
                            }
                        }
                        Spacer(Modifier.height(12.dp))
                        Button(
                            onClick = { onReview(true, null) },
                            enabled = !reviewBusy,
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                            shape = RoundedCornerShape(14.dp),
                        ) {
                            if (reviewBusy) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                            else Text(stringResource(R.string.review_approve), fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(
                            onClick = { askingChange = true },
                            enabled = !reviewBusy,
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                            shape = RoundedCornerShape(14.dp),
                        ) { Text(stringResource(R.string.review_change), color = PlantGreen) }
                    }
                }
                Spacer(Modifier.height(20.dp))
            }
            if (status == OrderStatus.Preparing && !order.changeRequest.isNullOrBlank()) {
                Surface(shape = RoundedCornerShape(12.dp), color = Color(0xFFFFF3E0)) {
                    Column(Modifier.fillMaxWidth().padding(12.dp)) {
                        Text(stringResource(R.string.review_you_asked), fontWeight = FontWeight.Bold, color = Color(0xFF8A5A00))
                        Text(order.changeRequest)
                    }
                }
                Spacer(Modifier.height(20.dp))
            }

            // Timeline
            if (status == OrderStatus.Cancelled) {
                StatusChip(status)
                order.cancelReason?.let {
                    Spacer(Modifier.height(6.dp))
                    Text(stringResource(R.string.order_cancelled_reason, cancelReasonLabel(it)), color = TextMuted)
                }
            } else {
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

            if (status == OrderStatus.Placed) {
                Spacer(Modifier.height(20.dp))
                OutlinedButton(
                    onClick = { confirmCancel = true },
                    enabled = !reviewBusy,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(14.dp),
                ) { Text(stringResource(R.string.cancel_my_order), color = CancelledRed) }
            }

            if (status == OrderStatus.Delivered) {
                Spacer(Modifier.height(20.dp))
                RateOrderSection(order.id)
            }

            if (!shopPhone.isNullOrBlank()) {
                Spacer(Modifier.height(20.dp))
                Heading(R.string.contact_title)
                com.plantapp.ui.ContactButtons(shopPhone, stringResource(R.string.contact_order_message, order.id.take(6).uppercase()))
            }

            Spacer(Modifier.height(24.dp))
            Heading(R.string.order_items)
            order.items.forEach {
                Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(itemLabel(it, lang), modifier = Modifier.weight(1f))
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
                Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.cart_total), fontWeight = FontWeight.Bold)
                    Text(priceText(order.totalIqd), fontWeight = FontWeight.Bold)
                }
            }

            Spacer(Modifier.height(24.dp))
            Heading(R.string.checkout_delivery)
            if (order.isGift) {
                Text(stringResource(R.string.order_gift_for, order.recipientName.orEmpty()), fontWeight = FontWeight.SemiBold)
                order.recipientPhone?.let { Text(it, color = TextMuted) }
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

            Spacer(Modifier.height(24.dp))
            Heading(R.string.checkout_payment)
            Text(stringResource(R.string.pay_cod))
            Spacer(Modifier.height(32.dp))
        }
    }

    if (askingChange) {
        AlertDialog(
            onDismissRequest = { askingChange = false },
            title = { Text(stringResource(R.string.review_change)) },
            text = {
                OutlinedTextField(
                    value = changeNote,
                    onValueChange = { if (it.length <= 300) changeNote = it },
                    label = { Text(stringResource(R.string.review_change_hint)) },
                    minLines = 2,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        askingChange = false
                        onReview(false, changeNote.trim())
                        changeNote = ""
                    },
                    enabled = changeNote.isNotBlank(),
                ) { Text(stringResource(R.string.review_change_send)) }
            },
            dismissButton = { TextButton(onClick = { askingChange = false }) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
    if (confirmCancel) {
        AlertDialog(
            onDismissRequest = { confirmCancel = false },
            title = { Text(stringResource(R.string.cancel_confirm_title)) },
            text = { Text(stringResource(R.string.cancel_confirm_body)) },
            confirmButton = {
                TextButton(onClick = { confirmCancel = false; onCancel() }) {
                    Text(stringResource(R.string.cancel_confirm_yes), color = CancelledRed)
                }
            },
            dismissButton = { TextButton(onClick = { confirmCancel = false }) { Text(stringResource(R.string.cancel_confirm_no)) } },
        )
    }
}

@Composable
internal fun Heading(res: Int) {
    Text(
        text = stringResource(res),
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        color = PlantGreenDark,
        modifier = Modifier.padding(bottom = 8.dp),
    )
}

@Composable
internal fun TimelineRow(label: String, done: Boolean, current: Boolean, last: Boolean) {
    Row(verticalAlignment = Alignment.Top) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(if (current) 22.dp else 18.dp)
                    .clip(CircleShape)
                    .background(if (done) PlantGreen else Color(0xFFD0D8D0)),
                contentAlignment = Alignment.Center,
            ) {
                if (done) Text("✓", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            if (!last) {
                Box(
                    modifier = Modifier
                        .size(width = 2.dp, height = 22.dp)
                        .background(if (done) PlantGreen else Color(0xFFD0D8D0)),
                )
            }
        }
        Spacer(Modifier.size(14.dp))
        Text(
            text = label,
            fontWeight = if (current) FontWeight.Bold else FontWeight.Normal,
            color = if (done) PlantGreenDark else TextMuted,
        )
    }
}

@Composable
fun OrderPlacedScreen(count: Int, onViewOrders: () -> Unit, onKeepShopping: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier.size(96.dp).clip(CircleShape).background(PlantGreen),
            contentAlignment = Alignment.Center,
        ) { Text("✓", color = Color.White, fontSize = 52.sp, fontWeight = FontWeight.Bold) }
        Spacer(Modifier.height(24.dp))
        Text(
            text = stringResource(R.string.placed_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.placed_body),
            style = MaterialTheme.typography.bodyLarge,
            color = TextMuted,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(32.dp))
        Button(onClick = onViewOrders, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(14.dp)) {
            Text(stringResource(R.string.placed_view_orders), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(10.dp))
        OutlinedButton(onClick = onKeepShopping, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(14.dp)) {
            Text(stringResource(R.string.placed_keep_shopping), color = PlantGreen)
        }
    }
}
