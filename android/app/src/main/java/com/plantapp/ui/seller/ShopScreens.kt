package com.plantapp.ui.seller

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Profile
import com.plantapp.data.Shop
import com.plantapp.data.ShopUpdate
import com.plantapp.ui.CityCodes
import com.plantapp.ui.LanguageSelector
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted

@Composable
fun ShopTab(
    shop: Shop,
    profile: Profile,
    onEdit: () -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Text(
            text = shop.name,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Text(cityLabel(shop.city), color = TextMuted)
        Spacer(Modifier.height(16.dp))
        InfoRow(R.string.field_phone, shop.phone)
        InfoRow(
            R.string.shop_delivery,
            if (shop.isNationwide) stringResource(R.string.delivers_nationwide)
            else shop.deliversTo.orEmpty().map { cityLabel(it) }.joinToString(", "),
        )
        if (shop.bio.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(shop.bio)
        }
        Spacer(Modifier.height(4.dp))
        Text(stringResource(R.string.shop_owner, "${profile.firstName} ${profile.lastName}".trim()), style = MaterialTheme.typography.bodySmall, color = TextMuted)

        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = onEdit, modifier = Modifier.fillMaxWidth().height(50.dp), shape = RoundedCornerShape(14.dp)) {
            Text(stringResource(R.string.shop_edit), color = SellerAmber, fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(28.dp))
        LanguageSelector()

        Spacer(Modifier.height(28.dp))
        OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.action_signout), color = SellerAmber, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun InfoRow(labelRes: Int, value: String) {
    if (value.isBlank()) return
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(stringResource(labelRes), color = TextMuted)
        Text(value, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 16.dp))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ShopEditorScreen(
    shop: Shop,
    saving: Boolean,
    onBack: () -> Unit,
    onSave: (ShopUpdate) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf(shop.name) }
    var phone by rememberSaveable { mutableStateOf(shop.phone) }
    var bio by rememberSaveable { mutableStateOf(shop.bio) }
    var nationwide by rememberSaveable { mutableStateOf(shop.isNationwide) }
    val cities = remember_cities(shop.deliversTo.orEmpty())
    var showError by rememberSaveable { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize().systemBarsPadding().imePadding()) {
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
            TextButton(onClick = onBack) { Text("$backArrow  ${stringResource(R.string.back)}", color = SellerAmber) }
            Text(
                text = stringResource(R.string.shop_edit),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(name, { name = it; showError = false }, label = { Text(stringResource(R.string.field_shop_name)) }, singleLine = true, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp))
            OutlinedTextField(phone, { phone = it; showError = false }, label = { Text(stringResource(R.string.field_phone)) }, singleLine = true, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp))
            OutlinedTextField(bio, { bio = it }, label = { Text(stringResource(R.string.field_bio)) }, minLines = 3, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp))

            Text(stringResource(R.string.shop_delivery), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp, bottom = 8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Choice(stringResource(R.string.shop_scope_local), !nationwide, Modifier.weight(1f)) { nationwide = false }
                Choice(stringResource(R.string.shop_scope_nationwide), nationwide, Modifier.weight(1f)) { nationwide = true }
            }
            if (!nationwide) {
                Spacer(Modifier.height(12.dp))
                Text(stringResource(R.string.shop_delivers_to), style = MaterialTheme.typography.labelLarge, color = TextMuted)
                Spacer(Modifier.height(8.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    CityCodes.forEach { code ->
                        val selected = code in cities
                        Choice(cityLabel(code), selected) { if (selected) cities.remove(code) else cities.add(code) }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
        Surface(shadowElevation = 8.dp, color = Color.White) {
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                if (showError) {
                    Text(stringResource(R.string.err_required), color = Color(0xFFC62828), style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(8.dp))
                }
                Button(
                    onClick = {
                        if (name.isBlank() || phone.isBlank() || (!nationwide && cities.isEmpty())) {
                            showError = true
                        } else {
                            onSave(
                                ShopUpdate(
                                    name = name.trim(),
                                    phone = phone.trim(),
                                    bio = bio.trim(),
                                    deliveryScope = if (nationwide) "nationwide" else "local",
                                    deliversTo = if (nationwide) null else cities.toList(),
                                )
                            )
                        }
                    },
                    enabled = !saving,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SellerAmber),
                ) {
                    if (saving) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                    else Text(stringResource(R.string.action_save), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

/** City selection that survives rotation/language change. */
@Composable
private fun remember_cities(initial: List<String>) =
    rememberSaveable(saver = androidx.compose.runtime.saveable.listSaver<androidx.compose.runtime.snapshots.SnapshotStateList<String>, String>(
        save = { it.toList() },
        restore = { saved -> mutableStateListOf<String>().also { it.addAll(saved) } },
    )) { mutableStateListOf<String>().also { it.addAll(initial) } }

@Composable
private fun Choice(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = if (selected) SellerAmber else Color.White,
        border = BorderStroke(1.dp, if (selected) SellerAmber else CardBorder),
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp).fillMaxWidth(),
            color = if (selected) Color.White else Color(0xFF333333),
            fontWeight = FontWeight.SemiBold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
