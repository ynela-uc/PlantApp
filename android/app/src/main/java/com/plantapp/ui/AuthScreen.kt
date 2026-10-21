package com.plantapp.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Catalog
import com.plantapp.data.Role
import com.plantapp.data.SignUpForm
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted

private val ErrorRed = Color(0xFFC62828)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AuthScreen(
    role: Role,
    busy: Boolean,
    error: AuthError?,
    onBack: () -> Unit,
    onSignIn: (email: String, password: String) -> Unit,
    onSignUp: (SignUpForm) -> Unit,
    onEdit: () -> Unit,
    onForgotPassword: () -> Unit,
) {
    val accent = if (role == Role.Seller) SellerAmber else PlantGreen
    var creating by rememberSaveable { mutableStateOf(false) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var firstName by rememberSaveable { mutableStateOf("") }
    var lastName by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var city by rememberSaveable { mutableStateOf("") }
    var address by rememberSaveable { mutableStateOf("") }
    var shopName by rememberSaveable { mutableStateOf("") }
    // Seller sign-up: the kinds of shop, as comma-separated Catalog section keys (survives rotation).
    var shopTypesCsv by rememberSaveable { mutableStateOf("") }
    val shopTypes = shopTypesCsv.split(',').filter { it.isNotBlank() }
    var localError by rememberSaveable { mutableStateOf<String?>(null) }

    val requiredMsg = stringResource(R.string.err_required)
    val shortPasswordMsg = stringResource(R.string.err_password_short)
    val shopTypesMsg = stringResource(R.string.err_shop_types)

    fun submit() {
        localError = null
        if (!creating) {
            if (email.isBlank() || password.isBlank()) { localError = requiredMsg; return }
            onSignIn(email.trim(), password)
            return
        }
        val missing = email.isBlank() || password.isBlank() || firstName.isBlank() ||
            lastName.isBlank() || phone.isBlank() || city.isBlank() ||
            (role == Role.Customer && address.isBlank()) ||
            (role == Role.Seller && shopName.isBlank())
        if (missing) { localError = requiredMsg; return }
        if (password.length < 6) { localError = shortPasswordMsg; return }
        if (role == Role.Seller && shopTypes.isEmpty()) { localError = shopTypesMsg; return }
        onSignUp(
            SignUpForm(
                email = email.trim(),
                password = password,
                firstName = firstName.trim(),
                lastName = lastName.trim(),
                phone = phone.trim(),
                city = city,
                address = address.trim(),
                shopName = shopName.trim(),
                shopTypes = shopTypes,
            )
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .systemBarsPadding()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 12.dp),
    ) {
        val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
        TextButton(onClick = onBack) {
            Text("$backArrow  ${stringResource(R.string.back)}", color = accent)
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(
                if (role == Role.Seller) R.string.auth_title_seller else R.string.auth_title_customer
            ),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(16.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            ModeTab(stringResource(R.string.auth_tab_signin), !creating, accent, Modifier.weight(1f)) {
                creating = false; localError = null; onEdit()
            }
            ModeTab(stringResource(R.string.auth_tab_signup), creating, accent, Modifier.weight(1f)) {
                creating = true; localError = null; onEdit()
            }
        }
        Spacer(Modifier.height(20.dp))

        if (creating) {
            Field(firstName, { firstName = it; onEdit() }, R.string.field_first_name)
            Field(lastName, { lastName = it; onEdit() }, R.string.field_last_name)
            Field(phone, { phone = it; onEdit() }, R.string.field_phone, KeyboardType.Phone)
        }
        Field(email, { email = it; onEdit() }, R.string.field_email, KeyboardType.Email)
        Field(password, { password = it; onEdit() }, R.string.field_password, KeyboardType.Password, secret = true)
        if (!creating) {
            TextButton(onClick = onForgotPassword) {
                Text(stringResource(R.string.forgot_password), color = accent, fontWeight = FontWeight.SemiBold)
            }
        }

        if (creating) {
            if (role == Role.Seller) {
                Field(shopName, { shopName = it; onEdit() }, R.string.field_shop_name)
                Text(
                    text = stringResource(R.string.shop_types_title),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(bottom = 12.dp),
                ) {
                    Catalog.sections.forEach { entry ->
                        val selected = entry.key in shopTypes
                        PickChip("${entry.emoji} ${sectionName(entry.key)}", selected, accent = accent) {
                            shopTypesCsv = (if (selected) shopTypes - entry.key else shopTypes + entry.key).joinToString(",")
                            onEdit()
                        }
                    }
                }
            }
            Text(
                text = stringResource(R.string.field_city),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CityCodes.forEach { code ->
                    val selected = city == code
                    Surface(
                        modifier = Modifier.clickable { city = code; onEdit() },
                        shape = RoundedCornerShape(999.dp),
                        color = if (selected) accent else Color.White,
                        border = BorderStroke(1.dp, if (selected) accent else CardBorder),
                    ) {
                        Text(
                            text = cityLabel(code),
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                            color = if (selected) Color.White else TextMuted,
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            if (role == Role.Customer) {
                Field(address, { address = it; onEdit() }, R.string.field_address, singleLine = false)
            }
        }

        val message = localError ?: error?.let { stringResource(it.messageRes()) }
        if (message != null) {
            Text(
                text = message,
                color = ErrorRed,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
            )
        }

        Spacer(Modifier.height(12.dp))
        Button(
            onClick = ::submit,
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = accent),
        ) {
            if (busy) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
            } else {
                Text(
                    text = stringResource(if (creating) R.string.action_signup else R.string.action_signin),
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        if (creating) LegalAgreement(accent)
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ModeTab(label: String, selected: Boolean, accent: Color, modifier: Modifier, onClick: () -> Unit) {
    Surface(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = if (selected) accent else Color.White,
        border = BorderStroke(1.dp, if (selected) accent else CardBorder),
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(vertical = 12.dp),
            textAlign = TextAlign.Center,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) Color.White else Color(0xFF333333),
        )
    }
}

@Composable
private fun Field(
    value: String,
    onChange: (String) -> Unit,
    labelRes: Int,
    keyboardType: KeyboardType = KeyboardType.Text,
    secret: Boolean = false,
    singleLine: Boolean = true,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(stringResource(labelRes)) },
        singleLine = singleLine,
        minLines = if (singleLine) 1 else 3,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        visualTransformation = if (secret) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
    )
}

private fun AuthError.messageRes(): Int = when (this) {
    AuthError.InvalidCredentials -> R.string.err_invalid_credentials
    AuthError.EmailTaken -> R.string.err_email_taken
    AuthError.Network -> R.string.err_network
    AuthError.WrongRoleIsCustomer -> R.string.err_wrong_role_customer
    AuthError.WrongRoleIsSeller -> R.string.err_wrong_role_seller
    AuthError.InvalidCode -> R.string.err_code_invalid
    AuthError.LinkExpired -> R.string.err_link_expired
    AuthError.Generic -> R.string.err_generic
}
