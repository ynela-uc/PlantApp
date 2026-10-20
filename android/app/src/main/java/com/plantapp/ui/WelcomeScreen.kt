package com.plantapp.ui

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
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Role
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.SellerAmberSoft
import com.plantapp.ui.theme.TextMuted

@Composable
fun WelcomeScreen(onRoleChosen: (Role) -> Unit) {
    Column(modifier = Modifier.fillMaxSize().systemBarsPadding()) {
    Column(
        modifier = Modifier
            .weight(1f)
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        androidx.compose.foundation.Image(
            painter = androidx.compose.ui.res.painterResource(R.drawable.logo),
            contentDescription = null,
            modifier = Modifier.size(96.dp),
        )

        Spacer(Modifier.height(20.dp))

        Text(
            text = stringResource(R.string.welcome_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.welcome_tagline),
            style = MaterialTheme.typography.bodyLarge,
            color = TextMuted,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(40.dp))

        Text(
            text = stringResource(R.string.role_prompt),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF333333),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))

        RoleCard(
            emoji = "🛒",
            iconBackground = PlantGreenSoft,
            title = stringResource(R.string.role_customer_title),
            description = stringResource(R.string.role_customer_desc),
            onClick = { onRoleChosen(Role.Customer) },
        )
        Spacer(Modifier.height(14.dp))
        RoleCard(
            emoji = "🏪",
            iconBackground = SellerAmberSoft,
            accent = SellerAmber,
            title = stringResource(R.string.role_seller_title),
            description = stringResource(R.string.role_seller_desc),
            onClick = { onRoleChosen(Role.Seller) },
        )
    }
    LanguageSelector(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp))
    }
}

@Composable
private fun RoleCard(
    emoji: String,
    iconBackground: Color,
    title: String,
    description: String,
    onClick: () -> Unit,
    accent: Color = PlantGreen,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
        shadowElevation = 1.dp,
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(CircleShape)
                    .background(iconBackground),
                contentAlignment = Alignment.Center,
            ) {
                Text(text = emoji, fontSize = 26.sp)
            }
            Spacer(Modifier.size(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = PlantGreenDark,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted,
                )
            }
            Spacer(Modifier.size(8.dp))
            // Chevron points toward the reading direction's end.
            val chevron = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "‹" else "›"
            Text(text = chevron, fontSize = 28.sp, color = accent)
        }
    }
}
