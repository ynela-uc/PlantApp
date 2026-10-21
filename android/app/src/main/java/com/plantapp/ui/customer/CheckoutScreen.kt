package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.MAX_ADDRESSES
import com.plantapp.data.Profile
import com.plantapp.data.localized
import com.plantapp.ui.AddressDraft
import com.plantapp.ui.AddressFields
import com.plantapp.ui.CityCodes
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

private val ErrorRed = Color(0xFFC62828)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CheckoutScreen(
    state: CustomerState,
    profile: Profile,
    onBack: () -> Unit,
    onPlace: (CheckoutForm) -> Unit,
) {
    val lang = rememberLang()
    var isGift by rememberSaveable { mutableStateOf(false) }
    var recipientName by rememberSaveable { mutableStateOf("") }
    var recipientPhone by rememberSaveable { mutableStateOf("") }
    var addr by rememberSaveable(stateSaver = AddressDraft.Saver) {
        mutableStateOf(AddressDraft(state.city, profile.district, profile.neighborhood, profile.address, profile.landmark, profile.addressNotes))
    }
    var note by rememberSaveable { mutableStateOf("") }
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var choseOther by rememberSaveable { mutableStateOf(false) }
    var saveNew by rememberSaveable { mutableStateOf(false) }
    var dayOffset by rememberSaveable { mutableIntStateOf(0) }
    var window by rememberSaveable { mutableStateOf("any") }
    var fieldsError by rememberSaveable { mutableStateOf(false) }
    var photoRequested by rememberSaveable { mutableStateOf(false) }

    // The saved addresses arrive a moment after the page opens: start with the default one.
    LaunchedEffect(state.addresses) {
        if (!choseOther && selectedId == null && state.addresses.isNotEmpty()) {
            val first = state.addresses.firstOrNull { it.isDefault } ?: state.addresses.first()
            selectedId = first.id
            addr = first.toDraft()
        }
    }

    val today = LocalDate.now()
    val dateFormat = DateTimeFormatter.ofPattern("d MMM", Locale.getDefault())

    Column(modifier = Modifier.fillMaxSize().systemBarsPadding().imePadding()) {
        Column(
            modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        ) {
            val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
            TextButton(onClick = onBack) { Text("$backArrow  ${stringResource(R.string.back)}", color = PlantGreen) }
            Text(
                text = stringResource(R.string.checkout_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )

            // Who is it for
            SectionTitle(R.string.checkout_who)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Pill(stringResource(R.string.checkout_for_me), !isGift, Modifier.weight(1f)) { isGift = false }
                Pill("🎁  " + stringResource(R.string.checkout_gift), isGift, Modifier.weight(1f)) { isGift = true }
            }
            if (isGift) {
                Spacer(Modifier.height(12.dp))
                Input(recipientName, { recipientName = it; fieldsError = false }, R.string.recipient_name)
                Input(recipientPhone, { recipientPhone = it; fieldsError = false }, R.string.recipient_phone, KeyboardType.Phone)
                Input(note, { if (it.length <= 200) note = it }, R.string.gift_note, singleLine = false)
            }

            // Delivery
            SectionTitle(R.string.checkout_delivery)
            AddressPicker(
                addresses = state.addresses,
                selectedId = selectedId,
                draft = addr,
                saveNew = saveNew,
                onSelect = { selectedId = it.id; choseOther = false; addr = it.toDraft(); fieldsError = false },
                onOther = { selectedId = null; choseOther = true; fieldsError = false },
                onDraft = { addr = it; fieldsError = false },
                onSaveNew = { saveNew = it },
            )

            Text(stringResource(R.string.delivery_date), style = MaterialTheme.typography.labelLarge, color = TextMuted)
            Spacer(Modifier.height(6.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                (0..3).forEach { offset ->
                    val label = when (offset) {
                        0 -> stringResource(R.string.delivery_today)
                        1 -> stringResource(R.string.delivery_tomorrow)
                        else -> today.plusDays(offset.toLong()).format(dateFormat)
                    }
                    Pill(label, dayOffset == offset) { dayOffset = offset }
                }
            }
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.delivery_window), style = MaterialTheme.typography.labelLarge, color = TextMuted)
            Spacer(Modifier.height(6.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    "any" to R.string.window_any,
                    "morning" to R.string.window_morning,
                    "afternoon" to R.string.window_afternoon,
                    "evening" to R.string.window_evening,
                ).forEach { (key, res) -> Pill(stringResource(res), window == key) { window = key } }
            }

            // Photo approval: shown only when something in the cart offers or needs it
            val photoOptional = state.cartLines.any { it.listing.photoApproval == "optional" }
            val photoRequired = state.cartLines.any { it.listing.photoApproval == "required" }
            if (photoOptional || photoRequired) {
                SectionTitle(R.string.checkout_photo_title)
                if (photoRequired) {
                    Text(stringResource(R.string.checkout_photo_required), color = TextMuted, style = MaterialTheme.typography.bodyMedium)
                }
                if (photoOptional) {
                    Row(
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().clickable { photoRequested = !photoRequested },
                    ) {
                        androidx.compose.material3.Checkbox(checked = photoRequested, onCheckedChange = { photoRequested = it })
                        Text(stringResource(R.string.checkout_photo_optional))
                    }
                }
            }

            // Payment
            SectionTitle(R.string.checkout_payment)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Pill(stringResource(R.string.pay_cod), true, Modifier.weight(1f)) { }
                Surface(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    color = Color(0xFFF0F0F0),
                ) {
                    Text(
                        text = stringResource(R.string.pay_card_soon),
                        modifier = Modifier.padding(vertical = 12.dp).fillMaxWidth(),
                        color = Color(0xFF9E9E9E),
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }
            }

            // Summary
            SectionTitle(R.string.checkout_summary)
            val groups = state.cartGroups(addr.city)
            groups.forEach { group ->
                Text(
                    text = stringResource(R.string.sold_by, group.shop?.name.orEmpty()),
                    style = MaterialTheme.typography.labelLarge,
                    color = TextMuted,
                    modifier = Modifier.padding(top = 8.dp),
                )
                group.lines.forEach { line ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        val choices = if (line.options.isEmpty()) "" else " (" + line.options.values.joinToString(" · ") + ")"
                        Text("${line.listing.name.localized(lang)}$choices × ${line.qty}", modifier = Modifier.weight(1f))
                        Text(priceText(line.total))
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(stringResource(R.string.delivery_to_city, cityLabel(addr.city)), color = TextMuted, modifier = Modifier.weight(1f))
                    Text(if (group.fee == 0) stringResource(R.string.delivery_free) else priceText(group.fee))
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(stringResource(R.string.total_with_delivery), fontWeight = FontWeight.Bold)
                Text(priceText(state.grandTotal(addr.city)), fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(16.dp))
        }

        Surface(shadowElevation = 8.dp, color = Color.White) {
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                val errorText = when (val e = state.checkoutError) {
                    is CheckoutError.NotDeliverable -> stringResource(
                        R.string.err_not_deliverable, e.shops.joinToString(", "), cityLabel(addr.city),
                    )
                    CheckoutError.PriceChanged -> stringResource(R.string.err_price_changed)
                    CheckoutError.Unavailable -> stringResource(R.string.err_unavailable)
                    CheckoutError.Network -> stringResource(R.string.err_network)
                    CheckoutError.Generic -> stringResource(R.string.err_generic)
                    null -> if (fieldsError) stringResource(R.string.err_checkout_fields) else null
                }
                if (errorText != null) {
                    Text(errorText, color = ErrorRed, style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(8.dp))
                }
                Button(
                    onClick = {
                        val missing = !addr.isComplete || (isGift && (recipientName.isBlank() || recipientPhone.isBlank()))
                        if (missing) {
                            fieldsError = true
                        } else {
                            fieldsError = false
                            onPlace(
                                CheckoutForm(
                                    isGift = isGift,
                                    recipientName = recipientName.trim(),
                                    recipientPhone = recipientPhone.trim(),
                                    city = addr.city,
                                    address = addr.trimmed().street,
                                    district = addr.trimmed().district,
                                    neighborhood = addr.trimmed().neighborhood,
                                    landmark = addr.trimmed().landmark,
                                    addressNotes = addr.trimmed().notes,
                                    lat = addr.lat,
                                    lng = addr.lng,
                                    giftNote = note.trim(),
                                    deliveryDate = today.plusDays(dayOffset.toLong()).toString(),
                                    window = window,
                                    photoRequested = photoRequested,
                                    saveAsAddress = selectedId == null && saveNew && state.addresses.size < MAX_ADDRESSES,
                                )
                            )
                        }
                    },
                    enabled = !state.placing && state.cartLines.isNotEmpty(),
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    if (state.placing) {
                        CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                    } else {
                        Text(
                            text = stringResource(R.string.place_order) + "  ·  " + priceText(state.grandTotal(addr.city)),
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(res: Int) {
    Text(
        text = stringResource(res),
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        color = PlantGreenDark,
        modifier = Modifier.padding(top = 24.dp, bottom = 10.dp),
    )
}

@Composable
private fun Pill(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = if (selected) PlantGreen else Color.White,
        border = BorderStroke(1.dp, if (selected) PlantGreen else CardBorder),
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp).fillMaxWidth(),
            color = if (selected) Color.White else Color(0xFF333333),
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
private fun Input(
    value: String,
    onChange: (String) -> Unit,
    labelRes: Int,
    keyboardType: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(stringResource(labelRes)) },
        singleLine = singleLine,
        minLines = if (singleLine) 1 else 2,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
    )
}
