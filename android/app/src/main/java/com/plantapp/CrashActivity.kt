package com.plantapp

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

/** Plain-view screen (no Compose, runs in its own process) that shows the stack trace of the last crash. */
class CrashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val trace = intent.getStringExtra(EXTRA_TRACE).orEmpty()
        val pad = (16 * resources.displayMetrics.density).toInt()
        val text = TextView(this).apply {
            this.text = "PlantApp crashed.\nPlease take a screenshot of this screen and send it.\n\n$trace"
            textSize = 11f
            setTextIsSelectable(true)
            setPadding(pad, pad * 2, pad, pad)
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }

    companion object {
        const val EXTRA_TRACE = "trace"
    }
}
