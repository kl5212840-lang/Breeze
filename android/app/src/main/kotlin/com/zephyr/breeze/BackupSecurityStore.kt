package com.zephyr.breeze

import android.content.Context
import android.app.Activity
import android.content.Intent
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.io.File

/** Only authenticated ciphertext is stored in preferences; wrapping keys stay
 * in Android Keystore and never enter portable app backups. */
class BackupSecurityStore(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "breeze/backup_security")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val preferences = activity.getSharedPreferences("breeze_device_backup_keys", Context.MODE_PRIVATE)
    private val prefix = activity.packageName + ".backup-security."
    private var export: Pair<File, MethodChannel.Result>? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "supported") { result.success(true); return@setMethodCallHandler }
            if (call.method == "exportFile") {
                try {
                    check(export == null)
                    val path = call.argument<String>("path") ?: error("invalid")
                    val file = File(path).canonicalFile
                    require(file.isFile && file.path.startsWith(activity.cacheDir.canonicalPath + File.separator))
                    require(file.extension in setOf("zip", "breezebackup", "breezerecovery"))
                    export = Pair(file, result)
                    activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, file.name)
                    }, 3762)
                } catch (_: Exception) { export = null; result.success("failed") }
                return@setMethodCallHandler
            }
            if (call.method !in setOf("readKey", "writeKey", "deleteKey")) {
                result.notImplemented(); return@setMethodCallHandler
            }
            val id = call.argument<String>("archiveId")
            val bytes = call.argument<ByteArray>("key")
            if (id == null || !id.matches(Regex("^[a-f0-9]{32}$")) ||
                (call.method == "writeKey" && bytes?.size != 32)) {
                result.error("invalid_arguments", null, null); return@setMethodCallHandler
            }
            executor.execute {
                try {
                    val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                    val alias = prefix + id
                    val output: ByteArray? = when (call.method) {
                        "readKey" -> {
                            val encoded = preferences.getString(id, null)
                            if (encoded == null) null else {
                                val wrapped = Base64.decode(encoded, Base64.NO_WRAP)
                                require(wrapped.size == 60)
                                val key = store.getKey(alias, null) as? SecretKey ?: error("unavailable")
                                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, wrapped.copyOfRange(0, 12)))
                                cipher.updateAAD(alias.toByteArray(Charsets.UTF_8))
                                cipher.doFinal(wrapped.copyOfRange(12, wrapped.size)).also { require(it.size == 32) }
                            }
                        }
                        "writeKey" -> {
                            val key = (store.getKey(alias, null) as? SecretKey) ?: KeyGenerator.getInstance("AES", "AndroidKeyStore").run {
                                init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                                    .setKeySize(256).build())
                                generateKey()
                            }
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.ENCRYPT_MODE, key)
                            cipher.updateAAD(alias.toByteArray(Charsets.UTF_8))
                            val encrypted = cipher.doFinal(bytes!!)
                            require(cipher.iv.size == 12)
                            check(preferences.edit().putString(id, Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP)).commit())
                            null
                        }
                        else -> {
                            check(preferences.edit().remove(id).commit())
                            if (store.containsAlias(alias)) store.deleteEntry(alias)
                            null
                        }
                    }
                    main.post { result.success(output) }
                } catch (_: Exception) {
                    main.post { result.error("device_storage_unavailable", null, null) }
                } finally { bytes?.fill(0) }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 3762) return false
        val pending = export ?: return true
        export = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { pending.second.success("cancelled"); return true }
        executor.execute {
            try {
                activity.contentResolver.openOutputStream(uri)?.use { output ->
                    pending.first.inputStream().use { it.copyTo(output) }
                } ?: error("unavailable")
                main.post { pending.second.success("saved") }
            } catch (_: Exception) { main.post { pending.second.success("failed") } }
        }
        return true
    }

    fun close() {
        channel.setMethodCallHandler(null)
        export?.second?.success("cancelled"); export = null
        executor.shutdown()
    }
}
