package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Catalog
import com.plantapp.data.Listing
import com.plantapp.data.Profile
import com.plantapp.data.localized
import com.plantapp.ui.CityCodes
import com.plantapp.ui.categoryName
import com.plantapp.ui.cityLabel
import com.plantapp.ui.occasionName
import com.plantapp.ui.sectionDescription
import com.plantapp.ui.sectionName
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.SellerAmberSoft
import com.plantapp.ui.theme.TextMuted

/**
 * The shopper's front door. With nothing chosen it shows the three sections (flowers, plants, gifts)
 * and the occasions; picking one shows its categories and products. Search works from anywhere.
 */
@Composable
fun BrowseScreen(
    profile: Profile,
    state: CustomerState,
    onCity: (String) -> Unit,
    onQuery: (String) -> Unit,
    onSection: (String?) -> Unit,
    onCategory: (String?) -> Unit,
    onOccasion: (String?) -> Unit,
    onOpen: (String) -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    val visible = state.visible(lang)
    val section = Catalog.section(state.section)

    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = modifier.fillMaxSize(),
    ) {
        // Greeting, search and the delivery city
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(modifier = Modifier.padding(top = 12.dp)) {
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
            }
        }

        if (state.loading) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Box(Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = PlantGreen)
                }
            }
            return@LazyVerticalGrid
        }
        if (state.failed) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(
                    Modifier.fillMaxWidth().padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(stringResource(R.string.browse_load_failed), color = TextMuted, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(12.dp))
                    Button(onClick = onRetry) { Text(stringResource(R.string.retry)) }
                }
            }
            return@LazyVerticalGrid
        }

        if (state.isHome) {
            // The three sections
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionTitle(stringResource(R.string.home_prompt))
                    Catalog.sections.forEach { entry ->
                        SectionTile(
                            emoji = entry.emoji,
                            title = sectionName(entry.key),
                            description = sectionDescription(entry.key),
                        ) { onSection(entry.key) }
                    }
                }
            }
            // Occasions
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column {
                    SectionTitle(stringResource(R.string.home_occasions))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(Catalog.occasions) { occasion ->
                            Chip("${occasion.emoji} ${occasionName(occasion.key)}", selected = false) { onOccasion(occasion.key) }
                        }
                    }
                }
            }
            item(span = { GridItemSpan(maxLineSpan) }) { SectionTitle(stringResource(R.string.home_all_products)) }
        } else {
            // A section or an occasion is open: breadcrumb and filters
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column {
                    val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = {
                            onSection(null)
                            onQuery("")
                        }) {
                            Text("$backArrow  ${stringResource(R.string.home_back)}", color = PlantGreen)
                        }
                        val title = when {
                            section != null -> "${section.emoji} ${sectionName(section.key)}"
                            state.occasion != null -> "${Catalog.occasionEmoji(state.occasion)} ${occasionName(state.occasion)}"
                            else -> stringResource(R.string.home_all_products)
                        }
                        Text(
                            text = title,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = PlantGreenDark,
                        )
                    }
                    if (section != null) {
                        Spacer(Modifier.height(4.dp))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            item { Chip(stringResource(R.string.browse_all), state.category == null) { onCategory(null) } }
                            items(section.categories) { category ->
                                Chip(
                                    label = "${category.emoji} ${categoryName(category.key)}",
                                    selected = state.category == category.key,
                                ) { onCategory(category.key) }
                            }
                        }
                    }
                }
            }
        }

        if (!state.isHome && visible.isEmpty()) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                    Text(
                        text = stringResource(R.string.browse_empty, cityLabel(state.city)),
                        color = TextMuted,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
        items(visible, key = { it.id }) { listing ->
            PlantCard(listing, lang) { onOpen(listing.id) }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        color = PlantGreenDark,
        modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
    )
}

@Composable
private fun SectionTile(emoji: String, title: String, description: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
        shadowElevation = 1.dp,
    ) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(56.dp).clip(CircleShape).background(PlantGreenSoft),
                contentAlignment = Alignment.Center,
            ) { Text(emoji, fontSize = 28.sp) }
            Spacer(Modifier.size(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.Bold, color = PlantGreenDark, style = MaterialTheme.typography.titleMedium)
                Text(description, color = TextMuted, style = MaterialTheme.typography.bodySmall)
            }
            val chevron = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "‹" else "›"
            Text(chevron, fontSize = 26.sp, color = PlantGreen)
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
