package com.plantapp.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Role
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted

/** Asks for the account email and sends the reset link. */
@Composable
fun ResetPasswordScreen(
    role: Role,
    busy: Boolean,
    error: AuthError?,
    linkSent: Boolean,
    sentTo: String,
    onBack: () -> Unit,
    onSendLink: (email: String) -> Unit,
    onEdit: () -> Unit,
) {
    val accent = if (role == Role.Seller) SellerAmber else PlantGreen
    var email by rememberSaveable { mutableStateOf("") }
    var localError by rememberSaveable { mutableStateOf<String?>(null) }
    val requiredMsg = stringResource(R.string.err_required)

    FormPage(onBack = onBack, accent = accent, titleRes = R.string.reset_title) {
        Text(
            text = if (linkSent) stringResource(R.string.reset_link_sent, sentTo) else stringResource(R.string.reset_intro),
            style = MaterialTheme.typography.bodyLarge,
            color = TextMuted,
        )
        Spacer(Modifier.height(20.dp))

        if (!linkSent) {
            PasswordField(email, { email = it; localError = null; onEdit() }, R.string.field_email, KeyboardType.Email, secret = false)
        }
        ErrorLine(localError ?: error?.let { stringResource(it.resetMessageRes()) })

        Spacer(Modifier.height(8.dp))
        Button(
            onClick = {
                val target = if (linkSent) sentTo else email.trim()
                if (target.isBlank()) localError = requiredMsg else onSendLink(target)
            },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = accent),
        ) {
            if (busy) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
            } else {
                Text(
                    text = stringResource(if (linkSent) R.string.reset_resend else R.string.reset_send_link),
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

/** Shown after the reset link opened the app: choose and save a new password. */
@Composable
fun SetNewPasswordScreen(
    busy: Boolean,
    error: AuthError?,
    onSubmit: (newPassword: String) -> Unit,
    onEdit: () -> Unit,
) {
    var password by rememberSaveable { mutableStateOf("") }
    var localError by rememberSaveable { mutableStateOf<String?>(null) }
    val requiredMsg = stringResource(R.string.err_required)
    val shortMsg = stringResource(R.string.err_password_short)

    FormPage(onBack = null, accent = PlantGreen, titleRes = R.string.set_password_title) {
        Text(
            text = stringResource(R.string.set_password_intro),
            style = MaterialTheme.typography.bodyLarge,
            color = TextMuted,
        )
        Spacer(Modifier.height(20.dp))
        PasswordField(password, { password = it; localError = null; onEdit() }, R.string.field_new_password, KeyboardType.Password, secret = true)
        ErrorLine(localError ?: error?.let { stringResource(it.resetMessageRes()) })
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = {
                when {
                    password.isBlank() -> localError = requiredMsg
                    password.length < 6 -> localError = shortMsg
                    else -> onSubmit(password)
                }
            },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
        ) {
            if (busy) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
            } else {
                Text(stringResource(R.string.set_password_action), fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun FormPage(
    onBack: (() -> Unit)?,
    accent: Color,
    titleRes: Int,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 12.dp),
    ) {
        if (onBack != null) {
            val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
            TextButton(onClick = onBack) { Text("$backArrow  ${stringResource(R.string.back)}", color = accent) }
        } else {
            Spacer(Modifier.height(48.dp))
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(titleRes),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(8.dp))
        content()
    }
}

@Composable
private fun ErrorLine(message: String?) {
    if (message == null) return
    Text(text = message, color = Color(0xFFC62828), style = MaterialTheme.typography.bodyMedium)
}

@Composable
private fun PasswordField(
    value: String,
    onChange: (String) -> Unit,
    labelRes: Int,
    keyboardType: KeyboardType,
    secret: Boolean,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(stringResource(labelRes)) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        visualTransformation = if (secret) PasswordVisualTransformation() else VisualTransformation.None,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
    )
}

private fun AuthError.resetMessageRes(): Int = when (this) {
    AuthError.Network -> R.string.err_network
    AuthError.LinkExpired -> R.string.err_link_expired
    else -> R.string.err_generic
}
