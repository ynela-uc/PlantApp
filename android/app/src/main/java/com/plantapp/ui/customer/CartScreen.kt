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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.localized
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

@Composable
fun CartScreen(
    state: CustomerState,
    onChangeQuantity: (key: String, delta: Int) -> Unit,
    onOpen: (String) -> Unit,
    onCheckout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    val groups = state.cartGroups(state.city)

    Column(modifier = modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.cart_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(12.dp))

        if (groups.isEmpty()) {
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🛒", fontSize = 56.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.cart_empty), fontWeight = FontWeight.Bold)
                    Text(
                        stringResource(R.string.cart_empty_hint),
                        color = TextMuted,
                        textAlign = TextAlign.Center,
                    )
                }
            }
            return@Column
        }

        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            groups.forEach { group ->
                item(key = "shop-${group.sellerId}") {
                    Text(
                        text = stringResource(R.string.sold_by, group.shop?.name.orEmpty()),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = TextMuted,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                items(group.lines.size, key = { group.lines[it].key }) { index ->
                    val line = group.lines[index]
                    CartLineRow(line, lang, onChangeQuantity) { onOpen(line.listing.id) }
                }
                item(key = "fee-${group.sellerId}") {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(stringResource(R.string.delivery_to_city, cityLabel(state.city)), color = TextMuted, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            if (group.fee == 0) stringResource(R.string.delivery_free) else priceText(group.fee),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }

        Surface(color = Color.White, shadowElevation = 6.dp, shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(stringResource(R.string.total_with_delivery), fontWeight = FontWeight.Bold)
                    Text(priceText(state.grandTotal(state.city)), fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(10.dp))
                Button(
                    onClick = onCheckout,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(stringResource(R.string.cart_checkout), fontWeight = FontWeight.Bold)
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun CartLineRow(
    line: CartLine,
    lang: String,
    onChangeQuantity: (String, Int) -> Unit,
    onOpen: () -> Unit,
) {
    val listing = line.listing
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).clickable(onClick = onOpen),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PlantPicture(listing, Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)), 28.sp)
            Column(modifier = Modifier.weight(1f)) {
                Text(listing.name.localized(lang), fontWeight = FontWeight.Bold, color = PlantGreenDark)
                if (line.options.isNotEmpty()) {
                    Text(
                        text = line.options.values.joinToString(" · "),
                        style = MaterialTheme.typography.bodySmall,
                        color = TextMuted,
                    )
                }
                Text(priceText(line.total), style = MaterialTheme.typography.bodyMedium)
            }
            Stepper(line.qty) { delta -> onChangeQuantity(line.key, delta) }
        }
    }
}

@Composable
private fun Stepper(qty: Int, onDelta: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StepButton("−") { onDelta(-1) }
        Text(qty.toString(), fontWeight = FontWeight.Bold)
        StepButton("+") { onDelta(1) }
    }
}

@Composable
private fun StepButton(symbol: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier.size(32.dp).clip(CircleShape).background(PlantGreen).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(symbol, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp) }
}
