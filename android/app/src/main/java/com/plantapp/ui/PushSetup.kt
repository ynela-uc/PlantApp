package com.plantapp.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.plantapp.Push
import com.plantapp.ui.customer.rememberLang

/** Once someone is signed in: ask for permission to show notifications (Android 13+) and store this phone's push address. */
@Composable
fun PushSetup(userId: String) {
    val context = LocalContext.current
    val lang = rememberLang()
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        // The address is stored either way; without permission nothing is shown.
    }
    LaunchedEffect(userId) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
        Push.register(context, lang)
    }
}
