package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Catalog
import com.plantapp.data.Listing
import com.plantapp.data.SellerInfo
import com.plantapp.ui.PickChip
import com.plantapp.ui.cityLabel
import com.plantapp.ui.sectionName
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

/** One shop's page: who they are, what they deliver and charge, and their products grouped by collection. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ShopPageScreen(
    shop: SellerInfo,
    listings: List<Listing>,
    city: String,
    onOpen: (String) -> Unit,
    onBack: () -> Unit,
) {
    val lang = rememberLang()
    var collection by rememberSaveable { mutableStateOf<String?>(null) }
    val collections = listings.mapNotNull { it.collection?.takeIf { name -> name.isNotBlank() } }.distinct()
    val visible = listings.filter { collection == null || it.collection == collection }
    val fee = shop.feeFor(city)
    val feeText = if (fee == 0) stringResource(R.string.delivery_free) else priceText(fee)

    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxSize().systemBarsPadding(),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column {
                val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
                TextButton(onClick = onBack) { Text("$backArrow  ${stringResource(R.string.back)}", color = PlantGreen) }
                Text(
                    text = shop.name,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = PlantGreenDark,
                )
                Text(
                    text = "${cityLabel(shop.city)}  ·  ${ratingLabel(shop.rating, shop.ratingCount)}",
                    color = TextMuted,
                )
                if (shop.shopTypes.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        shop.shopTypes.forEach { type ->
                            val emoji = Catalog.section(type)?.emoji.orEmpty()
                            Surface(shape = RoundedCornerShape(999.dp), color = Color.White, border = BorderStroke(1.dp, CardBorder)) {
                                Text(
                                    text = "$emoji ${sectionName(type)}",
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = TextMuted,
                                )
                            }
                        }
                    }
                }
                if (shop.bio.isNotBlank()) {
                    Spacer(Modifier.height(10.dp))
                    Text(shop.bio, style = MaterialTheme.typography.bodyMedium)
                }
                if (shop.phone.isNotBlank()) {
                    Spacer(Modifier.height(10.dp))
                    com.plantapp.ui.ContactButtons(shop.phone, stringResource(R.string.contact_shop_message))
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    DeliveryBadge(shop)
                    Text(
                        text = stringResource(R.string.delivery_to_city, cityLabel(city)) + ": " + feeText,
                        style = MaterialTheme.typography.bodySmall,
                        color = TextMuted,
                    )
                }
                if (collections.isNotEmpty()) {
                    Spacer(Modifier.height(16.dp))
                    Text(
                        text = stringResource(R.string.shop_collections),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = PlantGreenDark,
                    )
                    Spacer(Modifier.height(8.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        PickChip(stringResource(R.string.browse_all), collection == null, accent = PlantGreen) { collection = null }
                        collections.forEach { name ->
                            PickChip(name, collection == name, accent = PlantGreen) { collection = name }
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }
        items(visible, key = { it.id }) { listing ->
            PlantCard(listing, lang) { onOpen(listing.id) }
        }
        item(span = { GridItemSpan(maxLineSpan) }) {
            ShopReviews(shop.id)
        }
    }
}
