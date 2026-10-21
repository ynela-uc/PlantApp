package com.plantapp

import android.app.Activity
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Bundle
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.plantapp.data.Backend
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Push notifications through Firebase Cloud Messaging. The phone's address ("token") is stored in the database
 * (device_tokens) for the signed-in user; the server sends a push when an order changes (see supabase notify function).
 * Everything here quietly does nothing until google-services.json is added to the app (docs/push-setup.md).
 */
object Push {
    /** New orders and reminders for shops: loud, with vibration. */
    const val CHANNEL_NEW_ORDERS = "new_orders"

    /** Everything else (photo ready, on its way, ...). */
    const val CHANNEL_UPDATES = "order_updates"

    private const val PREFS = "push"
    private const val KEY_TOKEN = "token"
    private const val KEY_LANGUAGE = "language"

    private lateinit var app: Context

    /** True while one of our screens is visible: the seller's in-app banner covers new orders then. */
    @Volatile
    var inForeground = false
        private set

    fun init(context: Context) {
        app = context.applicationContext
        (app as Application).registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            private var started = 0
            override fun onActivityStarted(activity: Activity) { started++; inForeground = true }
            override fun onActivityStopped(activity: Activity) { started--; inForeground = started > 0 }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }

    fun createChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_NEW_ORDERS, context.getString(R.string.channel_new_orders), NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 500)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_UPDATES, context.getString(R.string.channel_order_updates), NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    private fun firebaseReady(context: Context): Boolean = FirebaseApp.getApps(context).isNotEmpty()

    /** Stores this phone's push address for the signed-in user. Safe to call often. */
    suspend fun register(context: Context, language: String) {
        if (!firebaseReady(context)) return
        try {
            val token = fetchToken()
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_TOKEN, token).putString(KEY_LANGUAGE, language).apply()
            send(token, language)
        } catch (_: Exception) {
            // No network or not signed in yet: tried again at the next start.
        }
    }

    /** Firebase gave this phone a new address: store it (when someone is signed in). */
    suspend fun onNewToken(context: Context, token: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val language = prefs.getString(KEY_LANGUAGE, null) ?: AppLanguage.current(context).tag
        prefs.edit().putString(KEY_TOKEN, token).apply()
        try { send(token, language) } catch (_: Exception) { }
    }

    /** On sign-out: this phone must stop getting the previous user's notifications. */
    suspend fun unregister() {
        if (!::app.isInitialized) return
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null) ?: return
        Backend.client.postgrest.rpc("unregister_device_token", buildJsonObject { put("p_token", token) })
        prefs.edit().remove(KEY_TOKEN).apply()
    }

    private suspend fun send(token: String, language: String) {
        Backend.client.postgrest.rpc(
            "register_device_token",
            buildJsonObject {
                put("p_token", token)
                put("p_platform", "android")
                put("p_language", language)
            },
        )
    }

    private suspend fun fetchToken(): String = suspendCancellableCoroutine { continuation ->
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) continuation.resume(task.result)
            else continuation.resumeWithException(task.exception ?: IllegalStateException("no push token"))
        }
    }
}
