package com.plantapp.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource

/** City codes as stored in the database (English names), in display order. */
val CityCodes = listOf(
    "Baghdad", "Erbil", "Basra", "Mosul", "Najaf", "Sulaymaniyah", "Karbala", "Duhok",
    "Kirkuk", "Anbar", "Babil", "Diyala", "Wasit", "Maysan", "DhiQar", "Muthanna", "Qadisiyah", "SalahAlDin", "Halabja",
)

/** Localised display name for a stored city code (string city_<code in lowercase>). Unknown codes are shown as-is. */
@Composable
fun cityLabel(code: String): String {
    val context = LocalContext.current
    val id = remember(code, context) { context.resources.getIdentifier("city_" + code.lowercase(), "string", context.packageName) }
    return if (id != 0) stringResource(id) else code
}

/** The main city of each governorate (latitude, longitude): a starting point for the map and a guess for "use my location". */
val GovernorateCenters: Map<String, Pair<Double, Double>> = mapOf(
    "Baghdad" to (33.3152 to 44.3661), "Erbil" to (36.1911 to 44.0092), "Basra" to (30.5081 to 47.7835),
    "Mosul" to (36.3350 to 43.1189), "Najaf" to (32.0000 to 44.3362), "Sulaymaniyah" to (35.5558 to 45.4351),
    "Karbala" to (32.6160 to 44.0249), "Duhok" to (36.8679 to 42.9884), "Kirkuk" to (35.4681 to 44.3922),
    "Anbar" to (33.4258 to 43.3033), "Babil" to (32.4637 to 44.4196), "Diyala" to (33.7500 to 44.6333),
    "Wasit" to (32.5128 to 45.8182), "Maysan" to (31.8356 to 47.1440), "DhiQar" to (31.0580 to 46.2573),
    "Muthanna" to (31.3098 to 45.2870), "Qadisiyah" to (31.9889 to 44.9264), "SalahAlDin" to (34.5953 to 43.6827),
    "Halabja" to (35.1778 to 45.9862),
)

/** The governorate whose main city is closest to a point; only a suggestion, the person can change it. */
fun nearestGovernorate(lat: Double, lng: Double): String {
    val scale = Math.cos(Math.toRadians(lat))
    return GovernorateCenters.minBy { (_, c) ->
        val dLat = c.first - lat
        val dLng = (c.second - lng) * scale
        dLat * dLat + dLng * dLng
    }.key
}
