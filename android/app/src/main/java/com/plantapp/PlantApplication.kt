package com.plantapp

import android.app.Application
import android.content.Intent
import android.util.Log

/**
 * Shows the error on screen when the app crashes (in a separate process, with plain views), so a crash on a
 * device we cannot attach a debugger to can be reported with a screenshot instead of "it keeps crashing".
 */
class PlantApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val intent = Intent(this, CrashActivity::class.java)
                    .putExtra(CrashActivity.EXTRA_TRACE, Log.getStackTraceString(error).take(9000))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                startActivity(intent)
                Thread.sleep(400)
            } catch (_: Throwable) {
                // Never let the reporter hide the original crash.
            }
            previous?.uncaughtException(thread, error)
        }
    }
}
