package com.plantapp.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.plantapp.R
import com.plantapp.data.AdminRepository
import com.plantapp.data.Listing
import com.plantapp.data.PendingShop
import com.plantapp.data.Profile
import com.plantapp.data.Rating
import com.plantapp.data.ShopDecision
import com.plantapp.data.localized
import com.plantapp.ui.customer.PlantPicture
import com.plantapp.ui.customer.RatingStarsRow
import com.plantapp.ui.customer.priceText
import com.plantapp.ui.customer.ratingLabel
import com.plantapp.ui.customer.rememberLang
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.ScreenBackground
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted
import kotlinx.coroutines.launch

private val AdminRed = Color(0xFFC62828)

/** What the admin may decide for a shop in each state. */
private fun allowedDecisions(status: String): List<ShopDecision> = when (status) {
    "pending" -> listOf(ShopDecision.Approve, ShopDecision.Changes, ShopDecision.Reject)
    "approved" -> listOf(ShopDecision.Changes, ShopDecision.Reject)
    "changes_requested" -> listOf(ShopDecision.Approve, ShopDecision.Reject)
    else -> listOf(ShopDecision.Approve)
}

private val FILTERS = listOf(
    "pending" to R.string.approvals_filter_waiting,
    "approved" to R.string.approvals_filter_approved,
    "changes_requested" to R.string.approvals_filter_changes,
    "rejected" to R.string.approvals_filter_rejected,
)

