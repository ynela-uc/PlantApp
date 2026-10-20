package com.plantapp.ui.customer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.plantapp.AppLanguage
import com.plantapp.R
import androidx.compose.ui.Alignment
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.TextUnit
import coil3.compose.AsyncImage
import com.plantapp.data.Listing
import com.plantapp.data.SellerInfo
import com.plantapp.data.plantEmoji
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.SellerAmberSoft
import java.text.NumberFormat
import java.util.Locale

/** Language code of the running UI (ar / ckb / en), used to pick listing text. */
@Composable
fun rememberLang(): String {
    val context = LocalContext.current
    return remember(context) { AppLanguage.current(context).tag }
}

@Composable
fun priceText(amount: Int): String {
    val formatted = NumberFormat.getIntegerInstance(Locale.getDefault()).format(amount)
    return stringResource(R.string.price_format, formatted)
}

/** Small pill showing whether a shop delivers nationwide or only locally. */
@Composable
fun DeliveryBadge(shop: SellerInfo?, modifier: Modifier = Modifier) {
    val nationwide = shop?.isNationwide == true
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (nationwide) PlantGreenSoft else SellerAmberSoft)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(
            text = stringResource(if (nationwide) R.string.delivers_nationwide else R.string.delivers_local),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = if (nationwide) PlantGreenDark else SellerAmber,
        )
    }
}

val PictureBackground = Color(0xFFE8F5E9)

/** The shop's photo of a plant, or the plant emoji until a photo exists. */
@Composable
fun PlantPicture(listing: Listing, modifier: Modifier, emojiSize: TextUnit) {
    Box(modifier = modifier.background(PictureBackground), contentAlignment = Alignment.Center) {
        val url = listing.imageUrl
        if (url != null) {
            AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Text(text = listing.placeholderEmoji, fontSize = emojiSize)
        }
    }
}
