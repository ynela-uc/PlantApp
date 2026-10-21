package com.plantapp.ui.customer

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.R
import com.plantapp.data.MAX_ADDRESSES
import com.plantapp.data.SavedAddress
import com.plantapp.ui.AddressDraft
import com.plantapp.ui.AddressFields
import com.plantapp.ui.PickChip
import com.plantapp.ui.addressText
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.TextMuted

private val AddressRed = Color(0xFFC62828)

/** The names an address can have besides the customer's own text. */
val AddressLabelKeys = listOf("home", "work", "apartment")

fun SavedAddress.toDraft() = AddressDraft(city, district, neighborhood, street, landmark, notes, lat, lng)

@Composable
fun addressLabelText(label: String): String = when (label) {
    "home" -> stringResource(R.string.addr_label_home)
    "work" -> stringResource(R.string.addr_label_work)
    "apartment" -> stringResource(R.string.addr_label_apartment)
    "" -> stringResource(R.string.addr_label_other)
    else -> label
}

@Composable
private fun SavedAddress.line(): String = addressText(city, district, neighborhood, street, landmark)

/** The list of saved addresses on the account page, with the buttons to add, edit and choose the default. */
@Composable
fun AddressBookSection(
    addresses: List<SavedAddress>,
    busy: Boolean,
    onAdd: () -> Unit,
    onEdit: (SavedAddress) -> Unit,
    onDefault: (SavedAddress) -> Unit,
) {
    Column {
        Text(
            stringResource(R.string.addr_book_title),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(6.dp))
        if (addresses.isEmpty()) Text(stringResource(R.string.addr_empty), color = TextMuted)
        addresses.forEach { address ->
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = Color.White,
                border = BorderStroke(1.dp, if (address.isDefault) PlantGreen else CardBorder),
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(addressLabelText(address.label), fontWeight = FontWeight.Bold, color = PlantGreenDark)
                        if (address.isDefault) {
                            Surface(shape = RoundedCornerShape(999.dp), color = PlantGreenSoft) {
                                Text(
                                    stringResource(R.string.addr_default),
                                    color = PlantGreenDark,
                                    style = MaterialTheme.typography.labelSmall,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                )
                            }
                        }
                    }
                    Text(address.line(), style = MaterialTheme.typography.bodyMedium)
                    if (address.notes.isNotBlank()) Text(address.notes, color = TextMuted, style = MaterialTheme.typography.bodySmall)
                    Row {
                        TextButton(onClick = { onEdit(address) }) { Text(stringResource(R.string.addr_edit), color = PlantGreen) }
                        if (!address.isDefault) {
                            TextButton(onClick = { onDefault(address) }, enabled = !busy) {
                                Text(stringResource(R.string.addr_set_default), color = PlantGreen)
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        if (addresses.size < MAX_ADDRESSES) {
            OutlinedButton(onClick = onAdd, modifier = Modifier.fillMaxWidth().height(48.dp), shape = RoundedCornerShape(14.dp)) {
                Text("+  " + stringResource(R.string.addr_add), color = PlantGreen, fontWeight = FontWeight.SemiBold)
            }
        } else {
            Text(stringResource(R.string.addr_max), color = TextMuted, style = MaterialTheme.typography.bodySmall)
        }
    }
}

/** Add a new address, or edit (and delete) a saved one. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AddressEditor(
    initial: SavedAddress?,
    /** True when no address exists yet: the new one becomes the default. */
    isFirst: Boolean,
    busy: Boolean,
    failed: Boolean,
    onSave: (label: String, draft: AddressDraft, makeDefault: Boolean) -> Unit,
    onDelete: (() -> Unit)?,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val startKey = when {
        initial == null -> if (isFirst) "home" else "other"
        initial.label in AddressLabelKeys -> initial.label
        else -> "other"
    }
    var labelKey by rememberSaveable { mutableStateOf(startKey) }
    var custom by rememberSaveable { mutableStateOf(if (initial != null && initial.label !in AddressLabelKeys) initial.label else "") }
    var addr by rememberSaveable(stateSaver = AddressDraft.Saver) { mutableStateOf(initial?.toDraft() ?: AddressDraft()) }
    var makeDefault by rememberSaveable { mutableStateOf(initial?.isDefault ?: isFirst) }
    var missing by rememberSaveable { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val lockedDefault = isFirst || initial?.isDefault == true

    Column(modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Text(
            stringResource(if (initial == null) R.string.addr_new_title else R.string.addr_edit_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(14.dp))
        Text(stringResource(R.string.addr_label_title), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(6.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            (AddressLabelKeys + "other").forEach { key ->
                PickChip(addressLabelText(if (key == "other") "" else key), labelKey == key, accent = PlantGreen) { labelKey = key }
            }
        }
        if (labelKey == "other") {
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = custom,
                onValueChange = { custom = it.take(40) },
                label = { Text(stringResource(R.string.addr_label_custom_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(Modifier.height(12.dp))
        AddressFields(addr, { addr = it; missing = false }, PlantGreen)

        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.addr_make_default), modifier = Modifier.weight(1f))
            Switch(checked = makeDefault, onCheckedChange = { makeDefault = it }, enabled = !lockedDefault)
        }
        if (missing) Text(stringResource(R.string.err_required), color = AddressRed, style = MaterialTheme.typography.bodyMedium)
        else if (failed) Text(stringResource(R.string.addr_save_failed), color = AddressRed, style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = {
                if (!addr.isComplete) {
                    missing = true
                } else {
                    onSave(if (labelKey == "other") custom.trim() else labelKey, addr.trimmed(), makeDefault || lockedDefault)
                }
            },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
        ) {
            if (busy) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
            else Text(stringResource(R.string.action_save), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onCancel, enabled = !busy, modifier = Modifier.fillMaxWidth().height(50.dp), shape = RoundedCornerShape(14.dp)) {
            Text(stringResource(R.string.action_cancel), color = PlantGreen)
        }
        if (onDelete != null) {
            TextButton(onClick = { confirmDelete = true }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.addr_delete), color = AddressRed)
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(stringResource(R.string.addr_delete_title)) },
            text = { Text(stringResource(R.string.addr_delete_body)) },
            confirmButton = {
                TextButton(onClick = { confirmDelete = false; onDelete?.invoke() }) {
                    Text(stringResource(R.string.addr_delete), color = AddressRed)
                }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
}

/** Checkout: choose one of the saved addresses, or type another one for this order only. */
@Composable
fun AddressPicker(
    addresses: List<SavedAddress>,
    selectedId: String?,
    draft: AddressDraft,
    saveNew: Boolean,
    onSelect: (SavedAddress) -> Unit,
    onOther: () -> Unit,
    onDraft: (AddressDraft) -> Unit,
    onSaveNew: (Boolean) -> Unit,
) {
    Column {
        if (addresses.isNotEmpty()) {
            addresses.forEach { address ->
                AddressChoice(
                    title = addressLabelText(address.label),
                    body = address.line(),
                    selected = selectedId == address.id,
                    onClick = { onSelect(address) },
                )
            }
            AddressChoice(
                title = stringResource(R.string.checkout_use_other),
                body = null,
                selected = selectedId == null,
                onClick = onOther,
            )
            Spacer(Modifier.height(8.dp))
        }
        if (selectedId == null) {
            AddressFields(draft, onDraft, PlantGreen)
            if (addresses.size < MAX_ADDRESSES) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                    Text(stringResource(R.string.checkout_save_address), modifier = Modifier.weight(1f))
                    Switch(checked = saveNew, onCheckedChange = onSaveNew)
                }
            }
        }
    }
}

@Composable
private fun AddressChoice(title: String, body: String?, selected: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = if (selected) PlantGreenSoft else Color.White,
        border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) PlantGreen else CardBorder),
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(title, fontWeight = FontWeight.Bold, color = PlantGreenDark)
            if (body != null) Text(body, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
