package com.zephyr.breeze

import android.content.Context
import android.net.ConnectivityManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors

/** Android implementation of the shared HLS staging and local playback contract. */
internal class AndroidHlsAssets(context: Context, messenger: BinaryMessenger) {
    private companion object {
        val storage = Executors.newSingleThreadExecutor()
        val writers = Executors.newFixedThreadPool(3)
        val main = Handler(Looper.getMainLooper())
        val active = mutableMapOf<String, Job>()
        val liveReceipts = mutableSetOf<String>() // main-queue state
        var processStore: AndroidHlsStore? = null // storage-queue state
    }

    private class Job(
        val id: String,
        val binding: HlsBinding,
        val metadata: Map<String, Any>,
        val expected: String,
        val recoverable: Boolean,
        val result: MethodChannel.Result,
        val owner: Any,
    ) {
        var lease: VideoDownloadForeground.Lease? = null
        var started = false
        @Volatile var transfer: AndroidHlsTransfer? = null
        @Volatile var failure: String? = null
    }

    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "breeze.video.hls")
    private val bindingOwner = Any()
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "supported" -> result.success(true)
                "start" -> start(args, result)
                "cancel" -> {
                    (args["id"] as? String)?.let(active::get)
                        ?.takeIf { it.owner === bindingOwner }?.let { cancel(it, "cancelled") }
                    result.success(null)
                }
                "recoverySnapshot" -> {
                    val excluded = liveReceipts.toSet()
                    perform(result) { it.snapshot(excluded) }
                }
                "commit" -> withBinding(args, result) { store, binding -> store.commit(binding) }
                "discard" -> withBinding(args, result, requiresResource = false) { store, binding -> store.discard(binding) }
                "delete" -> withBinding(args, result) { store, binding -> store.delete(binding) }
                "ackRecovery" -> withBinding(args, result) { store, binding ->
                    val accepted = store.acknowledge(binding)
                    if (accepted) main.post { liveReceipts.remove(binding.assetId) }
                    accepted
                }
                "releaseRecovery" -> {
                    val binding = HlsBinding.parse(args)
                    if (binding != null) {
                        liveReceipts.remove(binding.assetId)
                        if (!closed) channel.invokeMethod("recoveryChanged", null)
                    }
                    result.success(binding != null)
                }
                "cancelRecovery" -> withBinding(args, result) { store, binding -> store.discard(binding) }
                "list" -> perform(result) { it.list() }
                "acquirePlayback" -> withBinding(args, result) { store, binding ->
                    val (lease, manifest) = store.acquire(binding, bindingOwner)
                    try {
                        mapOf("leaseId" to lease, "fileURL" to manifest.toURI().toASCIIString(),
                            "subtitles" to store.captions(binding, lease, bindingOwner))
                    } catch (error: Exception) {
                        store.release(binding, lease, bindingOwner)
                        throw error
                    }
                }
                "releasePlayback" -> withBinding(args, result) { store, binding ->
                    store.release(binding, args["leaseId"] as? String ?: "", bindingOwner)
                }
                "hideTasks" -> perform(result) { store ->
                    store.hideTasks((args["keys"] as? List<*>)?.filterIsInstance<String>()?.toSet().orEmpty())
                }
                "stageRemoval" -> perform(result) { store ->
                    val source = args["source"] as? String ?: error("Missing HLS source")
                    val resources = args["resources"] as? List<*> ?: error("Missing HLS bindings")
                    val bindings = resources.map {
                        HlsBinding.parse(it as? Map<*, *> ?: error("Invalid HLS binding"))
                            ?: error("Invalid HLS binding")
                    }.toSet()
                    store.stageRemoval(source, bindings)
                }
                "commitRemoval", "rollbackRemoval" -> perform(result) { store ->
                    store.finishRemoval(args["token"] as? String ?: "", call.method == "commitRemoval")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun store() = processStore ?: AndroidHlsStore(
        File(app.noBackupFilesDir.canonicalFile, "breeze-hls-v1"),
    ).also { processStore = it }

    private fun perform(result: MethodChannel.Result, operation: (AndroidHlsStore) -> Any?) {
        storage.execute {
            try {
                val value = operation(store())
                main.post { if (!closed) result.success(value) }
            } catch (_: Exception) {
                main.post { if (!closed) result.error("storage", "Offline video storage is unavailable", null) }
            }
        }
    }

    private fun withBinding(
        args: Map<*, *>,
        result: MethodChannel.Result,
        requiresResource: Boolean = true,
        operation: (AndroidHlsStore, HlsBinding) -> Any?,
    ) {
        val binding = HlsBinding.parse(args, requiresResource)
        if (binding == null) result.success(false)
        else perform(result) { operation(it, binding) }
    }

    private fun start(args: Map<*, *>, result: MethodChannel.Result) {
        val media = (args["url"] as? String)?.let(::hlsHttps)
        val referer = (args["referer"] as? String)?.let(::hlsHttps)
        val id = args["id"] as? String
        val source = (args["source"] as? String)?.takeIf { it.isNotEmpty() && it.length <= 200 }
        val page = (args["video"] as? String)?.takeIf { stablePage(it) }
        val title = (args["title"] as? String)?.takeIf { it.length <= 300 }
        val quality = (args["quality"] as? String)?.takeIf { it.length <= 80 }
        val taskKey = (args["taskKey"] as? String)?.takeIf { it.isNotEmpty() && it.length <= 2048 }
        val resource = args["managedId"] as? String
        val headers = referer?.let { publicHeaders(args["headers"], it) }
        if (media == null || !media.path.endsWith(".m3u8", ignoreCase = true) ||
            id.isNullOrBlank() || id.length > 120 || source == null || page == null ||
            title == null || quality == null || taskKey == null || headers == null ||
            resource == null || resource != hlsHex(source, page, "hls", quality)) {
            result.success(HlsTransferFailure("invalidRequest").value())
            return
        }
        if (args["networkContext"] != null) {
            result.success(HlsTransferFailure("routeUnavailable").value())
            return
        }
        val rawProxy = args["androidProxy"]
        val proxy = androidVideoProxy(rawProxy)
        if (rawProxy != null && proxy == null) {
            result.success(HlsTransferFailure("routeUnavailable").value())
            return
        }
        if (active.size >= 3 || id in active || active.values.any { it.binding.resourceId == resource }) {
            result.success("busy")
            return
        }
        val wifi = args["wifiOnly"] == true
        val open = androidVideoDownloadConnection(app.getSystemService(ConnectivityManager::class.java), wifi, proxy) {
            throw HlsTransferFailure("waitingWifi")
        } ?: run {
            result.success(HlsTransferFailure("waitingWifi").value())
            return
        }
        val scope = (args["recoveryScope"] as? String)?.takeIf { it.matches(Regex("[a-f0-9]{64}")) }
        val attempt = (args["attempt"] as? Int)?.takeIf { it > 0 }
        val metadata = buildMap<String, Any> {
            put("source", source)
            put("url", page)
            put("title", title)
            put("quality", quality)
            put("taskKey", taskKey)
            put("showTask", true)
            put("at", System.currentTimeMillis())
            put("wifiOnly", wifi)
            if (scope != null && attempt != null) {
                put("recoveryScope", scope)
                put("attempt", attempt)
            }
            (args["cover"] as? String)?.takeIf { raw ->
                hlsHttps(raw)?.rawQuery == null && hlsHttps(raw) != null
            }?.let { put("cover", it) }
            (args["sourceDuration"] as? String)?.takeIf { it.length <= 300 && it.isNotBlank() }
                ?.let { put("sourceDuration", it) }
        }
        val expected = args["expectedGeneration"] as? String ?: ""
        if (expected.isNotEmpty() &&
            HlsBinding.parse(mapOf("assetId" to expected, "generation" to expected), false) == null) {
            result.success(HlsTransferFailure("invalidRequest").value())
            return
        }
        val asset = HlsBinding(resource, hlsToken(), hlsToken())
        val job = Job(id, asset, metadata, expected, scope != null && attempt != null, result, bindingOwner)
        active[id] = job
        if (job.recoverable) liveReceipts.add(asset.assetId)
        job.lease = VideoDownloadForegroundService.forProcess(app).acquire(
            ready = {
                if (active[id] === job && job.failure == null) {
                    job.started = true
                    run(job, media, headers, open)
                }
            },
            interrupted = { reason -> if (active[id] === job) cancel(job, reason ?: "cancelled") },
        )
        if (job.lease?.launch() != true) {
            finish(job, HlsTransferFailure("unavailable").value(), hasReceipt = false)
        }
    }

    private fun stablePage(raw: String): Boolean {
        val uri = hlsHttps(raw) ?: return false
        if (raw.length > 4096) return false
        val query = uri.rawQuery ?: return false
        if (uri.rawPath == "/watch") return query.matches(Regex("v=[0-9]+"))
        return uri.rawPath.matches(Regex("/(?:voddetail/[1-9][0-9]{0,14}\\.html|index\\.php/vod/detail/id/[1-9][0-9]{0,14}\\.html|vod/[1-9][0-9]{0,14}/|anime/[a-f0-9]{16,64}\\.html|videos/[A-Za-z0-9_-]{1,64})")) &&
            query.matches(Regex("line=[^&]{1,600}&episode=[^&]{1,1200}"))
    }

    private fun publicHeaders(raw: Any?, referer: URI): Map<String, String>? {
        val values = if (raw == null) emptyMap<Any, Any>() else raw as? Map<*, *> ?: return null
        if (values.size > 3) return null
        val result = mutableMapOf("Referer" to referer.toASCIIString())
        for ((key, rawValue) in values) {
            val name = when ((key as? String)?.lowercase()) {
                "referer" -> "Referer"
                "origin" -> "Origin"
                "user-agent" -> "User-Agent"
                else -> return null
            }
            val value = rawValue as? String ?: return null
            if (value.length > 2000 || value.any { it.code < 32 || it.code == 127 }) return null
            if (name != "User-Agent") {
                val target = hlsHttps(value) ?: return null
                if (!target.host.equals(referer.host, ignoreCase = true)) return null
                if (name == "Origin") {
                    if (target.rawQuery != null || target.rawPath !in setOf("", "/")) return null
                } else if (target.rawQuery != null && !stablePage(value)) return null
            }
            result[name] = value
        }
        return result
    }

    private fun run(job: Job, media: URI, headers: Map<String, String>, open: (URI) -> HttpURLConnection) {
        storage.execute {
            try {
                val store = store()
                check((store.current(job.binding.resourceId)?.binding?.generation ?: "") == job.expected)
                val directory = store.createPackage(job.binding)
                writers.execute { runWriter(job, directory, media, headers, open) }
            } catch (_: Exception) {
                main.post { finish(job, HlsTransferFailure("storage").value(), hasReceipt = false) }
            }
        }
    }

    private fun runWriter(job: Job, directory: File, media: URI, headers: Map<String, String>, open: (URI) -> HttpURLConnection) {
        val transfer = AndroidHlsTransfer(directory, media, headers, open) { bytes, loaded, total ->
            main.post {
                if (active[job.id] === job && job.failure == null) {
                    job.lease?.progress(bytes, -1)
                    if (!closed) channel.invokeMethod("progress", buildMap<String, Any> {
                        put("id", job.id)
                        put("received", bytes)
                        put("receivedSource", "package")
                        put("saving", false)
                        if (loaded != null && total != null) {
                            put("loadedTimeMs", loaded)
                            put("totalTimeMs", total)
                        }
                    })
                }
            }
        }
        job.transfer = transfer
        try {
            job.failure?.let { throw HlsTransferFailure(it) }
            val duration = transfer.run()
            val bytes = storeBytes(directory)
            storage.execute {
                try {
                    job.failure?.let { throw HlsTransferFailure(it) }
                    val asset = HlsAsset(job.binding, job.metadata, job.expected, bytes, duration, false, job.recoverable)
                    store().stage(asset)
                    main.post {
                        val cancelled = job.failure
                        if (cancelled != null) {
                            storage.execute {
                                try {
                                    store().discard(job.binding)
                                } catch (_: Exception) {
                                    // Next reconciliation checks the persisted attempt.
                                }
                                main.post { finish(job, HlsTransferFailure(cancelled).value(), hasReceipt = false) }
                            }
                        } else {
                            finish(job, asset.publicRow(false) + ("status" to "staged"), hasReceipt = job.recoverable)
                        }
                    }
                } catch (error: Exception) {
                    abort(job, directory, error)
                }
            }
        } catch (error: Exception) {
            abort(job, directory, error)
        }
    }

    private fun storeBytes(directory: File): Long {
        // Seal only the completed package on the transfer thread.
        return processStore!!.seal(directory)
    }

    private fun abort(job: Job, directory: File, error: Exception) {
        directory.deleteRecursively()
        val reason = job.failure ?: (error as? HlsTransferFailure)?.reason
        val value = if (reason == "cancelled") "cancelled"
            else if (error is HlsTransferFailure && job.failure == null) error.value()
            else HlsTransferFailure(reason ?: "storage").value()
        main.post { finish(job, value, hasReceipt = false) }
    }

    private fun cancel(job: Job, reason: String) {
        if (job.failure == null) job.failure = reason
        // Disconnect off the main queue. This call can wait for the network.
        val transfer = job.transfer
        if (transfer != null) Thread { transfer.cancel() }.start()
        if (!job.started) finish(job, if (reason == "cancelled") reason else HlsTransferFailure(reason).value(), false)
    }

    private fun finish(job: Job, value: Any, hasReceipt: Boolean) {
        if (active[job.id] !== job) return
        active.remove(job.id)
        job.lease?.close()
        if (!hasReceipt || closed) liveReceipts.remove(job.binding.assetId)
        if (!closed) job.result.success(value)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        closed = true
        active.values.filter { it.owner === bindingOwner }.forEach { cancel(it, "cancelled") }
        storage.execute {
            processStore?.releaseOwner(bindingOwner)
        }
    }
}
