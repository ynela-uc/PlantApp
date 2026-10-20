package com.plantapp.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Brand colours: teal and sand, with one accent per service (flowers coral, plants green, gifts gold).
// The names keep "PlantGreen" for the main brand colour so existing screens pick up the new look unchanged.
val PlantGreen = Color(0xFF0E6F73)
val PlantGreenDark = Color(0xFF0B4F52)
val PlantGreenSoft = Color(0xFFDCEEEE)
val SellerAmber = Color(0xFFB7791F)
val SellerAmberSoft = Color(0xFFFFF2DA)
val ScreenBackground = Color(0xFFF7F5EF)
val TextMuted = Color(0xFF55706F)
val CardBorder = Color(0xFFE7E1D3)

val FlowerCoral = Color(0xFFF26B5B)
val FlowerCoralSoft = Color(0xFFFEE9E5)
val LeafGreen = Color(0xFF3FA56B)
val LeafGreenSoft = Color(0xFFE1F3E8)
val GiftGold = Color(0xFFF2B544)
val GiftGoldSoft = Color(0xFFFFF1D3)

/** The accent colour of a section (flowers / plants / gifts); the brand teal for anything else. */
fun sectionAccent(key: String?): Color = when (key) {
    "flowers" -> FlowerCoral
    "plants" -> LeafGreen
    "gifts" -> GiftGold
    else -> PlantGreen
}

fun sectionAccentSoft(key: String?): Color = when (key) {
    "flowers" -> FlowerCoralSoft
    "plants" -> LeafGreenSoft
    "gifts" -> GiftGoldSoft
    else -> PlantGreenSoft
}

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
