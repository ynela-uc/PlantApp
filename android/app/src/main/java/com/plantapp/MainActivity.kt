package com.plantapp

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.plantapp.data.AUTH_HOST
import com.plantapp.data.AUTH_SCHEME
import com.plantapp.ui.AppViewModel
import com.plantapp.ui.PlantAppRoot
import com.plantapp.ui.theme.PlantAppTheme

class MainActivity : ComponentActivity() {
    // Same activity-scoped instance PlantAppRoot() receives.
    private val appViewModel: AppViewModel by viewModels()

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLanguage.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) handleAuthLink(intent)
        setContent {
            PlantAppTheme {
                PlantAppRoot(appViewModel)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthLink(intent)
    }

    /**
     * Handles the link from the password-reset email:
     * plantapp://auth-callback#access_token=...&refresh_token=...&type=recovery
     * or, when it is expired/used, plantapp://auth-callback#error=...&error_code=otp_expired
     */
    private fun handleAuthLink(intent: Intent) {
        val data = intent.data ?: return
        if (data.scheme != AUTH_SCHEME || data.host != AUTH_HOST) return
        val params = authParams(data)
        // Parameter names only; the values are secrets.
        Log.d("PlantAuth", "auth link params: ${params.keys}")
        val access = params["access_token"]
        when {
            params.containsKey("error") || params.containsKey("error_code") -> appViewModel.onAuthLinkFailed()
            access != null -> appViewModel.onRecoveryTokens(access, params["refresh_token"].orEmpty())
            else -> appViewModel.onAuthLinkFailed()
        }
        // Consume the link so a rotation or relaunch does not process it twice.
        this.intent = Intent(this, MainActivity::class.java)
    }

    /** Reads key=value pairs from both the #fragment and the ?query of the link. */
    private fun authParams(data: Uri): Map<String, String> {
        val raw = listOfNotNull(data.encodedFragment, data.encodedQuery).joinToString("&")
        return raw.split("&")
            .filter { it.contains("=") }
            .associate { pair ->
                val (key, value) = pair.split("=", limit = 2)
                Uri.decode(key) to Uri.decode(value)
            }
    }
}
