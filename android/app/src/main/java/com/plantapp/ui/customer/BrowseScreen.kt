package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Listing
import com.plantapp.data.Profile
import com.plantapp.data.localized
import com.plantapp.data.plantEmoji
import com.plantapp.ui.CityCodes
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

@Composable
fun BrowseScreen(
    profile: Profile,
    state: CustomerState,
    onCity: (String) -> Unit,
    onQuery: (String) -> Unit,
    onPlantFilter: (String?) -> Unit,
    onOpen: (String) -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    val visible = state.visible(lang)

    Column(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text(
                text = stringResource(R.string.home_greeting, profile.firstName.ifBlank { profile.phone }),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = state.query,
                onValueChange = onQuery,
                placeholder = { Text(stringResource(R.string.browse_search_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.browse_delivering_to),
                style = MaterialTheme.typography.labelMedium,
                color = TextMuted,
            )
            Spacer(Modifier.height(6.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(CityCodes) { code ->
                    Chip(cityLabel(code), selected = state.city == code) { onCity(code) }
                }
            }
            val types = state.plantTypes()
            if (types.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item { Chip(stringResource(R.string.browse_all), state.plantFilter == null) { onPlantFilter(null) } }
                    items(types) { (key, listing) ->
                        Chip(
                            label = "${plantEmoji(key)} ${listing.name.localized(lang)}",
                            selected = state.plantFilter == key,
                        ) { onPlantFilter(key) }
                    }
                }
            }
        }

        when {
            state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = PlantGreen)
            }
            state.failed -> Column(
                Modifier.fillMaxSize().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(stringResource(R.string.browse_load_failed), color = TextMuted, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                Button(onClick = onRetry) { Text(stringResource(R.string.retry)) }
            }
            visible.isEmpty() -> Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                Text(
                    text = stringResource(R.string.browse_empty, cityLabel(state.city)),
                    color = TextMuted,
                    textAlign = TextAlign.Center,
                )
            }
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(visible, key = { it.id }) { listing ->
                    PlantCard(listing, lang) { onOpen(listing.id) }
                }
                item(span = { GridItemSpan(2) }) { Spacer(Modifier.height(4.dp)) }
            }
        }
    }
}

@Composable
private fun Chip(label: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(999.dp),
        color = if (selected) PlantGreen else Color.White,
        border = BorderStroke(1.dp, if (selected) PlantGreen else CardBorder),
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            color = if (selected) Color.White else TextMuted,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun PlantCard(listing: Listing, lang: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(18.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
    ) {
        Column {
            PlantPicture(listing, Modifier.fillMaxWidth().aspectRatio(1.25f), 52.sp)
            Column(modifier = Modifier.padding(12.dp)) {
                Text(
                    text = listing.name.localized(lang),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = PlantGreenDark,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = listing.sellers?.name.orEmpty(),
                    style = MaterialTheme.typography.bodySmall,
                    color = TextMuted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = priceText(listing.priceIqd),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(8.dp))
                DeliveryBadge(listing.sellers)
            }
        }
    }
}
