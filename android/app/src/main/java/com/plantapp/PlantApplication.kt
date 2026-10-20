package com.plantapp

import android.app.Application
import android.content.Intent
import android.util.Log
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.request.allowHardware

/**
 * Shows the error on screen when the app crashes (in a separate process, with plain views), so a crash on a
 * device we cannot attach a debugger to can be reported with a screenshot instead of "it keeps crashing".
 *
 * Photos are decoded as ordinary bitmaps, not GPU-only ones: emulators (BlueStacks) show garbage from other
 * apps' textures for hardware bitmaps, and some devices run out of graphics memory with many of them.
 */
class PlantApplication : Application(), SingletonImageLoader.Factory {
    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context).allowHardware(false).build()

    override fun onCreate() {
        super.onCreate()
        Push.init(this)
        Push.createChannels(this)
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
