package com.zephyr.breeze

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class ClassicLauncherActivity : MainActivity()

internal object LauncherAppIcon {
    private const val CHANNEL = "breeze.appearance.app_icon"
    private const val CLASSIC_ICON_NAME = "AppIconClassic"
    private const val CLASSIC_COMPONENT = "com.zephyr.breeze.ClassicLauncherIcon"

    fun register(context: Context, messenger: BinaryMessenger) {
        val host = LauncherComponents(context)
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(host.status())
                "select" -> when (val name = call.arguments as? String) {
                    "", CLASSIC_ICON_NAME -> result.success(host.select(name == CLASSIC_ICON_NAME))
                    else -> result.error("INVALID_ICON", "Unknown launcher icon", null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private class LauncherComponents(private val context: Context) {
        private val pm = context.packageManager
        private val default = ComponentName(context, MainActivity::class.java)
        private val classic = ComponentName(context.packageName, CLASSIC_COMPONENT)

        private fun enabled(component: ComponentName): Boolean =
            when (pm.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> component == default
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                else -> false
            }

        fun status(failed: Boolean = false): Map<String, Any?> {
            val defaultEnabled = enabled(default)
            val classicEnabled = enabled(classic)
            val showClassic = classicEnabled && !defaultEnabled
            val icon = if (showClassic) R.mipmap.ic_launcher_classic else R.mipmap.ic_launcher
            val preview = runCatching {
                context.resources.openRawResource(icon).use { it.readBytes() }
            }.getOrNull()
            val night = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return mapOf(
                "supported" to true,
                "failed" to (failed || defaultEnabled == classicEnabled),
                "iconName" to if (showClassic) CLASSIC_ICON_NAME else "",
                "previewAppearance" to if (night == Configuration.UI_MODE_NIGHT_YES) "dark" else "light",
                "preview" to preview,
            )
        }

        fun select(useClassic: Boolean): Map<String, Any?> {
            val selected = if (useClassic) classic else default
            val previous = if (useClassic) default else classic
            val keepProcess = PackageManager.DONT_KILL_APP
            val success = runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.setComponentEnabledSettings(
                        listOf(
                            PackageManager.ComponentEnabledSetting(selected, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, keepProcess),
                            PackageManager.ComponentEnabledSetting(previous, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, keepProcess),
                        ),
                    )
                } else {
                    // Keep a launcher available even if the second write fails.
                    val oldSelected = pm.getComponentEnabledSetting(selected)
                    pm.setComponentEnabledSetting(selected, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, keepProcess)
                    try {
                        pm.setComponentEnabledSetting(previous, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, keepProcess)
                    } catch (error: RuntimeException) {
                        if (enabled(previous)) {
                            pm.setComponentEnabledSetting(selected, oldSelected, keepProcess)
                        }
                        throw error
                    }
                }
                enabled(selected) && !enabled(previous)
            }.getOrDefault(false)
            return status(failed = !success)
        }
    }
}
