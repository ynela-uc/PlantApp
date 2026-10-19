package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Listing
import com.plantapp.data.localized
import com.plantapp.data.plantEmoji
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

@Composable
fun ListingDetailScreen(
    listing: Listing,
    inCart: Int,
    onAdd: () -> Unit,
    onBack: () -> Unit,
) {
    val lang = rememberLang()
    val shop = listing.sellers

    Column(modifier = Modifier.fillMaxSize().systemBarsPadding()) {
        Column(
            modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()),
        ) {
            val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
            TextButton(onClick = onBack, modifier = Modifier.padding(horizontal = 8.dp)) {
                Text("$backArrow  ${stringResource(R.string.back)}", color = PlantGreen)
            }
            PlantPicture(listing, Modifier.fillMaxWidth().height(240.dp), 96.sp)

            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = listing.name.localized(lang),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = PlantGreenDark,
                )
                listing.scientificName?.takeIf { it.isNotBlank() }?.let {
                    Text(text = it, style = MaterialTheme.typography.bodyMedium, fontStyle = FontStyle.Italic, color = TextMuted)
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    text = priceText(listing.priceIqd),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )

                Spacer(Modifier.height(16.dp))
                if (shop != null) {
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, CardBorder),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text(
                                text = stringResource(R.string.sold_by, shop.name),
                                fontWeight = FontWeight.Bold,
                                color = PlantGreenDark,
                            )
                            Text(
                                text = "${cityLabel(shop.city)}  ·  ★ ${"%.1f".format(shop.rating)}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = TextMuted,
                            )
                            Spacer(Modifier.height(8.dp))
                            DeliveryBadge(shop)
                            if (!shop.isNationwide && !shop.deliversTo.isNullOrEmpty()) {
                                Spacer(Modifier.height(6.dp))
                                val cityNames = shop.deliversTo.map { cityLabel(it) }
                                Text(
                                    text = stringResource(R.string.delivers_to, cityNames.joinToString(", ")),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = TextMuted,
                                )
                            }
                        }
                    }
                }

                val description = listing.description.localized(lang)
                if (description.isNotBlank()) {
                    Spacer(Modifier.height(20.dp))
                    Text(text = description, style = MaterialTheme.typography.bodyLarge)
                }

                if (listing.care.isNotEmpty()) {
                    Spacer(Modifier.height(24.dp))
                    Text(
                        text = stringResource(R.string.detail_care),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = PlantGreenDark,
                    )
                    Spacer(Modifier.height(10.dp))
                    CareRow("💧", R.string.care_water, listing.care["water"]?.localized(lang))
                    CareRow("☀️", R.string.care_light, listing.care["light"]?.localized(lang))
                    CareRow("🌱", R.string.care_fertilizer, listing.care["fertilizer"]?.localized(lang))
                }

                listing.heightCm?.let {
                    Spacer(Modifier.height(16.dp))
                    CareRow("📏", R.string.detail_size, stringResource(R.string.size_height, it))
                }
            }
        }

        Surface(shadowElevation = 8.dp, color = Color.White) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (inCart > 0) {
                    Text(
                        text = stringResource(R.string.in_cart, inCart),
                        style = MaterialTheme.typography.labelLarge,
                        color = TextMuted,
                    )
                }
                Button(
                    onClick = onAdd,
                    modifier = Modifier.weight(1f).height(52.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(stringResource(R.string.add_to_cart), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun CareRow(emoji: String, labelRes: Int, text: String?) {
    if (text.isNullOrBlank()) return
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = emoji, fontSize = 22.sp)
        Column {
            Text(
                text = stringResource(labelRes),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Text(text = text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
