package com.plantapp.ui.customer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Profile
import com.plantapp.ui.LanguageSelector
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

@Composable
fun ProfileTab(profile: Profile, onSignOut: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
    ) {
        Text(
            text = "${profile.firstName} ${profile.lastName}".trim(),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(16.dp))
        InfoRow(R.string.field_phone, profile.phone)
        InfoRow(R.string.field_city, if (profile.city.isBlank()) "" else cityLabel(profile.city))
        InfoRow(R.string.field_address, profile.address)

        Spacer(Modifier.height(28.dp))
        LanguageSelector()

        Spacer(Modifier.height(28.dp))
        OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.action_signout), color = PlantGreen, fontWeight = FontWeight.SemiBold)
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
        Text(value, fontWeight = FontWeight.SemiBold)
    }
}
