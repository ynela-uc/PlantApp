package com.plantapp.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.plantapp.R

/** City codes as stored in the database (English names), in display order. */
val CityCodes = listOf(
    "Baghdad", "Erbil", "Basra", "Mosul", "Najaf", "Sulaymaniyah", "Karbala", "Duhok",
)

/** Localised display name for a stored city code. Unknown codes are shown as-is. */
@Composable
fun cityLabel(code: String): String {
    val id = when (code) {
        "Baghdad" -> R.string.city_baghdad
        "Erbil" -> R.string.city_erbil
        "Basra" -> R.string.city_basra
        "Mosul" -> R.string.city_mosul
        "Najaf" -> R.string.city_najaf
        "Sulaymaniyah" -> R.string.city_sulaymaniyah
        "Karbala" -> R.string.city_karbala
        "Duhok" -> R.string.city_duhok
        else -> null
    }
    return if (id != null) stringResource(id) else code
}
