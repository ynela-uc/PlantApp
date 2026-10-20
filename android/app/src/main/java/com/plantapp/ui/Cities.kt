package com.plantapp.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource

/** City codes as stored in the database (English names), in display order. */
val CityCodes = listOf(
    "Baghdad", "Erbil", "Basra", "Mosul", "Najaf", "Sulaymaniyah", "Karbala", "Duhok",
    "Kirkuk", "Anbar", "Babil", "Diyala", "Wasit", "Maysan", "DhiQar", "Muthanna", "Qadisiyah", "SalahAlDin",
)

/** Localised display name for a stored city code (string city_<code in lowercase>). Unknown codes are shown as-is. */
@Composable
fun cityLabel(code: String): String {
    val context = LocalContext.current
    val id = remember(code, context) { context.resources.getIdentifier("city_" + code.lowercase(), "string", context.packageName) }
    return if (id != 0) stringResource(id) else code
}
