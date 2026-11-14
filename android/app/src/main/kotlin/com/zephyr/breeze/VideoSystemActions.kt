package com.zephyr.breeze

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
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

/** Activity owns external pickers. The application process owns keyed MP4 tasks. */
class VideoSystemActions(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private const val SHARE_REQUEST = 2101
        private const val EXPORT_REQUEST = 2102
        private var processDownloads: ManagedVideoDownloads? = null

        private fun managedDownloads(context: Context): ManagedVideoDownloads =
            processDownloads ?: run {
                val handler = Handler(Looper.getMainLooper())
                ManagedVideoDownloads(context.cacheDir, Executors.newSingleThreadExecutor(),
                    post = { action -> handler.post(action) }, clock = SystemClock::elapsedRealtime,
                    foreground = VideoDownloadForegroundService.forProcess(context))
                    .also { processDownloads = it }
            }
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val shareChannel = MethodChannel(messenger, "breeze.video.share")
    private val downloadChannel = MethodChannel(messenger, "breeze.video.download")
    private val binding = Any()
    private val managed by lazy { managedDownloads(activity.applicationContext) }
    private var shareResult: MethodChannel.Result? = null
    private var active: Transfer? = null
    private var pendingExport: Transfer? = null

    private class Transfer(val id: String, val result: MethodChannel.Result, val file: File,
        val managedId: String? = null, val ownedTemp: Boolean = true) {
        val transfer = VideoMp4Transfer()
        val cancelled get() = transfer.cancelled
        val received get() = transfer.received
        val total get() = transfer.total
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
                "status" -> result.success(managedIdentity(args)?.let(managed::status))
                "attach" -> attach(args, result)
                "export" -> exportManaged(args, result)
                "exportArchive" -> exportArchive(args, result)
                "cancel" -> {
                    if (args["transferKey"] == null) {
                        active?.takeIf { it.id == args["id"] }?.let { finish(it, "cancelled") }
                    }
                    managed.cancel(binding, args["id"], args["transferKey"], args["scope"])
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun watch(raw: String): URI? = videoHttps(raw)?.takeIf {
        raw.length <= 2000 && it.rawPath == "/watch" &&
            Regex("v=[0-9]+").matches(it.rawQuery ?: "")
    }

    private fun publicPage(raw: String): URI? = watch(raw) ?: videoHttps(raw)?.takeIf {
        raw.length <= 2000 && it.rawQuery == null &&
            listOf(
                Regex("/voddetail/[1-9][0-9]{0,14}\\.html"),
                Regex("/index\\.php/vod/detail/id/[1-9][0-9]{0,14}\\.html"),
                Regex("/vod/[1-9][0-9]{0,14}/"),
                Regex("/anime/[a-f0-9]{16,64}\\.html"),
                Regex("/videos/[A-Za-z0-9_-]{1,64}"),
            ).any { pattern -> pattern.matches(it.rawPath ?: "") }
    }

    private fun publicHeaders(raw: Any?, page: URI): Map<String, String>? {
        if (raw == null) return emptyMap()
        val values = raw as? Map<*, *> ?: return null
        if (values.size > 3) return null
        val result = mutableMapOf<String, String>()
        for ((key, rawValue) in values) {
            val name = when ((key as? String)?.lowercase()) {
                "referer" -> "Referer"; "origin" -> "Origin"; "user-agent" -> "User-Agent"; else -> return null
            }
            val value = rawValue as? String ?: return null
            if (value.length > 2000 || value.any { it.code < 32 || it.code == 127 }) return null
            if (name != "User-Agent") {
                val target = videoHttps(value) ?: return null
                if (target.host != page.host || (if (target.port == -1) 443 else target.port) !=
                    (if (page.port == -1) 443 else page.port)) return null
                if (name == "Origin") {
                    if (target.rawQuery != null || !(target.rawPath.isNullOrEmpty() || target.rawPath == "/")) return null
                } else if (target.rawQuery != null && publicPage(value) == null) {
                    if (publicPage(value.substringBefore('?')) == null) return null
                    val query = target.rawQuery.split('&')
                    if (query.size != 2 || query.map { it.substringBefore('=') }.toSet() != setOf("line", "episode") ||
                        query.any { it.substringAfter('=', "").isEmpty() || it.substringAfter('=', "").length > 900 }) return null
                }
            }
            result[name] = value
        }
        return result
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
        val id = requestId(args)
        val raw = args["url"] as? String ?: ""
        val media = videoHttps(raw)
        val referer = publicPage(args["referer"] as? String ?: "")
        if (id == null || raw.length > 8192 || media == null ||
            !media.path.lowercase().endsWith(".mp4") || referer == null) {
            result.success(VideoMp4Failure("invalidRequest").result()); return
        }
        val headers = publicHeaders(args["headers"], referer) ?: run {
            result.success(VideoMp4Failure("invalidRequest").result()); return
        }
        if (activity.isFinishing || activity.isDestroyed) { result.success("unavailable"); return }
        val managedId = args["managedId"] as? String
        val identity = managedIdentity(args)
        if (args.containsKey("managedId") && (managedId == null || !validId(managedId)) ||
            args.containsKey("transferKey") && identity == null) {
            result.success(VideoMp4Failure("invalidRequest").result()); return
        }
        val listener = subscriber(id, result)
        if (identity != null && managed.attach(identity, listener)) return
        if (managed.busy) { result.success("busy"); return }
        val open = downloadConnection(args["wifiOnly"] == true) ?: run {
            result.success(VideoMp4Failure("waitingWifi").result()); return
        }
        if (identity != null) {
            managed.start(identity, listener, media, referer, headers, open)
            return
        }
        val name = listOf((args["title"] as? String ?: "Video").take(100),
            (args["quality"] as? String ?: "").take(20)).joinToString(" ")
            .replace(Regex("[\\p{Cntrl}/\\\\:?%*|\"<>]"), " ").trim().ifEmpty { "Video" }
        val file = try { File.createTempFile("breeze-video-", ".mp4", activity.cacheDir) }
            catch (_: Exception) { result.success("failed"); return }
        val job = Transfer(id, result, file, managedId)
        active = job
        progress(job, force = true)
        worker.execute {
            try {
                job.transfer.download(file, media, referer, headers, SystemClock::elapsedRealtime, open) {
                    progress(job)
                }
                main.post { if (active === job) {
                    if (job.managedId != null) commitManaged(job) else export(job, "$name.mp4")
                } }
            } catch (error: Exception) {
                main.post {
                    finish(job, when {
                        job.cancelled -> "cancelled"
                        error is VideoMp4Failure -> error.result()
                        else -> "failed"
                    })
                }
            } finally {
                if (job.cancelled && job.ownedTemp) job.file.delete()
            }
        }
    }

    private fun requestId(args: Map<*, *>): String? =
        (args["id"] as? String)?.takeIf { it.length in 1..80 }

    private fun managedIdentity(args: Map<*, *>): ManagedVideoAttempt? =
        ManagedVideoAttempt.parse(args["transferKey"], args["managedId"], args["scope"])

    private fun subscriber(id: String, result: MethodChannel.Result): ManagedVideoSubscriber =
        ManagedVideoSubscriber(binding, id, result::success) { values ->
            downloadChannel.invokeMethod("progress", values)
        }

    private fun attach(args: Map<*, *>, result: MethodChannel.Result) {
        val id = requestId(args)
        val identity = managedIdentity(args)
        if (id == null || identity == null || !managed.attach(identity, subscriber(id, result))) {
            result.success(null)
        }
    }

    private fun downloadConnection(wifiOnly: Boolean): ((URI) -> HttpURLConnection)? {
        if (!wifiOnly) return { uri -> uri.toURL().openConnection() as HttpURLConnection }
        val connectivity = activity.applicationContext.getSystemService(ConnectivityManager::class.java)
        val network = connectivity?.activeNetwork ?: return null
        val capabilities = connectivity.getNetworkCapabilities(network) ?: return null
        if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return null
        // Bind all hops to the selected Wi-Fi network while the engine is detached.
        return { uri -> network.openConnection(uri.toURL()) as HttpURLConnection }
    }

    private fun validId(id: String) = Regex("^[a-f0-9]{64}$").matches(id)

    private fun managedRoot(): File {
        val root = File(activity.filesDir, "downloads/video-v1")
        check(root.canonicalPath == File(activity.filesDir.canonicalFile, "downloads/video-v1").path)
        check(root.mkdirs() || root.isDirectory)
        return root
    }

    private fun commitManaged(job: Transfer) {
        if (active !== job || job.cancelled) return
        try {
            val id = job.managedId ?: error("identity")
            check(validId(id))
            val root = File(activity.cacheDir, "breeze-video-staging")
            check(root.canonicalPath == File(activity.cacheDir.canonicalFile, "breeze-video-staging").path)
            check(root.mkdirs() || root.isDirectory)
            val stageId = java.util.UUID.randomUUID().toString().replace("-", "")
            val target = File(root, "$stageId.mp4")
            progress(job, saving = true, force = true)
            android.system.Os.rename(job.file.absolutePath, target.absolutePath)
            finish(job, mapOf("status" to "staged", "resourceId" to id,
                "stageId" to stageId, "bytes" to job.received))
        } catch (_: Exception) { finish(job, "failed") }
    }

    private fun exportManaged(args: Map<*, *>, result: MethodChannel.Result) {
        if (active != null || pendingExport != null || managed.busy) { result.success("busy"); return }
        val id = args["resourceId"] as? String
        if (id == null || !validId(id)) { result.success("failed"); return }
        try {
            val root = managedRoot()
            val file = File(root, "$id.mp4")
            check(file.isFile && file.length() > 12 && file.canonicalPath == File(root.canonicalFile, "$id.mp4").path)
            val name = (args["title"] as? String ?: "Video").take(100)
                .replace(Regex("[\\p{Cntrl}/\\\\:?%*|\"<>]"), " ").trim().ifEmpty { "Video" }
            val job = Transfer("video-export-${SystemClock.elapsedRealtime()}", result, file, ownedTemp = false)
            active = job
            export(job, "$name.mp4")
        } catch (_: Exception) { result.success("failed") }
    }

    private fun exportArchive(args: Map<*, *>, result: MethodChannel.Result) {
        if (active != null || pendingExport != null || managed.busy) { result.success("busy"); return }
        val id = args["archiveId"] as? String
        if (id == null || !id.matches(Regex("^[a-f0-9]{32}$"))) { result.success("failed"); return }
        try {
            val root = File(activity.cacheDir.canonicalFile, "breeze-comic-export")
            val folder = File(root, id)
            val file = File(folder, "archive.zip")
            check(root.canonicalPath == root.path && folder.canonicalPath == folder.path &&
                file.canonicalPath == file.path && file.isFile && file.length() >= 4)
            val name = (args["title"] as? String ?: "Comic").take(100)
                .replace(Regex("[\\p{Cntrl}/\\\\:?%*|\"<>]"), " ").trim().ifEmpty { "Comic" }
            val job = Transfer("comic-export-$id", result, file, ownedTemp = false)
            active = job
            export(job, "$name.zip", "application/zip")
        } catch (_: Exception) { result.success("failed") }
    }

    private fun progress(job: Transfer, saving: Boolean = false, force: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - job.lastProgress < 150) return
        job.lastProgress = now
        val values = mapOf("id" to job.id, "received" to job.received, "total" to job.total, "saving" to saving)
        main.post { if (active === job && !job.cancelled) downloadChannel.invokeMethod("progress", values) }
    }

    @Suppress("DEPRECATION")
    private fun export(job: Transfer, name: String, mime: String = "video/mp4") {
        if (activity.isFinishing || activity.isDestroyed) { finish(job, "unavailable"); return }
        job.exporting = true
        pendingExport = job
        if (mime == "video/mp4") progress(job, saving = true, force = true)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
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

    private fun finish(job: Transfer, status: Any) {
        if (active !== job) return
        active = null
        job.transfer.cancel()
        if (job.exporting) {
            @Suppress("DEPRECATION")
            try { activity.finishActivity(EXPORT_REQUEST) } catch (_: Exception) { }
        }
        if (job.ownedTemp) job.file.delete()
        job.result.success(status)
    }

    fun close() {
        shareResult?.success("unavailable")
        shareResult = null
        processDownloads?.detach(binding)
        active?.let { finish(it, "cancelled") }
        shareChannel.setMethodCallHandler(null)
        downloadChannel.setMethodCallHandler(null)
        worker.shutdownNow()
    }
}
