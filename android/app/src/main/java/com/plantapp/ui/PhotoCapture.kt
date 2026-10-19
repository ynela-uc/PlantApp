package com.plantapp.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import java.io.File

/** Two ways to get a photo: the camera app, or an image from the gallery. */
class PhotoCapture(val takePhoto: () -> Unit, val pickPhoto: () -> Unit)

/**
 * Remembers camera and gallery launchers. [onPhoto] receives the raw image bytes
 * (call [ImageUtils.prepareJpeg] on them before uploading or sending to the AI).
 */
@Composable
fun rememberPhotoCapture(onPhoto: (ByteArray) -> Unit): PhotoCapture {
    val context = LocalContext.current
    val latest = rememberUpdatedState(onPhoto)
    val file = remember { File(context.cacheDir, "capture.jpg") }
    val uri = remember { FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file) }

    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { picked ->
        if (picked != null) {
            context.contentResolver.openInputStream(picked)?.use { latest.value(it.readBytes()) }
        }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        if (saved && file.exists()) latest.value(file.readBytes())
    }

    return remember {
        PhotoCapture(
            takePhoto = {
                // Some devices and emulators have no camera app: fall back to the gallery.
                try {
                    camera.launch(uri)
                } catch (_: Exception) {
                    gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
            },
            pickPhoto = {
                gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        )
    }
}
