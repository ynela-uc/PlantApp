package com.plantapp.ui

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.rememberCameraPositionState
import com.plantapp.BuildConfig
import com.plantapp.R
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenDark
import com.plantapp.ui.theme.TextMuted
import kotlinx.coroutines.launch

private val PinRed = Color(0xFFC62828)

/** The map needs a Google Maps key in android/local.properties (MAPS_API_KEY); without it only "use my location" works. */
val MapsEnabled: Boolean get() = BuildConfig.MAPS_ENABLED

/** Opens a place in the phone's maps app (the Google Maps app when installed, else the browser). */
fun openInMaps(context: Context, lat: Double, lng: Double, label: String) {
    val geo = Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(label)})"))
    try {
        context.startActivity(geo)
    } catch (_: Exception) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng")))
        } catch (_: Exception) { }
    }
}

/**
 * Returns a function that asks for location permission (once) and then reads where the phone is.
 * [onResult] gets (latitude, longitude), or null when the permission was refused or no position was found.
 */
@Composable
fun rememberLocationRequester(onResult: (Pair<Double, Double>?) -> Unit): () -> Unit {
    val context = LocalContext.current
    val latest by rememberUpdatedState(onResult)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { grants ->
        if (grants.values.any { it }) readLocation(context) { latest(it) } else latest(null)
    }
    return {
        val granted = listOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            .any { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }
        if (granted) readLocation(context) { latest(it) }
        else launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }
}

@SuppressLint("MissingPermission")
private fun readLocation(context: Context, onResult: (Pair<Double, Double>?) -> Unit) {
    val client = LocationServices.getFusedLocationProviderClient(context)
    client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, CancellationTokenSource().token)
        .addOnSuccessListener { location ->
            if (location != null) {
                onResult(location.latitude to location.longitude)
            } else {
                // No fresh fix: the last known position is still a good start.
                client.lastLocation
                    .addOnSuccessListener { last -> onResult(last?.let { it.latitude to it.longitude }) }
                    .addOnFailureListener { onResult(null) }
            }
        }
        .addOnFailureListener { onResult(null) }
}

/** "Use my location", "Choose on the map" and the state of the pin, shown under the address fields. */
@Composable
fun PinSection(draft: AddressDraft, onChange: (AddressDraft) -> Unit) {
    val context = LocalContext.current
    var busy by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var guessed by remember { mutableStateOf(false) }
    var showMap by remember { mutableStateOf(false) }

    /** Sets the pin; when no governorate was chosen yet, suggests the nearest one. */
    fun place(lat: Double, lng: Double) {
        val suggest = draft.city.isBlank()
        guessed = suggest
        onChange(draft.copy(lat = lat, lng = lng, city = if (suggest) nearestGovernorate(lat, lng) else draft.city))
    }

    val requestLocation = rememberLocationRequester { result ->
        busy = false
        failed = result == null
        if (result != null) place(result.first, result.second)
    }

    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Text(stringResource(R.string.pin_title), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        Text(stringResource(R.string.pin_hint), color = TextMuted, style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedButton(
                onClick = { busy = true; failed = false; requestLocation() },
                enabled = !busy,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.weight(1f),
            ) { Text(if (busy) stringResource(R.string.pin_getting) else "📍 " + stringResource(R.string.pin_use_location), color = PlantGreen) }
            OutlinedButton(
                onClick = { showMap = true },
                enabled = MapsEnabled,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.weight(1f),
            ) { Text("🗺 " + stringResource(R.string.pin_choose_map), color = PlantGreen) }
        }
        if (!MapsEnabled) Text(stringResource(R.string.pin_map_not_set_up), color = TextMuted, style = MaterialTheme.typography.bodySmall)
        if (draft.hasPin) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text("✓ " + stringResource(R.string.pin_saved), color = PlantGreenDark, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                TextButton(onClick = { onChange(draft.copy(lat = null, lng = null)); guessed = false }) {
                    Text(stringResource(R.string.pin_remove), color = PinRed)
                }
            }
            TextButton(onClick = { openInMaps(context, draft.lat!!, draft.lng!!, "") }) { Text(stringResource(R.string.map_open), color = PlantGreen) }
        }
        if (failed) Text(stringResource(R.string.pin_failed), color = PinRed, style = MaterialTheme.typography.bodySmall)
        if (guessed) Text(stringResource(R.string.pin_guessed), color = TextMuted, style = MaterialTheme.typography.bodySmall)
    }

    if (showMap) {
        MapPickerDialog(
            lat = draft.lat,
            lng = draft.lng,
            hintCity = draft.city,
            onConfirm = { lat, lng -> showMap = false; place(lat, lng) },
            onDismiss = { showMap = false },
        )
    }
}

/** Full-screen map with the pin fixed in the middle: move the map until the pin is on the door, then confirm. */
@Composable
private fun MapPickerDialog(lat: Double?, lng: Double?, hintCity: String, onConfirm: (Double, Double) -> Unit, onDismiss: () -> Unit) {
    val start = when {
        lat != null && lng != null -> LatLng(lat, lng)
        GovernorateCenters[hintCity] != null -> GovernorateCenters.getValue(hintCity).let { LatLng(it.first, it.second) }
        else -> LatLng(33.3152, 44.3661)
    }
    val camera = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(start, if (lat != null) 17f else 12f)
    }
    val scope = rememberCoroutineScope()
    var failed by remember { mutableStateOf(false) }
    val requestLocation = rememberLocationRequester { result ->
        failed = result == null
        if (result != null) scope.launch { camera.animate(CameraUpdateFactory.newLatLngZoom(LatLng(result.first, result.second), 17f)) }
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize()) {
                GoogleMap(
                    modifier = Modifier.fillMaxSize(),
                    cameraPositionState = camera,
                    uiSettings = MapUiSettings(zoomControlsEnabled = true, myLocationButtonEnabled = false),
                )
                // The pin stays in the middle of the screen; its tip marks the chosen spot.
                Text("📍", fontSize = 40.sp, modifier = Modifier.align(Alignment.Center).offset(y = (-20).dp))
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = Color.White.copy(alpha = 0.92f),
                    modifier = Modifier.align(Alignment.TopCenter).systemBarsPadding().padding(12.dp),
                ) {
                    Text(stringResource(R.string.pin_map_title), modifier = Modifier.padding(12.dp), fontWeight = FontWeight.SemiBold)
                }
                Column(modifier = Modifier.align(Alignment.BottomCenter).systemBarsPadding().padding(16.dp)) {
                    if (failed) {
                        Surface(shape = RoundedCornerShape(8.dp), color = Color.White.copy(alpha = 0.92f)) {
                            Text(stringResource(R.string.pin_failed), color = PinRed, modifier = Modifier.padding(8.dp))
                        }
                        Spacer(Modifier.height(6.dp))
                    }
                    Button(
                        onClick = { onConfirm(camera.position.target.latitude, camera.position.target.longitude) },
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(14.dp),
                    ) { Text(stringResource(R.string.pin_confirm), fontWeight = FontWeight.Bold) }
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        Surface(shape = RoundedCornerShape(14.dp), color = Color.White, modifier = Modifier.weight(1f)) {
                            TextButton(onClick = { failed = false; requestLocation() }) { Text("📍 " + stringResource(R.string.pin_use_location), color = PlantGreen) }
                        }
                        Surface(shape = RoundedCornerShape(14.dp), color = Color.White, modifier = Modifier.weight(1f)) {
                            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel), color = PlantGreen) }
                        }
                    }
                }
            }
        }
    }
}
