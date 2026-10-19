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
import com.plantapp.data.Listing
import com.plantapp.data.localized
import com.plantapp.data.plantEmoji
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

@Composable
fun CartScreen(
    state: CustomerState,
    onChangeQuantity: (listingId: String, delta: Int) -> Unit,
    onOpen: (String) -> Unit,
    onCheckout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    val lines = state.cartLines

    Column(modifier = modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.cart_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(12.dp))

        if (lines.isEmpty()) {
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

        val bySeller = lines.groupBy { it.first.sellers?.name.orEmpty() }
        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            bySeller.forEach { (shopName, shopLines) ->
                item(key = "shop-$shopName") {
                    Text(
                        text = stringResource(R.string.sold_by, shopName),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = TextMuted,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                items(shopLines.size, key = { shopLines[it].first.id }) { index ->
                    val (listing, qty) = shopLines[index]
                    CartLine(listing, qty, lang, onChangeQuantity) { onOpen(listing.id) }
                }
            }
        }

        val total = lines.sumOf { (listing, qty) -> listing.priceIqd * qty }
        Surface(color = Color.White, shadowElevation = 6.dp, shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(stringResource(R.string.cart_total), fontWeight = FontWeight.Bold)
                    Text(priceText(total), fontWeight = FontWeight.Bold)
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
private fun CartLine(
    listing: Listing,
    qty: Int,
    lang: String,
    onChangeQuantity: (String, Int) -> Unit,
    onOpen: () -> Unit,
) {
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
                Text(priceText(listing.priceIqd * qty), style = MaterialTheme.typography.bodyMedium)
            }
            Stepper(qty) { delta -> onChangeQuantity(listing.id, delta) }
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
