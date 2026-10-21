package com.plantapp.ui.seller

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Order
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.SellerAmberSoft
import kotlinx.coroutines.delay

/** A banner on top of every seller screen when a new order arrives while the app is open. Tap to open, or it fades after 12 seconds. */
@Composable
fun NewOrderBanner(orders: List<Order>, onOpen: () -> Unit, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    if (orders.isEmpty()) return
    LaunchedEffect(orders.joinToString { it.id }) {
        delay(12_000)
        onDismiss()
    }
    val first = orders.first()
    Surface(
        modifier = modifier.systemBarsPadding().padding(12.dp).fillMaxWidth().clickable(onClick = onOpen),
        shape = RoundedCornerShape(16.dp),
        color = SellerAmberSoft,
        shadowElevation = 8.dp,
        border = BorderStroke(2.dp, SellerAmber),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = "🛍  " + if (orders.size > 1) stringResource(R.string.banner_new_orders, orders.size)
                else stringResource(R.string.banner_new_order, first.buyerName.ifBlank { "#" + first.id.take(6).uppercase() }),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Text(stringResource(R.string.banner_tap_to_open), style = MaterialTheme.typography.bodySmall, color = SellerAmber)
        }
    }
}

/**
 * The shop's phone makes a sound and vibrates when a new order arrives while the app is open. The chime is our own file played at
 * the media volume: the phone's "default notification sound" is missing or silent on some devices and emulators.
 */
fun playNewOrderAlert(context: Context) {
    try {
        val player = MediaPlayer()
        player.setAudioAttributes(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
        )
        context.resources.openRawResourceFd(R.raw.new_order).use { player.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
        player.setOnCompletionListener { it.release() }
        player.prepare()
        player.start()
    } catch (_: Exception) { }
    try {
        context.getSystemService(Vibrator::class.java)?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 400, 200, 400), -1))
    } catch (_: Exception) { }
}
