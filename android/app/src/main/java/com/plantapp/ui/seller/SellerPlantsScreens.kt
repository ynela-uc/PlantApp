package com.plantapp.ui.seller

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.plantapp.R
import com.plantapp.data.Catalog
import com.plantapp.ui.PickChip
import com.plantapp.ui.categoryName
import com.plantapp.ui.occasionName
import com.plantapp.ui.sectionName
import com.plantapp.data.Listing
import com.plantapp.data.localized
import com.plantapp.data.plantEmoji
import com.plantapp.data.plantPhotoUrl
import com.plantapp.ui.customer.PictureBackground
import com.plantapp.ui.customer.priceText
import com.plantapp.ui.customer.rememberLang
import com.plantapp.ui.rememberPhotoCapture
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.TextMuted

private val ErrorRed = Color(0xFFC62828)

@Composable
fun SellerPlantsTab(
    state: SellerState,
    onAdd: () -> Unit,
    onEdit: (Listing) -> Unit,
    onToggleStock: (Listing) -> Unit,
    onDelete: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    var pendingDelete by rememberSaveable { mutableStateOf<String?>(null) }

    Column(modifier = modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.plants_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Button(
                onClick = onAdd,
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SellerAmber),
            ) { Text("＋  " + stringResource(R.string.plants_add), fontWeight = FontWeight.Bold) }
        }
        Spacer(Modifier.height(12.dp))

        if (state.listings.isEmpty()) {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
                    Text("🪴", fontSize = 56.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.plants_empty), fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.plants_empty_hint), color = TextMuted, textAlign = TextAlign.Center)
                }
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(state.listings, key = { it.id }) { listing ->
                    PlantRow(listing, lang, onClick = { onEdit(listing) }, onToggleStock = { onToggleStock(listing) }, onDelete = { pendingDelete = listing.id })
                }
                item { Spacer(Modifier.height(12.dp)) }
            }
        }
    }

    pendingDelete?.let { id ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(stringResource(R.string.plant_delete_title)) },
            text = { Text(stringResource(R.string.plant_delete_text)) },
            confirmButton = {
                TextButton(onClick = { onDelete(id); pendingDelete = null }) {
                    Text(stringResource(R.string.action_delete), color = ErrorRed)
                }
            },
            dismissButton = { TextButton(onClick = { pendingDelete = null }) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
}

