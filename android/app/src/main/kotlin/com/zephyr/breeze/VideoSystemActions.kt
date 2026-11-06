package com.zephyr.breeze

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors

/** Foreground, explicit video actions. No account cookies or signed URLs are logged. */
class VideoSystemActions(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private const val SHARE_REQUEST = 2101
        private const val EXPORT_REQUEST = 2102
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val shareChannel = MethodChannel(messenger, "breeze.video.share")
    private val downloadChannel = MethodChannel(messenger, "breeze.video.download")
    private var shareResult: MethodChannel.Result? = null
    private var active: Transfer? = null
    private var pendingExport: Transfer? = null

    private class Transfer(val id: String, val result: MethodChannel.Result, val file: File) {
        @Volatile var cancelled = false
        @Volatile var connection: HttpURLConnection? = null
        var received = 0L
        var total = -1L
        var lastProgress = 0L
        var exporting = false
    }

    init {
        shareChannel.setMethodCallHandler { call, result ->
            if (call.method != "share") result.notImplemented()
            else share(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>(), result)
        }
        downloadChannel.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "start" -> start(args, result)
                "cancel" -> {
                    active?.takeIf { it.id == args["id"] }?.let { finish(it, "cancelled") }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun https(raw: String): URI? = try {
        URI(raw).takeIf {
            it.scheme == "https" && !it.host.isNullOrEmpty() && it.rawUserInfo == null &&
                (it.port == -1 || it.port == 443) && it.rawFragment == null
        }
    } catch (_: Exception) { null }

    private fun watch(raw: String): URI? = https(raw)?.takeIf {
        raw.length <= 2000 && it.rawPath == "/watch" &&
            Regex("v=[0-9]+").matches(it.rawQuery ?: "")
    }

    private fun publicPage(raw: String): URI? = watch(raw) ?: https(raw)?.takeIf {
        raw.length <= 2000 && it.rawQuery == null &&
            Regex("/voddetail/[1-9][0-9]{0,14}\\.html").matches(it.rawPath ?: "")
    }

    @Suppress("DEPRECATION")
    private fun share(args: Map<*, *>, result: MethodChannel.Result) {
        if (shareResult != null) { result.success("busy"); return }
        val url = publicPage(args["url"] as? String ?: "")
        if (url == null) { result.success("failed"); return }
        if (activity.isFinishing || activity.isDestroyed) { result.success("unavailable"); return }
        val title = (args["title"] as? String ?: "").trim().take(300)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, listOf(title, url.toString()).filter { it.isNotEmpty() }.joinToString("\n"))
            putExtra(Intent.EXTRA_TITLE, title)
        }
        shareResult = result
        try {
            activity.startActivityForResult(Intent.createChooser(send, null), SHARE_REQUEST)
        } catch (_: Exception) {
            shareResult = null
            result.success("unavailable")
        }
    }

    private fun start(args: Map<*, *>, result: MethodChannel.Result) {
        if (active != null || pendingExport != null) { result.success("busy"); return }
        val id = args["id"] as? String ?: ""
        val raw = args["url"] as? String ?: ""
        val media = https(raw)
        val referer = watch(args["referer"] as? String ?: "")
        if (id.isEmpty() || id.length > 80 || raw.length > 8192 || media == null ||
            !media.path.lowercase().endsWith(".mp4") || referer == null) {
            result.success("failed"); return
        }
        if (activity.isFinishing || activity.isDestroyed) { result.success("unavailable"); return }
        val name = listOf((args["title"] as? String ?: "Video").take(100),
            (args["quality"] as? String ?: "").take(20)).joinToString(" ")
            .replace(Regex("[\\p{Cntrl}/\\\\:?%*|\"<>]"), " ").trim().ifEmpty { "Video" }
        val file = try { File.createTempFile("breeze-video-", ".mp4", activity.cacheDir) }
            catch (_: Exception) { result.success("failed"); return }
        val job = Transfer(id, result, file)
        active = job
        progress(job, force = true)
        worker.execute {
            try {
                transfer(job, media, referer)
                main.post { if (active === job) export(job, "$name.mp4") }
            } catch (_: Exception) {
                main.post { finish(job, if (job.cancelled) "cancelled" else "failed") }
            } finally {
                job.connection?.disconnect()
                job.connection = null
                if (job.cancelled) job.file.delete()
            }
        }
    }

    private fun transfer(job: Transfer, original: URI, referer: URI) {
        var target = original
        var redirects = 0
        val started = SystemClock.elapsedRealtime()
        while (!job.cancelled) {
            val connection = target.toURL().openConnection() as HttpURLConnection
            job.connection = connection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 45000
            connection.readTimeout = 45000
            connection.useCaches = false
            connection.setRequestProperty("Accept-Encoding", "identity")
            if (target.host == original.host) connection.setRequestProperty("Referer", referer.toString())
            val code = connection.responseCode
            if (code in listOf(301, 302, 303, 307, 308)) {
                check(++redirects <= 5)
                val next = target.resolve(connection.getHeaderField("Location") ?: error("redirect"))
                target = https(next.toString()) ?: error("redirect")
                connection.disconnect()
                continue
            }
            check(code in 200..299)
            val mime = connection.contentType?.substringBefore(';')?.trim()?.lowercase().orEmpty()
            check(mime.isEmpty() || mime in listOf("video/mp4", "application/mp4", "application/octet-stream", "binary/octet-stream"))
            job.total = connection.contentLengthLong
            connection.inputStream.buffered().use { input ->
                val header = ByteArray(12)
                var offset = 0
                while (offset < header.size) {
                    val count = input.read(header, offset, header.size - offset)
                    check(count > 0)
                    offset += count
                }
                check(String(header, 4, 4, Charsets.US_ASCII) == "ftyp")
                job.file.outputStream().use { output ->
                    output.write(header)
                    job.received = header.size.toLong()
                    val buffer = ByteArray(128 * 1024)
                    while (true) {
                        check(!job.cancelled && SystemClock.elapsedRealtime() - started < 3600000)
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        job.received += count
                        progress(job)
                    }
                }
            }
            check(!job.cancelled && job.received > 12 && (job.total <= 0 || job.received == job.total))
            return
        }
        error("cancelled")
    }

    private fun progress(job: Transfer, saving: Boolean = false, force: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - job.lastProgress < 150) return
        job.lastProgress = now
        val values = mapOf("id" to job.id, "received" to job.received, "total" to job.total, "saving" to saving)
        main.post { if (active === job && !job.cancelled) downloadChannel.invokeMethod("progress", values) }
    }

    @Suppress("DEPRECATION")
    private fun export(job: Transfer, name: String) {
        if (activity.isFinishing || activity.isDestroyed) { finish(job, "unavailable"); return }
        job.exporting = true
        pendingExport = job
        progress(job, saving = true, force = true)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/mp4"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        try { activity.startActivityForResult(intent, EXPORT_REQUEST) }
        catch (_: Exception) { pendingExport = null; finish(job, "unavailable") }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request == SHARE_REQUEST) {
            val result = shareResult
            shareResult = null
            // Android cannot confirm that another app actually sent a share.
            result?.success("presented")
            return true
        }
        if (request != EXPORT_REQUEST) return false
        val job = pendingExport ?: return true
        pendingExport = null
        job.exporting = false
        if (active !== job) return true
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) { finish(job, "cancelled"); return true }
        worker.execute {
            var saved = false
            try {
                activity.contentResolver.openOutputStream(uri, "w")?.use { output ->
                    job.file.inputStream().use { input ->
                        val buffer = ByteArray(128 * 1024)
                        while (true) {
                            check(!job.cancelled)
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                    }
                } ?: error("export")
                saved = !job.cancelled
            } catch (_: Exception) { /* Report generic failure; never log URL/provider details. */ }
            if (!saved) try { DocumentsContract.deleteDocument(activity.contentResolver, uri) } catch (_: Exception) { }
            main.post { finish(job, if (saved) "saved" else if (job.cancelled) "cancelled" else "failed") }
        }
        return true
    }

    private fun finish(job: Transfer, status: String) {
        if (active !== job) return
        active = null
        job.cancelled = true
        if (job.exporting) {
            @Suppress("DEPRECATION")
            try { activity.finishActivity(EXPORT_REQUEST) } catch (_: Exception) { }
        }
        job.connection?.disconnect()
        job.file.delete()
        job.result.success(status)
    }

    fun close() {
        shareResult?.success("unavailable")
        shareResult = null
        active?.let { finish(it, "cancelled") }
        shareChannel.setMethodCallHandler(null)
        downloadChannel.setMethodCallHandler(null)
        worker.shutdownNow()
    }
}
