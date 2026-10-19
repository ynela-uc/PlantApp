package com.plantapp.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

object ImageUtils {
    /**
     * Turns a camera/gallery image into a smaller upright JPEG: respects the EXIF rotation,
     * scales the longest side down to [maxSide], and compresses. Keeps uploads and AI calls cheap and fast.
     */
    fun prepareJpeg(raw: ByteArray, maxSide: Int = 1280, quality: Int = 82): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)

        var sample = 1
        while (bounds.outWidth / (sample * 2) >= maxSide && bounds.outHeight / (sample * 2) >= maxSide) sample *= 2
        val decoded = BitmapFactory.decodeByteArray(raw, 0, raw.size, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: return raw

        val rotation = when (
            ExifInterface(ByteArrayInputStream(raw)).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val scale = maxSide.toFloat() / maxOf(decoded.width, decoded.height)
        val matrix = Matrix().apply {
            if (rotation != 0f) postRotate(rotation)
            if (scale < 1f) postScale(scale, scale)
        }
        val finished = if (matrix.isIdentity) decoded else Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)

        return ByteArrayOutputStream().use { out ->
            finished.compress(Bitmap.CompressFormat.JPEG, quality, out)
            out.toByteArray()
        }
    }
}
