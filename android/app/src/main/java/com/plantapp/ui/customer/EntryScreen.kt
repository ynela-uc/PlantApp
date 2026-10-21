package com.plantapp.ui.customer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Catalog
import com.plantapp.data.Profile
import com.plantapp.ui.PickChip
import com.plantapp.ui.occasionName
import com.plantapp.ui.sectionDescription
import com.plantapp.ui.sectionName
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.ScreenBackground
import com.plantapp.ui.theme.sectionAccent
import com.plantapp.ui.theme.sectionAccentSoft
import com.plantapp.ui.theme.TextMuted

/**
 * Shown every time the shopper opens the app: what are you looking for? Flowers, plants or gifts,
 * or one of the occasions. The answer opens the app already filtered to it.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EntryScreen(profile: Profile, onChoose: (section: String?, occasion: String?) -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ScreenBackground)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 24.dp),
    ) {
        Text(
            text = stringResource(R.string.home_greeting, profile.firstName.ifBlank { profile.phone }),
            style = MaterialTheme.typography.titleMedium,
            color = TextMuted,
        )
        Text(
            text = stringResource(R.string.home_prompt),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(20.dp))

        Catalog.sections.forEach { entry ->
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .clickable { onChoose(entry.key, null) },
                shape = RoundedCornerShape(22.dp),
                color = Color.White,
                border = BorderStroke(1.dp, CardBorder),
                shadowElevation = 1.dp,
            ) {
                Row(modifier = Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier.size(64.dp).clip(CircleShape).background(sectionAccentSoft(entry.key)),
                        contentAlignment = Alignment.Center,
                    ) { Text(entry.emoji, fontSize = 32.sp) }
                    Spacer(Modifier.size(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = sectionName(entry.key),
                            fontWeight = FontWeight.Bold,
                            color = PlantGreenDark,
                            style = MaterialTheme.typography.titleLarge,
                        )
                        Text(sectionDescription(entry.key), color = TextMuted, style = MaterialTheme.typography.bodyMedium)
                    }
                    val chevron = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "‹" else "›"
                    Text(chevron, fontSize = 30.sp, color = sectionAccent(entry.key))
                }
            }
        }

        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.home_occasions),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(8.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Catalog.occasions.forEach { occasion ->
                PickChip("${occasion.emoji} ${occasionName(occasion.key)}", selected = false, accent = PlantGreen) {
                    onChoose(null, occasion.key)
                }
            }
        }

        Spacer(Modifier.height(24.dp))
        OutlinedButton(
            onClick = { onChoose(null, null) },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(14.dp),
        ) { Text(stringResource(R.string.home_all_products), color = PlantGreen, fontWeight = FontWeight.SemiBold) }
    }
}
