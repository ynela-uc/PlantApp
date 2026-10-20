package com.plantapp.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Profile
import com.plantapp.data.Role
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted

/** Placeholder home for a signed-in account; the real Customer and Seller apps replace this next. */
@Composable
fun HomeShell(profile: Profile, onSignOut: () -> Unit) {
    val isSeller = profile.roleEnum == Role.Seller
    val name = profile.firstName.ifBlank { profile.phone }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = if (isSeller) "🏪" else "🛒", style = MaterialTheme.typography.displayMedium)
        Spacer(Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.home_greeting, name),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(if (isSeller) R.string.home_seller_body else R.string.home_customer_body),
            style = MaterialTheme.typography.bodyLarge,
            color = TextMuted,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(32.dp))
        OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
            Text(
                text = stringResource(R.string.action_signout),
                color = if (isSeller) SellerAmber else Color(0xFF0E6F73),
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}
