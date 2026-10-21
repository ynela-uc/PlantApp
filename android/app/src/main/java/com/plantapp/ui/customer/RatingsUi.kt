package com.plantapp.ui.customer

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.plantapp.R
import com.plantapp.data.Rating
import com.plantapp.data.RatingsRepository
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.TextMuted
import kotlinx.coroutines.launch

/** A shop shows stars only after this many ratings; before that it is "New". */
const val RATING_MIN_COUNT = 3

private val StarGold = Color(0xFFF2B544)
private val RatingErrorRed = Color(0xFFC62828)

@Composable
fun ratingLabel(rating: Double, count: Int): String =
    if (count >= RATING_MIN_COUNT) "★ ${"%.1f".format(rating)} ($count)" else stringResource(R.string.rating_new)

/** Five stars; tap one to choose when [onPick] is given. */
@Composable
fun RatingStarsRow(stars: Int, onPick: ((Int) -> Unit)? = null) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for (i in 1..5) {
            Text(
                text = if (i <= stars) "★" else "☆",
                fontSize = if (onPick != null) 34.sp else 18.sp,
                color = StarGold,
                modifier = if (onPick != null) Modifier.clickable { onPick(i) } else Modifier,
            )
        }
    }
}

/** The latest reviews of a shop (shown on its page). */
@Composable
fun ShopReviews(shopId: String) {
    var ratings by remember(shopId) { mutableStateOf<List<Rating>?>(null) }
    LaunchedEffect(shopId) { ratings = runCatching { RatingsRepository.forShop(shopId) }.getOrDefault(emptyList()) }
    val list = ratings ?: return
    Column(modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
        Text(
            text = stringResource(R.string.reviews_title),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = PlantGreenDark,
        )
        Spacer(Modifier.height(6.dp))
        if (list.isEmpty()) {
            Text(stringResource(R.string.reviews_empty), color = TextMuted)
        } else {
            list.forEach { rating ->
                Column(modifier = Modifier.padding(vertical = 6.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        RatingStarsRow(rating.stars)
                        Text(
                            text = rating.reviewerName.ifBlank { stringResource(R.string.reviewer_anonymous) },
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(rating.createdAt.take(10), color = TextMuted, style = MaterialTheme.typography.bodySmall)
                    }
                    rating.comment?.takeIf { it.isNotBlank() }?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
                }
            }
        }
    }
}

/** On a delivered order: the customer's rating, or the form to give one. */
@Composable
fun RateOrderSection(orderId: String) {
    var mine by remember(orderId) { mutableStateOf<Rating?>(null) }
    var loaded by remember(orderId) { mutableStateOf(false) }
    var stars by rememberSaveable(orderId) { mutableIntStateOf(0) }
    var comment by rememberSaveable(orderId) { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(orderId) {
        mine = runCatching { RatingsRepository.forOrder(orderId) }.getOrNull()
        loaded = true
    }
    if (!loaded) return

    Surface(shape = RoundedCornerShape(16.dp), color = PlantGreenSoft, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            val existing = mine
            if (existing != null) {
                Text(stringResource(R.string.rate_yours), fontWeight = FontWeight.Bold, color = PlantGreenDark)
                Spacer(Modifier.height(4.dp))
                RatingStarsRow(existing.stars)
                existing.comment?.takeIf { it.isNotBlank() }?.let {
                    Spacer(Modifier.height(4.dp))
                    Text(it)
                }
            } else {
                Text(stringResource(R.string.rate_title), fontWeight = FontWeight.Bold, color = PlantGreenDark)
                Spacer(Modifier.height(6.dp))
                RatingStarsRow(stars) { stars = it }
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = comment,
                    onValueChange = { if (it.length <= 300) comment = it },
                    label = { Text(stringResource(R.string.rate_comment_hint)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                if (failed) {
                    Text(stringResource(R.string.rate_failed), color = RatingErrorRed, style = MaterialTheme.typography.bodySmall)
                }
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = {
                        scope.launch {
                            busy = true
                            failed = false
                            try {
                                RatingsRepository.rate(orderId, stars, comment.trim())
                                mine = RatingsRepository.forOrder(orderId)
                            } catch (_: Exception) {
                                failed = true
                            }
                            busy = false
                        }
                    },
                    enabled = stars > 0 && !busy,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    if (busy) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.height(22.dp))
                    else Text(stringResource(R.string.rate_send), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