@Composable
private fun PlantRow(
    listing: Listing,
    lang: String,
    onClick: () -> Unit,
    onToggleStock: () -> Unit,
    onDelete: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = Color.White,
        border = BorderStroke(1.dp, CardBorder),
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                modifier = Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)).background(PictureBackground),
                contentAlignment = Alignment.Center,
            ) {
                val url = listing.imageUrl
                if (url != null) {
                    AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                } else {
                    Text(listing.placeholderEmoji, fontSize = 30.sp)
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(listing.name.localized(lang), fontWeight = FontWeight.Bold, color = PlantGreenDark)
                Text(priceText(listing.priceIqd), style = MaterialTheme.typography.bodyMedium)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(checked = listing.inStock, onCheckedChange = { onToggleStock() }, modifier = Modifier.height(28.dp))
                    Spacer(Modifier.size(8.dp))
                    Text(
                        text = stringResource(if (listing.inStock) R.string.plant_in_stock else R.string.plant_out_of_stock),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (listing.inStock) PlantGreen else ErrorRed,
                    )
                }
            }
            TextButton(onClick = onDelete) { Text("🗑", fontSize = 20.sp) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PlantEditorScreen(
    editor: EditorState,
    onBack: () -> Unit,
    onPhoto: (ByteArray) -> Unit,
    onRunAi: () -> Unit,
    onText: (TextField, String) -> Unit,
    onScientific: (String) -> Unit,
    onHeight: (String) -> Unit,
    onPrice: (String) -> Unit,
    onStock: (Boolean) -> Unit,
    onSave: () -> Unit,
    onSection: (String) -> Unit,
    onCategory: (String) -> Unit,
    onOccasion: (String) -> Unit,
    onUpdate: ((EditorState) -> EditorState) -> Unit,
) {
    val lang = rememberLang()
    val capture = rememberPhotoCapture(onPhoto)
    val isPlant = editor.section == Catalog.PLANTS
    // Occasions and collections suit flowers and gifts; piece counts (packages) suit gifts.
    val showOccasions = editor.section == Catalog.FLOWERS || editor.section == Catalog.GIFTS
    val showPieces = editor.section == Catalog.GIFTS

    Column(modifier = Modifier.fillMaxSize().systemBarsPadding().imePadding()) {
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            val backArrow = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "→" else "←"
            TextButton(onClick = onBack) { Text("$backArrow  ${stringResource(R.string.back)}", color = SellerAmber) }
            Text(
                text = stringResource(if (editor.listingId == null) R.string.editor_title_new else R.string.editor_title_edit),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            Spacer(Modifier.height(16.dp))

            // Photo
            Box(
                modifier = Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(18.dp)).background(PictureBackground),
                contentAlignment = Alignment.Center,
            ) {
                val existing = editor.existingImagePath?.takeIf { it.isNotBlank() }?.let(::plantPhotoUrl)
                when {
                    editor.photoBytes != null -> AsyncImage(model = editor.photoBytes, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    existing != null -> AsyncImage(model = existing, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    else -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("📷", fontSize = 48.sp)
                        Text(stringResource(R.string.editor_photo_hint), color = TextMuted, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 24.dp))
                    }
                }
                if (editor.aiBusy) {
                    Box(Modifier.fillMaxSize().background(Color(0x99000000)), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(color = Color.White)
                            Spacer(Modifier.height(10.dp))
                            Text(stringResource(R.string.editor_ai_busy), color = Color.White, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Button(
                    onClick = capture.takePhoto,
                    enabled = !editor.aiBusy,
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SellerAmber),
                ) { Text("📷  " + stringResource(R.string.photo_take), fontWeight = FontWeight.Bold) }
                OutlinedButton(
                    onClick = capture.pickPhoto,
                    enabled = !editor.aiBusy,
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                ) { Text(stringResource(R.string.photo_pick), color = SellerAmber) }
            }

            // AI
            Spacer(Modifier.height(10.dp))
            Button(
                onClick = onRunAi,
                enabled = editor.photoBytes != null && !editor.aiBusy,
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PlantGreen),
            ) { Text("✨  " + stringResource(R.string.editor_ai_button), fontWeight = FontWeight.Bold) }
            editor.aiMessage?.let { message ->
                Spacer(Modifier.height(8.dp))
                val good = message == AiMessage.Filled
                Surface(shape = RoundedCornerShape(12.dp), color = if (good) PlantGreenSoft else Color(0xFFFFF3E0)) {
                    Text(
                        text = stringResource(aiMessageRes(message)),
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (good) PlantGreenDark else Color(0xFF8A5A00),
                    )
                }
            }

            Spacer(Modifier.height(20.dp))
            // Where the product is filed: section, category, occasions
            PickerTitle(R.string.field_section)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Catalog.sections.forEach { entry ->
                    PickChip("${entry.emoji} ${sectionName(entry.key)}", editor.section == entry.key) { onSection(entry.key) }
                }
            }
            Catalog.section(editor.section)?.let { current ->
                PickerTitle(R.string.field_category)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    current.categories.forEach { category ->
                        PickChip("${category.emoji} ${categoryName(category.key)}", editor.category == category.key) { onCategory(category.key) }
                    }
                }
            }
            if (showOccasions) {
                PickerTitle(R.string.field_occasions)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Catalog.occasions.forEach { occasion ->
                        PickChip("${occasion.emoji} ${occasionName(occasion.key)}", occasion.key in editor.occasions) { onOccasion(occasion.key) }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))

            Field(editor.name[lang].orEmpty(), { onText(TextField.Name, it) }, R.string.field_plant_name, placeholder = editor.name.localized(lang))
            if (isPlant) Field(editor.scientificName, onScientific, R.string.field_scientific)
            Field(editor.description[lang].orEmpty(), { onText(TextField.Description, it) }, R.string.field_description, placeholder = editor.description.localized(lang), singleLine = false)
            if (isPlant) {
                Field(editor.water[lang].orEmpty(), { onText(TextField.Water, it) }, R.string.field_water, placeholder = editor.water.localized(lang), singleLine = false)
                Field(editor.light[lang].orEmpty(), { onText(TextField.Light, it) }, R.string.field_light, placeholder = editor.light.localized(lang), singleLine = false)
                Field(editor.fertilizer[lang].orEmpty(), { onText(TextField.Fertilizer, it) }, R.string.field_fertilizer, placeholder = editor.fertilizer.localized(lang), singleLine = false)
                Field(editor.heightText, onHeight, R.string.field_height, KeyboardType.Number)
            }
            Field(editor.priceText, onPrice, R.string.field_price, KeyboardType.Number)
            Field(
                editor.oldPriceText,
                { value -> onUpdate { it.copy(oldPriceText = value.filter(Char::isDigit).take(9)) } },
                R.string.field_old_price,
                KeyboardType.Number,
            )
            if (showPieces) {
                Field(
                    editor.piecesText,
                    { value -> onUpdate { it.copy(piecesText = value.filter(Char::isDigit).take(3)) } },
                    R.string.field_pieces,
                    KeyboardType.Number,
                )
            }
            if (showOccasions) {
                Field(editor.collection, { value -> onUpdate { it.copy(collection = value.take(40)) } }, R.string.field_collection)
            }

            // Choices the customer makes (colour, scent, ...)
            PickerTitle(R.string.options_title)
            editor.options.forEachIndexed { index, draft ->
                Column(modifier = Modifier.padding(bottom = 8.dp)) {
                    Field(
                        draft.name,
                        { value -> onUpdate { e -> e.copy(options = e.options.mapIndexed { i, d -> if (i == index) d.copy(name = value) else d }) } },
                        R.string.option_name_hint,
                    )
                    Field(
                        draft.valuesText,
                        { value -> onUpdate { e -> e.copy(options = e.options.mapIndexed { i, d -> if (i == index) d.copy(valuesText = value) else d }) } },
                        R.string.option_values_hint,
                    )
                    TextButton(onClick = { onUpdate { e -> e.copy(options = e.options.filterIndexed { i, _ -> i != index }) } }) {
                        Text("🗑  " + stringResource(R.string.action_delete), color = ErrorRed)
                    }
                }
            }
            if (editor.options.size < 3) {
                OutlinedButton(
                    onClick = { onUpdate { it.copy(options = it.options + OptionDraft()) } },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
                ) { Text("＋  " + stringResource(R.string.option_add), color = SellerAmber) }
            }

            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 6.dp)) {
                Switch(checked = editor.inStock, onCheckedChange = onStock)
                Spacer(Modifier.size(10.dp))
                Text(stringResource(R.string.plant_in_stock), fontWeight = FontWeight.SemiBold)
            }
            if (editor.aiGenerated) {
                Text(stringResource(R.string.editor_ai_note), style = MaterialTheme.typography.bodySmall, color = TextMuted)
            }
            Spacer(Modifier.height(16.dp))
        }

        Surface(shadowElevation = 8.dp, color = Color.White) {
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                editor.error?.let {
                    Text(
                        text = stringResource(
                            when (it) {
                                EditorError.Required -> R.string.editor_error_required
                                EditorError.CategoryMissing -> R.string.editor_error_category
                                EditorError.SaveFailed -> R.string.editor_error_save
                            }
                        ),
                        color = ErrorRed,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Spacer(Modifier.height(8.dp))
                }
                Button(
                    onClick = onSave,
                    enabled = !editor.saving && !editor.aiBusy,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SellerAmber),
                ) {
                    if (editor.saving) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                    else Text(stringResource(R.string.action_save), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

private fun aiMessageRes(message: AiMessage): Int = when (message) {
    AiMessage.Filled -> R.string.editor_ai_done
    AiMessage.LowConfidence -> R.string.editor_ai_low
    AiMessage.NotAPlant -> R.string.editor_ai_not_plant
    AiMessage.NotConfigured -> R.string.editor_ai_not_configured
    AiMessage.LimitReached -> R.string.editor_ai_limit
    AiMessage.Network -> R.string.err_network
    AiMessage.Failed -> R.string.editor_ai_failed
}

@Composable
private fun Field(
    value: String,
    onChange: (String) -> Unit,
    labelRes: Int,
    keyboardType: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
    placeholder: String = "",
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(stringResource(labelRes)) },
        placeholder = if (placeholder.isNotBlank()) ({ Text(placeholder, color = Color(0xFFB0B0B0)) }) else null,
        singleLine = singleLine,
        minLines = if (singleLine) 1 else 2,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
    )
}

@Composable
private fun PickerTitle(res: Int) {
    Text(
        text = stringResource(res),
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.Bold,
        color = PlantGreenDark,
        modifier = Modifier.padding(top = 14.dp, bottom = 8.dp),
    )
}
