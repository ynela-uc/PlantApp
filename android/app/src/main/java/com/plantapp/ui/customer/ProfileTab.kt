package com.plantapp.ui.customer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.Profile
import com.plantapp.data.ProfileUpdate
import com.plantapp.ui.CityCodes
import com.plantapp.ui.LanguageSelector
import com.plantapp.ui.PickChip
import com.plantapp.ui.cityLabel
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted

@Composable
fun ProfileTab(
    profile: Profile,
    saving: Boolean,
    saveFailed: Boolean,
    onSave: (ProfileUpdate) -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var editing by rememberSaveable { mutableStateOf(false) }
    // A saved profile comes back as a new Profile: close the form.
    LaunchedEffect(profile) { editing = false }

    if (editing) {
        ProfileEditor(
            profile = profile,
            saving = saving,
            saveFailed = saveFailed,
            onCancel = { editing = false },
            onSave = onSave,
            modifier = modifier,
        )
        return
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
    ) {
        Text(
            text = "${profile.firstName} ${profile.lastName}".trim(),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(16.dp))
        InfoRow(R.string.field_phone, profile.phone)
        InfoRow(R.string.field_city, if (profile.city.isBlank()) "" else cityLabel(profile.city))
        InfoRow(R.string.field_address, profile.address)

        Spacer(Modifier.height(16.dp))
        OutlinedButton(
            onClick = { editing = true },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(14.dp),
        ) { Text(stringResource(R.string.profile_edit), color = PlantGreen, fontWeight = FontWeight.SemiBold) }

        Spacer(Modifier.height(28.dp))
        LanguageSelector()

        Spacer(Modifier.height(28.dp))
        OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.action_signout), color = PlantGreen, fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(12.dp))
        com.plantapp.ui.LegalLinks(PlantGreen)
        Spacer(Modifier.height(8.dp))
        com.plantapp.ui.DeleteAccountSection(onDeleted = onSignOut)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProfileEditor(
    profile: Profile,
    saving: Boolean,
    saveFailed: Boolean,
    onCancel: () -> Unit,
    onSave: (ProfileUpdate) -> Unit,
    modifier: Modifier,
) {
    var firstName by rememberSaveable { mutableStateOf(profile.firstName) }
    var lastName by rememberSaveable { mutableStateOf(profile.lastName) }
    var phone by rememberSaveable { mutableStateOf(profile.phone) }
    var city by rememberSaveable { mutableStateOf(profile.city) }
    var address by rememberSaveable { mutableStateOf(profile.address) }
    var missing by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
    ) {
        Text(
            text = stringResource(R.string.profile_edit),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(16.dp))
        Input(firstName, { firstName = it; missing = false }, R.string.field_first_name)
        Input(lastName, { lastName = it; missing = false }, R.string.field_last_name)
        Input(phone, { phone = it; missing = false }, R.string.field_phone, KeyboardType.Phone)
        Text(
            text = stringResource(R.string.field_city),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
        )
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            CityCodes.forEach { code ->
                PickChip(cityLabel(code), city == code, accent = PlantGreen) { city = code; missing = false }
            }
        }
        Spacer(Modifier.height(12.dp))
        Input(address, { address = it; missing = false }, R.string.field_address, singleLine = false)

        if (missing) {
            Text(stringResource(R.string.err_required), color = Color(0xFFC62828), style = MaterialTheme.typography.bodyMedium)
        } else if (saveFailed) {
            Text(stringResource(R.string.err_generic), color = Color(0xFFC62828), style = MaterialTheme.typography.bodyMedium)
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = {
                if (firstName.isBlank() || lastName.isBlank() || phone.isBlank() || city.isBlank() || address.isBlank()) {
                    missing = true
                } else {
                    onSave(ProfileUpdate(firstName.trim(), lastName.trim(), phone.trim(), city, address.trim()))
                }
            },
            enabled = !saving,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
        ) {
            if (saving) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
            else Text(stringResource(R.string.action_save), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = onCancel,
            enabled = !saving,
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(14.dp),
        ) { Text(stringResource(R.string.action_cancel), color = PlantGreen) }
    }
}

@Composable
private fun Input(
    value: String,
    onChange: (String) -> Unit,
    labelRes: Int,
    keyboardType: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(stringResource(labelRes)) },
        singleLine = singleLine,
        minLines = if (singleLine) 1 else 2,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
    )
}

@Composable
private fun InfoRow(labelRes: Int, value: String) {
    if (value.isBlank()) return
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        Text(stringResource(labelRes), color = TextMuted)
        Text(value, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 16.dp))
    }
}