/** The home of the admin account: every shop, with the decisions and the moderation tools. No shop, cart or orders. */
@Composable
fun AdminApp(profile: Profile, onSignOut: () -> Unit) {
    var shops by remember { mutableStateOf<List<PendingShop>?>(null) }
    var failed by remember { mutableStateOf(false) }
    var busyId by remember { mutableStateOf<String?>(null) }
    var filter by remember { mutableStateOf("pending") }
    var asking by remember { mutableStateOf<Pair<PendingShop, ShopDecision>?>(null) }
    var previewing by remember { mutableStateOf<PendingShop?>(null) }
    val scope = rememberCoroutineScope()

    suspend fun load() {
        try {
            shops = AdminRepository.shops()
            failed = false
        } catch (_: Exception) {
            failed = true
        }
    }
    LaunchedEffect(Unit) { load() }

    fun decide(shop: PendingShop, decision: ShopDecision, note: String?) {
        scope.launch {
            busyId = shop.id
            try {
                AdminRepository.review(shop.id, decision, note)
                load()
            } catch (_: Exception) {
                failed = true
            }
            busyId = null
        }
    }

    fun choose(shop: PendingShop, decision: ShopDecision) {
        if (decision == ShopDecision.Approve) decide(shop, decision, null) else asking = shop to decision
    }

    Surface(color = ScreenBackground, modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.systemBarsPadding().padding(horizontal = 16.dp)) {
            Text(
                stringResource(R.string.admin_home_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
                modifier = Modifier.padding(top = 12.dp),
            )
            Text("${profile.firstName} ${profile.lastName}".trim(), color = TextMuted)
            Spacer(Modifier.height(10.dp))

            val list = shops
            Row(modifier = Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for ((status, labelRes) in FILTERS) {
                    val count = list?.count { it.reviewStatus == status } ?: 0
                    PickChip(
                        label = stringResource(labelRes) + if (list != null) " ($count)" else "",
                        selected = filter == status,
                        accent = PlantGreen,
                    ) { filter = status }
                }
            }

            Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                when {
                    list == null && !failed -> CircularProgressIndicator(color = PlantGreen, modifier = Modifier.padding(24.dp))
                    list == null -> Text(stringResource(R.string.approvals_failed), color = AdminRed, modifier = Modifier.padding(top = 12.dp))
                    else -> {
                        if (failed) Text(stringResource(R.string.approvals_failed), color = AdminRed)
                        val shown = list.filter { it.reviewStatus == filter }
                        if (shown.isEmpty()) Text(stringResource(R.string.approvals_empty), color = TextMuted, modifier = Modifier.padding(top = 12.dp))
                        shown.forEach { shop ->
                            ShopReviewCard(shop, busy = busyId == shop.id, onView = { previewing = shop }, onDecide = { choose(shop, it) })
                        }
                    }
                }
                Spacer(Modifier.height(24.dp))
                LanguageSelector()
                Spacer(Modifier.height(16.dp))
                OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.action_signout), color = PlantGreen, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }

    previewing?.let { shop ->
        Dialog(onDismissRequest = { previewing = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            ShopPreviewScreen(
                shop = shop,
                busy = busyId == shop.id,
                onClose = { previewing = null },
                onDecide = { decision ->
                    previewing = null
                    choose(shop, decision)
                },
            )
        }
    }

    asking?.let { (shop, decision) ->
        NoteDialog(
            title = stringResource(if (decision == ShopDecision.Changes) R.string.approvals_changes else R.string.approvals_reject),
            hint = stringResource(if (decision == ShopDecision.Changes) R.string.approvals_changes_hint else R.string.approvals_reject_hint),
            onCancel = { asking = null },
            onSend = { note ->
                asking = null
                decide(shop, decision, note)
            },
        )
    }
}

@Composable
private fun ShopReviewCard(shop: PendingShop, busy: Boolean, onView: () -> Unit, onDecide: (ShopDecision) -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(shop.name, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium, color = PlantGreenDark)
            Text(
                cityLabel(shop.city) + if (shop.approved) "  ·  " + ratingLabel(shop.rating, shop.ratingCount) else "",
                color = TextMuted,
            )
            Spacer(Modifier.height(6.dp))
            Text(stringResource(R.string.approvals_owner, shop.ownerName.ifBlank { "-" }, shop.ownerEmail))
            if (shop.phone.isNotBlank()) Text(shop.phone)
            Text(addressText(shop.city, shop.district, shop.neighborhood, shop.address, shop.landmark), color = TextMuted)
            if (shop.shopTypes.isNotEmpty()) Text(shop.shopTypes.map { sectionName(it) }.joinToString(", "), color = TextMuted)
            if (shop.bio.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(shop.bio)
            }
            if (!shop.reviewNote.isNullOrBlank()) {
                Spacer(Modifier.height(6.dp))
                Text(stringResource(R.string.approvals_your_note, shop.reviewNote), color = SellerAmber, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(10.dp))
            Button(onClick = onView, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Text(stringResource(R.string.approvals_view, shop.productCount), fontWeight = FontWeight.Bold)
            }
            DecisionButtons(busy, allowedDecisions(shop.reviewStatus), onDecide)
        }
    }
}

@Composable
private fun NoteDialog(title: String, hint: String, onCancel: () -> Unit, onSend: (String) -> Unit) {
    var note by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = note,
                onValueChange = { if (it.length <= 500) note = it },
                label = { Text(hint) },
                minLines = 3,
                modifier = Modifier.fillMaxWidth(),
            )
        },
        confirmButton = {
            TextButton(onClick = { onSend(note.trim()) }, enabled = note.trim().length >= 3) {
                Text(stringResource(R.string.approvals_send))
            }
        },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(R.string.action_cancel)) } },
    )
}

@Composable
private fun DecisionButtons(busy: Boolean, allowed: List<ShopDecision>, onDecide: (ShopDecision) -> Unit) {
    if (busy) {
        CircularProgressIndicator(color = PlantGreen, modifier = Modifier.height(28.dp))
        return
    }
    for (decision in allowed) {
        when (decision) {
            ShopDecision.Approve -> Button(onClick = { onDecide(decision) }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Text(stringResource(R.string.approvals_approve), fontWeight = FontWeight.Bold)
            }
            ShopDecision.Changes -> OutlinedButton(onClick = { onDecide(decision) }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Text(stringResource(R.string.approvals_changes), color = SellerAmber)
            }
            ShopDecision.Reject -> OutlinedButton(onClick = { onDecide(decision) }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Text(stringResource(R.string.approvals_reject), color = AdminRed)
            }
        }
    }
}

