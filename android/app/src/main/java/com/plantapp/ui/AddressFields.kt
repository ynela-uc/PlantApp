package com.plantapp.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.ui.theme.PlantGreen

/**
 * An address as the person types it. [city] is the governorate code (see CityCodes) and [street] the street or building;
 * the other fields are free text. Iraq has no dependable street names or postcodes, so the landmark counts as much as the street.
 */
data class AddressDraft(
    val city: String = "",
    val district: String = "",
    val neighborhood: String = "",
    val street: String = "",
    val landmark: String = "",
    val notes: String = "",
) {
    /** Governorate, district and neighborhood are needed, plus a street/building or a landmark to find the door. */
    val isComplete: Boolean
        get() = city.isNotBlank() && district.isNotBlank() && neighborhood.isNotBlank() && (street.isNotBlank() || landmark.isNotBlank())

    fun trimmed() = copy(
        district = district.trim(), neighborhood = neighborhood.trim(), street = street.trim(),
        landmark = landmark.trim(), notes = notes.trim(),
    )

    companion object {
        /** Keeps the draft across rotation and language changes. */
        val Saver = listSaver<AddressDraft, String>(
            save = { listOf(it.city, it.district, it.neighborhood, it.street, it.landmark, it.notes) },
            restore = { AddressDraft(it[0], it[1], it[2], it[3], it[4], it[5]) },
        )
    }
}

/** Governorate chips and the address fields, one below the other. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AddressFields(draft: AddressDraft, onChange: (AddressDraft) -> Unit, accent: Color = PlantGreen) {
    Column {
        Text(
            text = stringResource(R.string.field_city),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
        )
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            CityCodes.forEach { code ->
                PickChip(cityLabel(code), draft.city == code, accent = accent) { onChange(draft.copy(city = code)) }
            }
        }
        Spacer(Modifier.height(12.dp))
        AddressInput(draft.district, R.string.field_district) { onChange(draft.copy(district = it.take(100))) }
        AddressInput(draft.neighborhood, R.string.field_neighborhood) { onChange(draft.copy(neighborhood = it.take(100))) }
        AddressInput(draft.street, R.string.field_address) { onChange(draft.copy(street = it.take(300))) }
        AddressInput(draft.landmark, R.string.field_landmark) { onChange(draft.copy(landmark = it.take(200))) }
        AddressInput(draft.notes, R.string.field_address_notes, singleLine = false) { onChange(draft.copy(notes = it.take(300))) }
    }
}

@Composable
private fun AddressInput(value: String, labelRes: Int, singleLine: Boolean = true, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(stringResource(labelRes)) },
        singleLine = singleLine,
        minLines = if (singleLine) 1 else 2,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
    )
}

/** The address on one line, for lists and summaries: governorate, district, neighborhood, street, "near landmark". */
@Composable
fun addressText(city: String, district: String, neighborhood: String, street: String, landmark: String): String {
    val near = landmark.takeIf { it.isNotBlank() }?.let { stringResource(R.string.address_near, it) }
    return listOfNotNull(
        city.takeIf { it.isNotBlank() }?.let { cityLabel(it) },
        district.takeIf { it.isNotBlank() },
        neighborhood.takeIf { it.isNotBlank() },
        street.takeIf { it.isNotBlank() },
        near,
    ).joinToString(", ")
}

/** Only the area (governorate and district): shown to a shop before it accepts the order. */
@Composable
fun areaText(city: String, district: String): String =
    listOfNotNull(city.takeIf { it.isNotBlank() }?.let { cityLabel(it) }, district.takeIf { it.isNotBlank() }).joinToString(", ")
