package com.plantapp.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.produceState
import com.plantapp.data.OrdersRepository

/** Loads a short-lived signed link for a private order photo; null while loading or on failure. */
@Composable
fun rememberSignedPhotoUrl(path: String?): State<String?> =
    produceState<String?>(initialValue = null, path) {
        value = if (path.isNullOrBlank()) null else try {
            OrdersRepository().signedPhotoUrl(path)
        } catch (_: Exception) {
            null
        }
    }
