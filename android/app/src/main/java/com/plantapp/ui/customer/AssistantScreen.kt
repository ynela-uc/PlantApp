package com.plantapp.ui.customer

import android.graphics.BitmapFactory
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import com.plantapp.data.Catalog
import com.plantapp.ui.occasionName
import com.plantapp.ui.sectionName
import com.plantapp.ui.categoryName
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.AssistantReply
import com.plantapp.data.ShopMatch
import com.plantapp.data.ShopReach
import com.plantapp.data.findShops
import com.plantapp.data.localized
import com.plantapp.ui.PhotoCapture
import com.plantapp.ui.cityLabel
import com.plantapp.ui.rememberPhotoCapture
import com.plantapp.ui.theme.CardBorder
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.SellerAmberSoft
import com.plantapp.ui.theme.TextMuted

private val ErrorRed = Color(0xFFC62828)
private val ErrorSoft = Color(0xFFFFEBEE)

/** The plant-help chat: photo or question in, answer plus "where to buy" out. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AssistantScreen(
    state: AssistantState,
    customer: CustomerState,
    onSendText: (String) -> Unit,
    onSendPhoto: (ByteArray) -> Unit,
    onNewChat: () -> Unit,
    onOpenListing: (String) -> Unit,
    onBrowse: (section: String?, category: String?, occasion: String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = rememberLang()
    val capture = rememberPhotoCapture(onSendPhoto)
    val listState = rememberLazyListState()
    var input by rememberSaveable { mutableStateOf("") }

    LaunchedEffect(state.messages.size, state.busy) {
        val extra = if (state.busy) 1 else 0
        val last = state.messages.size + extra - 1
        if (last >= 0) listState.animateScrollToItem(last)
    }

    Column(modifier = modifier.fillMaxSize().imePadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.ai_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = PlantGreenDark,
            )
            if (state.messages.isNotEmpty()) {
                TextButton(onClick = onNewChat, enabled = !state.busy) {
                    Text(stringResource(R.string.ai_new_chat), color = PlantGreen, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (state.messages.isEmpty()) {
                EmptyState(capture) { example -> if (!state.busy) onSendText(example) }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                ) {
                    items(state.messages, key = { it.id }) { message ->
                        if (message.fromUser) {
                            UserBubble(message)
                        } else {
                            val reply = message.reply
                            AssistantBubble(
                                text = message.text,
                                reply = reply,
                                lang = lang,
                                matches = if (reply != null) findShops(reply, customer.listings, customer.city) else emptyList(),
                                city = customer.city,
                                onOpenListing = onOpenListing,
                                onBrowse = onBrowse,
                                onFollowUp = { if (!state.busy) onSendText(it) },
                                isLast = message.id == state.messages.last().id && !state.busy,
                            )
                        }
                    }
                    if (state.busy) {
                        item(key = "busy") {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(Modifier.size(20.dp), color = PlantGreen, strokeWidth = 2.dp)
                                Spacer(Modifier.size(10.dp))
                                Text(stringResource(R.string.ai_thinking), color = TextMuted)
                            }
                        }
                    }
                }
            }
        }

        state.error?.let { error ->
            Surface(
                color = ErrorSoft,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
            ) {
                Text(
                    text = stringResource(errorRes(error)),
                    color = ErrorRed,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(12.dp),
                )
            }
        }

        // Input row
        Surface(color = Color.White, shadowElevation = 6.dp) {
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    TextButton(onClick = capture.takePhoto, enabled = !state.busy) { Text("📷", fontSize = 22.sp) }
                    TextButton(onClick = capture.pickPhoto, enabled = !state.busy) { Text("🖼", fontSize = 22.sp) }
                    OutlinedTextField(
                        value = input,
                        onValueChange = { if (it.length <= 500) input = it },
                        placeholder = { Text(stringResource(R.string.ai_input_hint)) },
                        shape = RoundedCornerShape(14.dp),
                        maxLines = 3,
                        modifier = Modifier.weight(1f),
                    )
                    Button(
                        onClick = {
                            onSendText(input)
                            input = ""
                        },
                        enabled = !state.busy && input.isNotBlank(),
                        shape = RoundedCornerShape(12.dp),
                    ) { Text(stringResource(R.string.ai_send), fontWeight = FontWeight.Bold) }
                }
                Text(
                    text = stringResource(R.string.ai_disclaimer),
                    style = MaterialTheme.typography.labelSmall,
                    color = TextMuted,
                    modifier = Modifier.padding(start = 6.dp, top = 4.dp),
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EmptyState(capture: PhotoCapture, onExample: (String) -> Unit) {
    val examples = listOf(
        stringResource(R.string.ai_example_gift),
        stringResource(R.string.ai_example_care),
        stringResource(R.string.ai_example_flowers),
    )
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🌿", fontSize = 56.sp)
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.ai_intro_title),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = stringResource(R.string.ai_intro),
            style = MaterialTheme.typography.bodyMedium,
            color = TextMuted,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(14.dp))
        Surface(shape = RoundedCornerShape(16.dp), color = Color.White, border = BorderStroke(1.dp, CardBorder)) {
            Column(modifier = Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.ai_can_identify), style = MaterialTheme.typography.bodyMedium)
                Text(stringResource(R.string.ai_can_care), style = MaterialTheme.typography.bodyMedium)
                Text(stringResource(R.string.ai_can_gift), style = MaterialTheme.typography.bodyMedium)
                Text(stringResource(R.string.ai_can_shop), style = MaterialTheme.typography.bodyMedium)
            }
        }
        Spacer(Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.ai_try),
            style = MaterialTheme.typography.labelLarge,
            color = TextMuted,
        )
        Spacer(Modifier.height(8.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            examples.forEach { example ->
                Surface(
                    modifier = Modifier.clickable { onExample(example) },
                    shape = RoundedCornerShape(999.dp),
                    color = PlantGreenSoft,
                ) {
                    Text(
                        text = example,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                        color = PlantGreenDark,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
        Spacer(Modifier.height(20.dp))
        Button(
            onClick = capture.takePhoto,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(14.dp),
        ) { Text("📷  " + stringResource(R.string.photo_take), fontWeight = FontWeight.Bold) }
        Spacer(Modifier.height(10.dp))
        OutlinedButton(
            onClick = capture.pickPhoto,
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(14.dp),
        ) { Text(stringResource(R.string.photo_pick), color = PlantGreen) }
    }
}

@Composable
private fun UserBubble(message: ChatMessage) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        Surface(
            color = PlantGreen,
            shape = RoundedCornerShape(18.dp),
            modifier = Modifier.widthIn(max = 300.dp),
        ) {
            Column(modifier = Modifier.padding(10.dp)) {
                message.photo?.let { bytes ->
                    val bitmap = remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() }
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.size(width = 220.dp, height = 180.dp).clip(RoundedCornerShape(12.dp)),
                        )
                    }
                }
                if (message.text.isNotBlank()) {
                    if (message.photo != null) Spacer(Modifier.height(6.dp))
                    Text(message.text, color = Color.White)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AssistantBubble(
    text: String,
    reply: AssistantReply?,
    lang: String,
    matches: List<ShopMatch>,
    city: String,
    onOpenListing: (String) -> Unit,
    onBrowse: (String?, String?, String?) -> Unit,
    onFollowUp: (String) -> Unit,
    isLast: Boolean,
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Surface(
            color = Color.White,
            shape = RoundedCornerShape(18.dp),
            border = BorderStroke(1.dp, CardBorder),
            modifier = Modifier.widthIn(max = 340.dp),
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                if (reply != null && reply.identified) {
                    val name = reply.names.toMap().localized(lang)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = name,
                            fontWeight = FontWeight.Bold,
                            color = PlantGreenDark,
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.weight(1f, fill = false),
                        )
                        HealthChip(reply.health)
                    }
                    if (reply.scientificName.isNotBlank()) {
                        Text(
                            text = reply.scientificName,
                            fontStyle = FontStyle.Italic,
                            color = TextMuted,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                }
                Text(text, style = MaterialTheme.typography.bodyMedium)

                if (reply != null && reply.identified) {
                    Spacer(Modifier.height(14.dp))
                    Text(
                        text = "🛒  " + stringResource(R.string.ai_where_to_buy),
                        fontWeight = FontWeight.Bold,
                        color = PlantGreenDark,
                    )
                    Spacer(Modifier.height(6.dp))
                    if (matches.isEmpty()) {
                        Text(stringResource(R.string.ai_no_shops), color = TextMuted, style = MaterialTheme.typography.bodySmall)
                    } else {
                        val shown = matches.take(8)
                        ShopReach.entries.forEach { reach ->
                            val group = shown.filter { it.reach == reach }
                            if (group.isNotEmpty()) {
                                Text(
                                    text = when (reach) {
                                        ShopReach.SameCity -> stringResource(R.string.ai_group_city, cityLabel(city))
                                        ShopReach.Delivers -> stringResource(R.string.ai_group_delivers, cityLabel(city))
                                        ShopReach.OtherCity -> stringResource(R.string.ai_group_other, cityLabel(city))
                                    },
                                    style = MaterialTheme.typography.labelMedium,
                                    color = TextMuted,
                                    modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
                                )
                                group.forEach { match -> ShopRow(match, lang) { onOpenListing(match.listing.id) } }
                            }
                        }
                    }
                }

                // A shortcut to the products the guide suggests (a section, category or occasion)
                if (reply != null) {
                    val section = Catalog.section(reply.browseSection)
                    val category = section?.categories?.firstOrNull { it.key == reply.browseCategory }
                    val occasion = Catalog.occasions.firstOrNull { it.key == reply.browseOccasion }
                    val label = when {
                        category != null -> "${category.emoji} ${categoryName(category.key)}"
                        section != null -> "${section.emoji} ${sectionName(section.key)}"
                        occasion != null -> "${occasion.emoji} ${occasionName(occasion.key)}"
                        else -> null
                    }
                    if (label != null) {
                        Spacer(Modifier.height(12.dp))
                        Surface(
                            modifier = Modifier.clickable {
                                onBrowse(reply.browseSection.ifBlank { null }, reply.browseCategory.ifBlank { null }, reply.browseOccasion.ifBlank { null })
                            },
                            shape = RoundedCornerShape(999.dp),
                            color = PlantGreen,
                        ) {
                            Text(
                                text = stringResource(R.string.ai_browse, label),
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }

                if (isLast && reply != null && reply.followUps.isNotEmpty()) {
                    Spacer(Modifier.height(12.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        reply.followUps.take(3).forEach { question ->
                            Surface(
                                modifier = Modifier.clickable { onFollowUp(question) },
                                shape = RoundedCornerShape(999.dp),
                                color = PlantGreenSoft,
                            ) {
                                Text(
                                    text = question,
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                    color = PlantGreenDark,
                                    style = MaterialTheme.typography.bodySmall,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HealthChip(health: String) {
    val (res, bg, fg) = when (health) {
        "healthy" -> Triple(R.string.ai_health_healthy, PlantGreenSoft, PlantGreenDark)
        "needs_attention" -> Triple(R.string.ai_health_attention, SellerAmberSoft, SellerAmber)
        "unhealthy" -> Triple(R.string.ai_health_unhealthy, ErrorSoft, ErrorRed)
        else -> return
    }
    Box(modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(bg).padding(horizontal = 10.dp, vertical = 4.dp)) {
        Text(stringResource(res), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = fg)
    }
}

@Composable
private fun ShopRow(match: ShopMatch, lang: String, onClick: () -> Unit) {
    val listing = match.listing
    Surface(
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp).clip(RoundedCornerShape(12.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = Color(0xFFF5F8F7),
        border = BorderStroke(1.dp, CardBorder),
    ) {
        Row(
            modifier = Modifier.padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            PlantPicture(listing, Modifier.size(48.dp).clip(RoundedCornerShape(10.dp)), 24.sp)
            Column(modifier = Modifier.weight(1f)) {
                Text(listing.name.localized(lang), fontWeight = FontWeight.Bold, color = PlantGreenDark, maxLines = 1)
                Text(
                    text = listing.sellers?.let { "${it.name} · ${cityLabel(it.city)}" }.orEmpty(),
                    style = MaterialTheme.typography.bodySmall,
                    color = TextMuted,
                    maxLines = 1,
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(priceText(listing.priceIqd), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                if (!match.exact) {
                    Text(stringResource(R.string.ai_similar), style = MaterialTheme.typography.labelSmall, color = SellerAmber)
                }
            }
        }
    }
}

private fun errorRes(error: AssistantError): Int = when (error) {
    AssistantError.NotConfigured -> R.string.ai_unavailable
    AssistantError.DailyLimit -> R.string.ai_limit
    AssistantError.PhotoLimit -> R.string.ai_photo_limit
    AssistantError.Network -> R.string.err_network
    AssistantError.Failed -> R.string.err_generic
}