/** Everything a customer would see about the shop, so the admin can decide: details, delivery, every product and the reviews. */
@Composable
private fun ShopPreviewScreen(shop: PendingShop, busy: Boolean, onClose: () -> Unit, onDecide: (ShopDecision) -> Unit) {
    var products by remember(shop.id) { mutableStateOf<List<Listing>?>(null) }
    var ratings by remember(shop.id) { mutableStateOf<List<Rating>>(emptyList()) }
    var failed by remember(shop.id) { mutableStateOf(false) }
    var removingProduct by remember { mutableStateOf<Listing?>(null) }
    var removingRating by remember { mutableStateOf<Rating?>(null) }
    val scope = rememberCoroutineScope()
    val lang = rememberLang()

    suspend fun load() {
        try {
            products = AdminRepository.listings(shop.id)
            ratings = AdminRepository.ratings(shop.id)
            failed = false
        } catch (_: Exception) {
            failed = true
        }
    }
    LaunchedEffect(shop.id) { load() }

    Surface(color = ScreenBackground, modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(shop.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = PlantGreenDark, modifier = Modifier.weight(1f))
                TextButton(onClick = onClose) { Text(stringResource(R.string.approvals_close)) }
            }
            Text(cityLabel(shop.city) + if (shop.approved) "  ·  " + ratingLabel(shop.rating, shop.ratingCount) else "", color = TextMuted)
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.approvals_owner, shop.ownerName.ifBlank { "-" }, shop.ownerEmail))
            if (shop.phone.isNotBlank()) Text(shop.phone)
            Text(addressText(shop.city, shop.district, shop.neighborhood, shop.address, shop.landmark))
            if (shop.addressNotes.isNotBlank()) Text(shop.addressNotes, color = TextMuted)
            if (shop.lat != null && shop.lng != null) {
                val context = androidx.compose.ui.platform.LocalContext.current
                TextButton(onClick = { openInMaps(context, shop.lat, shop.lng, shop.name) }) { Text(stringResource(R.string.map_open)) }
            }
            if (shop.shopTypes.isNotEmpty()) Text(shop.shopTypes.map { sectionName(it) }.joinToString(", "), color = TextMuted)
            if (shop.bio.isNotBlank()) {
                Spacer(Modifier.height(6.dp))
                Text(shop.bio)
            }
            Spacer(Modifier.height(10.dp))
            Text(stringResource(R.string.shop_delivery), fontWeight = FontWeight.Bold, color = PlantGreenDark)
            Text(
                if (shop.deliveryScope == "nationwide") stringResource(R.string.delivers_nationwide)
                else shop.deliversTo.orEmpty().map { cityLabel(it) }.joinToString(", ").ifBlank { cityLabel(shop.city) },
            )
            Text(stringResource(R.string.shop_fee_title) + ": " + priceText(shop.deliveryFeeIqd))
            shop.deliveryFees.forEach { (city, fee) -> Text(cityLabel(city) + ": " + priceText(fee), color = TextMuted) }
            if (!shop.reviewNote.isNullOrBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(stringResource(R.string.approvals_your_note, shop.reviewNote), color = SellerAmber)
            }

            Spacer(Modifier.height(14.dp))
            Text(stringResource(R.string.approvals_products, products?.size ?: shop.productCount), fontWeight = FontWeight.Bold, color = PlantGreenDark)
            val list = products
            when {
                list == null && !failed -> CircularProgressIndicator(color = PlantGreen, modifier = Modifier.padding(16.dp))
                list == null -> Text(stringResource(R.string.approvals_failed), color = AdminRed)
                list.isEmpty() -> Text(stringResource(R.string.approvals_no_products), color = TextMuted)
                else -> list.forEach { ProductPreview(it, lang, onRemove = { removingProduct = it }) }
            }

            Spacer(Modifier.height(14.dp))
            Text(stringResource(R.string.approvals_reviews, ratings.size), fontWeight = FontWeight.Bold, color = PlantGreenDark)
            if (ratings.isEmpty() && products != null) Text(stringResource(R.string.approvals_no_reviews), color = TextMuted)
            ratings.forEach { rating ->
                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        RatingStarsRow(rating.stars)
                        Text(rating.reviewerName.ifBlank { stringResource(R.string.reviewer_anonymous) }, fontWeight = FontWeight.SemiBold)
                        Text(rating.createdAt.take(10), color = TextMuted, style = MaterialTheme.typography.bodySmall)
                    }
                    rating.comment?.takeIf { it.isNotBlank() }?.let { Text(it) }
                    TextButton(onClick = { removingRating = rating }) {
                        Text(stringResource(R.string.approvals_delete_review), color = AdminRed)
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            DecisionButtons(busy, allowedDecisions(shop.reviewStatus), onDecide)
            Spacer(Modifier.height(24.dp))
        }
    }

    removingProduct?.let { listing ->
        NoteDialog(
            title = stringResource(R.string.approvals_delete_product),
            hint = stringResource(R.string.approvals_delete_hint),
            onCancel = { removingProduct = null },
            onSend = { note ->
                removingProduct = null
                scope.launch {
                    try {
                        AdminRepository.deleteListing(listing.id, note)
                        load()
                    } catch (_: Exception) {
                        failed = true
                    }
                }
            },
        )
    }
    removingRating?.let { rating ->
        NoteDialog(
            title = stringResource(R.string.approvals_delete_review),
            hint = stringResource(R.string.approvals_delete_review_hint),
            onCancel = { removingRating = null },
            onSend = { note ->
                removingRating = null
                scope.launch {
                    try {
                        AdminRepository.deleteRating(rating.id, note)
                        load()
                    } catch (_: Exception) {
                        failed = true
                    }
                }
            },
        )
    }
}

