package com.plantapp.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource

/**
 * Localised names for the catalog keys (see data/Catalog.kt). The names live in the string files as
 * sec_<key>, cat_<key> and occ_<key>; an unknown key is shown as it is.
 */
@Composable
private fun catalogName(prefix: String, key: String): String {
    val context = LocalContext.current
    val id = remember(prefix, key, context) {
        context.resources.getIdentifier("${prefix}_$key", "string", context.packageName)
    }
    return if (id != 0) stringResource(id) else key
}

@Composable
fun sectionName(key: String): String = catalogName("sec", key)

/** The short line under a section name on the home screen. */
@Composable
fun sectionDescription(key: String): String = catalogName("sec", "${key}_desc")

@Composable
fun categoryName(key: String): String = catalogName("cat", key)

@Composable
fun occasionName(key: String): String = catalogName("occ", key)
