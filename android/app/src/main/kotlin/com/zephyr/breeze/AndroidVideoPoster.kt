package com.zephyr.breeze

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.roundToInt

/** Decode one frame from an already-authorized local file descriptor. */
internal object AndroidVideoPoster {
    private const val MAX_EDGE = 480
    private const val MAX_COMPAT_PIXELS = 1920L * 1080
    private const val MAX_BYTES = 1024 * 1024

    fun extract(file: File): ByteArray? = try {
        file.inputStream().use { input ->
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(input.fd)
                extract(retriever)
            } finally {
                retriever.release()
            }
        }
    } catch (_: Exception) {
        null
    }

    private fun extract(retriever: MediaMetadataRetriever): ByteArray? {
        val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            ?.toIntOrNull()?.takeIf { it > 0 } ?: return null
        val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            ?.toIntOrNull()?.takeIf { it > 0 } ?: return null
        val frameOption = MediaMetadataRetriever.OPTION_CLOSEST_SYNC
        val frame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull()
            val (displayWidth, displayHeight) = if (rotation == 90 || rotation == 270)
                height to width else width to height
            val (targetWidth, targetHeight) = dimensions(displayWidth, displayHeight)
            retriever.getScaledFrameAtTime(0, frameOption, targetWidth, targetHeight)
        } else {
            if (width.toLong() * height > MAX_COMPAT_PIXELS) return null
            retriever.getFrameAtTime(0, frameOption)
        } ?: return null
        try {
            val (targetWidth, targetHeight) = dimensions(frame.width, frame.height)
            val resized = Bitmap.createScaledBitmap(frame, targetWidth, targetHeight, true)
            try {
                val output = ByteArrayOutputStream()
                return if (resized.compress(Bitmap.CompressFormat.JPEG, 88, output) &&
                    output.size() in 1..MAX_BYTES) output.toByteArray() else null
            } finally {
                if (resized !== frame) resized.recycle()
            }
        } finally {
            frame.recycle()
        }
    }

    private fun dimensions(width: Int, height: Int): Pair<Int, Int> {
        val scale = minOf(1.0, MAX_EDGE.toDouble() / maxOf(width, height))
        return (width * scale).roundToInt().coerceAtLeast(1) to
            (height * scale).roundToInt().coerceAtLeast(1)
    }
}