@Composable
private fun ProductPreview(listing: Listing, lang: String, onRemove: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
    ) {
        Column {
            val photo = listing.imageUrl
            if (photo != null) TapToZoomImage(photo, shape = RoundedCornerShape(0.dp))
            else PlantPicture(listing, Modifier.fillMaxWidth().height(160.dp), 64.sp)
            Column(modifier = Modifier.padding(12.dp)) {
                Text(listing.name.localized(lang), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium, color = PlantGreenDark)
                Text(
                    listOfNotNull(sectionName(listing.section), listing.category?.let { categoryName(it) }, listing.collection?.takeIf { it.isNotBlank() }).joinToString("  ·  "),
                    color = TextMuted,
                    style = MaterialTheme.typography.bodySmall,
                )
                Spacer(Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(priceText(listing.priceIqd), fontWeight = FontWeight.Bold)
                    listing.oldPriceIqd?.takeIf { it > listing.priceIqd }?.let {
                        Text(priceText(it), color = TextMuted, textDecoration = TextDecoration.LineThrough)
                    }
                }
                listing.pieces?.let { Text(stringResource(R.string.approvals_pieces, it), color = TextMuted, style = MaterialTheme.typography.bodySmall) }
                if (!listing.inStock) Text(stringResource(R.string.approvals_out_of_stock), color = AdminRed, style = MaterialTheme.typography.bodySmall)
                val description = listing.description.localized(lang)
                if (description.isNotBlank()) {
                    Spacer(Modifier.height(4.dp))
                    Text(description, style = MaterialTheme.typography.bodyMedium)
                }
                listing.options.forEach { option ->
                    Text(option.name + ": " + option.values.joinToString(", "), color = TextMuted, style = MaterialTheme.typography.bodySmall)
                }
                TextButton(onClick = onRemove) { Text(stringResource(R.string.approvals_delete_product), color = AdminRed) }
            }
        }
    }
}
