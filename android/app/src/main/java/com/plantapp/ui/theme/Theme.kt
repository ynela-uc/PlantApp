package com.plantapp.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val PlantGreen = Color(0xFF2E7D32)
val PlantGreenDark = Color(0xFF1B5E20)
val PlantGreenSoft = Color(0xFFE3F2E3)
val SellerAmber = Color(0xFFB8860B)
val SellerAmberSoft = Color(0xFFFFF3E0)
val ScreenBackground = Color(0xFFF4FBF4)
val TextMuted = Color(0xFF4E6E4F)
val CardBorder = Color(0xFFE0ECE0)

private val LightColors = lightColorScheme(
    primary = PlantGreen,
    onPrimary = Color.White,
    primaryContainer = PlantGreenSoft,
    onPrimaryContainer = PlantGreenDark,
    background = ScreenBackground,
    onBackground = Color(0xFF1B1B1B),
    surface = Color.White,
    onSurface = Color(0xFF1B1B1B),
    outline = CardBorder,
)

@Composable
fun PlantAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightColors, content = content)
}
