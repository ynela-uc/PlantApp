package com.plantapp.ui

import android.app.Activity
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.AppLanguage
import com.plantapp.R
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.TextMuted

/** Three-way language picker. Picking a language saves it and recreates the activity. */
@Composable
fun LanguageSelector(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val current = AppLanguage.current(context)

    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = "🌐  " + stringResource(R.string.language_label),
            style = MaterialTheme.typography.labelMedium,
            color = TextMuted,
        )
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            AppLanguage.entries.forEach { language ->
                val selected = language == current
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clickable(enabled = !selected) {
                            AppLanguage.save(context, language)
                            (context as? Activity)?.recreate()
                        },
                    shape = RoundedCornerShape(14.dp),
                    color = if (selected) PlantGreen else Color.White,
                    border = BorderStroke(1.dp, if (selected) PlantGreen else CardBorder),
                ) {
                    Text(
                        text = language.nativeName,
                        modifier = Modifier.padding(vertical = 12.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        fontWeight = FontWeight.SemiBold,
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (selected) Color.White else Color(0xFF333333),
                    )
                }
            }
        }
    }
}
