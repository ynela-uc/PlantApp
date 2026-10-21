package com.plantapp.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.ui.theme.PlantGreen

/** A phone number in international digits for WhatsApp: 0770... and 770... become 964770... (Iraq). */
fun internationalDigits(phone: String): String? {
    val digits = phone.filter { it.isDigit() }
    return when {
        digits.isEmpty() -> null
        digits.startsWith("00") -> digits.drop(2)
        digits.startsWith("964") -> digits
        digits.startsWith("0") -> "964" + digits.drop(1)
        digits.length == 10 && digits.startsWith("7") -> "964$digits"
        else -> digits
    }
}

fun whatsappUrl(phone: String, message: String?): String? {
    val number = internationalDigits(phone) ?: return null
    val text = message?.let { "?text=" + Uri.encode(it) }.orEmpty()
    return "https://wa.me/$number$text"
}

fun openCall(context: Context, phone: String) {
    val number = phone.filter { it.isDigit() || it == '+' }
    if (number.isEmpty()) return
    try { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number"))) } catch (_: ActivityNotFoundException) { }
}

fun openWhatsApp(context: Context, phone: String, message: String?) {
    val url = whatsappUrl(phone, message) ?: return
    try { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } catch (_: ActivityNotFoundException) { }
}

/** Two buttons: call the number, or write on WhatsApp (with a ready message). */
@Composable
fun ContactButtons(phone: String, whatsappMessage: String?, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    Row(modifier = modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedButton(
            onClick = { openCall(context, phone) },
            modifier = Modifier.weight(1f).height(48.dp),
            shape = RoundedCornerShape(12.dp),
        ) { Text("📞  " + stringResource(R.string.contact_call), color = PlantGreen, fontWeight = FontWeight.SemiBold) }
        OutlinedButton(
            onClick = { openWhatsApp(context, phone, whatsappMessage) },
            modifier = Modifier.weight(1f).height(48.dp),
            shape = RoundedCornerShape(12.dp),
        ) { Text("💬  " + stringResource(R.string.contact_whatsapp), color = PlantGreen, fontWeight = FontWeight.SemiBold) }
    }
}
