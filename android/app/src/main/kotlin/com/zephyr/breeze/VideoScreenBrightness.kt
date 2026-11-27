package com.zephyr.breeze

import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

internal class VideoScreenBrightness(
    private val activity: FragmentActivity,
    messenger: BinaryMessenger,
) {
    private data class Adjustment(val original: Float, val applied: Float)

    private val channel = MethodChannel(messenger, "zephyr/video_screen_brightness")
    private var adjustment: Adjustment? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "get" -> reportBrightness(result)
                "getVolume" -> handleMediaVolume(result)
                "set", "setVolume" -> {
                    val value = call.arguments as? Double
                    when {
                        value == null || !value.isFinite() ->
                            result.error("invalid_arguments", null, null)
                        !activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) ->
                            result.error("unavailable", null, null)
                        call.method == "setVolume" ->
                            handleMediaVolume(result, value.coerceIn(0.0, 1.0))
                        else -> {
                            setBrightness(value.coerceIn(0.0, 1.0).toFloat())
                            reportBrightness(result)
                        }
                    }
                }
                "restore" -> {
                    restore()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun reportBrightness(result: MethodChannel.Result) {
        val value = currentBrightness()
        if (value == null) result.error("unavailable", null, null)
        else result.success(value)
    }

    private fun currentBrightness(): Double? {
        val override = activity.window.attributes.screenBrightness
        if (override in 0f..1f) return override.toDouble()
        val systemValue = runCatching {
            Settings.System.getInt(activity.contentResolver, Settings.System.SCREEN_BRIGHTNESS)
        }.getOrNull() ?: return null
        return systemValue.coerceIn(0, 255) / 255.0
    }

    private fun setBrightness(value: Float) {
        val window = activity.window
        val attributes = window.attributes
        val current = attributes.screenBrightness
        if (current == value) return
        val original = adjustment?.takeIf { it.applied == current }?.original ?: current
        attributes.screenBrightness = value
        window.attributes = attributes
        adjustment = Adjustment(original, value)
    }

    private fun handleMediaVolume(result: MethodChannel.Result, target: Double? = null) {
        val level = try {
            val audio = activity.getSystemService(AudioManager::class.java)
                ?: return result.error("unavailable", null, null)
            if (audio.isVolumeFixed) return result.error("unsupported", null, null)

            val stream = AudioManager.STREAM_MUSIC
            val minimum = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                audio.getStreamMinVolume(stream)
            } else {
                0
            }
            val maximum = audio.getStreamMaxVolume(stream)
            val steps = maximum - minimum
            if (steps <= 0) return result.error("unsupported", null, null)

            if (target != null) {
                audio.setStreamVolume(stream, minimum + (target * steps).roundToInt(), 0)
            }
            val actual = audio.getStreamVolume(stream).coerceIn(minimum, maximum)
            (actual - minimum).toDouble() / steps
        } catch (_: RuntimeException) {
            return result.error("unavailable", null, null)
        }
        result.success(level)
    }

    fun restore() {
        val saved = adjustment ?: return
        adjustment = null
        val window = activity.window
        val attributes = window.attributes
        if (attributes.screenBrightness == saved.applied) {
            // Restoring -1 returns control to Android's normal display policy.
            attributes.screenBrightness = saved.original
            window.attributes = attributes
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        restore()
    }
}
