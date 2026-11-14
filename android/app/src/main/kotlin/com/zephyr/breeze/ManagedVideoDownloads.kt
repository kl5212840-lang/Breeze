package com.zephyr.breeze

import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

internal data class ManagedVideoAttempt(val key: String, val resourceId: String, val scope: String) {
    fun sameTask(other: ManagedVideoAttempt): Boolean = key == other.key && resourceId == other.resourceId

    companion object {
        private val hash = Regex("^[a-f0-9]{64}$")

        fun parse(key: Any?, resourceId: Any?, scope: Any?): ManagedVideoAttempt? =
            if (key is String && resourceId is String && scope is String &&
                hash.matches(key) && hash.matches(resourceId) && hash.matches(scope)) {
                ManagedVideoAttempt(key, resourceId, scope)
            } else null
    }
}

internal class ManagedVideoSubscriber(
    val owner: Any,
    val id: String,
    val result: (Any?) -> Unit,
    val progress: (Map<String, Any>) -> Unit,
)

/** App process owns the writer. The owner queue serializes subscription and completion. */
internal class ManagedVideoDownloads(
    cacheDir: File,
    private val worker: Executor,
    private val post: (() -> Unit) -> Unit,
    private val clock: () -> Long,
    private val foreground: VideoDownloadForeground? = null,
) {
    private val root = File(cacheDir.canonicalFile, "breeze-video-staging")
    private var active: Job? = null
    private val settled = linkedMapOf<ManagedVideoAttempt, Receipt>()

    private class Job(val identity: ManagedVideoAttempt, var subscriber: ManagedVideoSubscriber?) {
        val transfer = VideoMp4Transfer()
        var foreground: VideoDownloadForeground.Lease? = null
        var lastProgress = Long.MIN_VALUE
    }

    private class Receipt(val result: Any, val at: Long, val stage: File?, var owner: Any?)

    init {
        worker.execute {
            if (root.canonicalPath == root.path) {
                val old = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
                val stageName = Regex("^[a-f0-9]{32}\\.mp4$")
                root.listFiles()?.filter {
                    it.name.startsWith("breeze-managed-") && it.name.endsWith(".part") ||
                        stageName.matches(it.name) && it.lastModified() in 1..old
                }?.forEach { it.delete() }
            }
        }
    }

    val busy: Boolean get() = active != null

    private fun receipt(identity: ManagedVideoAttempt): Receipt? {
        val now = clock()
        settled.entries.removeAll { (_, receipt) ->
            if (receipt.stage?.isFile == false) return@removeAll true
            if (receipt.owner != null || now - receipt.at <= 10 * 60 * 1000) return@removeAll false
            receipt.stage?.delete()
            true
        }
        return settled[identity]
    }

    fun status(identity: ManagedVideoAttempt): String? {
        discardDetachedScopeChange(identity)
        val job = active
        if (job != null && job.identity.sameTask(identity)) {
            return if (job.identity == identity && job.subscriber == null) "active" else "busy"
        }
        if (settled.any { (stored, receipt) -> stored.sameTask(identity) && receipt.stage != null &&
                receipt.owner != null && receipt.stage.isFile }) return "busy"
        val prior = receipt(identity) ?: return null
        if (prior.stage == null) return null
        return if (prior.owner == null) "settled" else "busy"
    }

    fun attach(identity: ManagedVideoAttempt, subscriber: ManagedVideoSubscriber): Boolean {
        discardDetachedScopeChange(identity)
        val job = active?.takeIf { it.identity == identity }
        if (job != null) {
            if (job.subscriber != null) {
                subscriber.result("busy")
            } else {
                job.subscriber = subscriber
                progress(job, force = true)
            }
            return true
        }
        val prior = receipt(identity) ?: return false
        if (prior.owner != null) {
            subscriber.result("busy")
        } else {
            prior.owner = subscriber.owner
            subscriber.result(prior.result)
        }
        return true
    }

    private fun discardDetachedScopeChange(identity: ManagedVideoAttempt) {
        val job = active
        if (job != null && job.subscriber == null && job.identity.sameTask(identity) &&
            job.identity.scope != identity.scope) {
            job.transfer.cancel()
            finish(job, "cancelled")
        }
        settled.entries.removeAll { (stored, receipt) ->
            if (receipt.owner != null || !stored.sameTask(identity) || stored.scope == identity.scope) {
                return@removeAll false
            }
            receipt.stage?.delete()
            true
        }
    }

    fun start(
        identity: ManagedVideoAttempt,
        subscriber: ManagedVideoSubscriber,
        media: URI,
        referer: URI,
        headers: Map<String, String>,
        open: (URI) -> HttpURLConnection,
    ) {
        if (attach(identity, subscriber)) return
        if (busy) {
            subscriber.result("busy")
            return
        }
        val job = Job(identity, subscriber)
        active = job
        progress(job, force = true)
        fun beginTransfer() {
            if (active !== job) return
            try {
                worker.execute { run(job, media, referer, headers, open) }
            } catch (_: RejectedExecutionException) {
                finish(job, "unavailable")
            }
        }
        if (foreground == null) {
            beginTransfer()
            return
        }
        job.foreground = foreground.acquire(::beginTransfer) { reason ->
            if (active === job) {
                job.transfer.cancel()
                finish(job, reason?.let { VideoMp4Failure(it).result() } ?: "cancelled")
            }
        }
        if (job.foreground?.launch() != true) finish(job, "unavailable")
    }

    private fun run(
        job: Job,
        media: URI,
        referer: URI,
        headers: Map<String, String>,
        open: (URI) -> HttpURLConnection,
    ) {
        var part: File? = null
        var stage: File? = null
        try {
            if (job.transfer.cancelled) return
            val temp = try {
                check(root.canonicalPath == root.path && (root.mkdirs() || root.isDirectory))
                File.createTempFile("breeze-managed-", ".part", root)
            } catch (_: Exception) {
                throw VideoMp4Failure("storage")
            }
            part = temp
            job.transfer.download(temp, media, referer, headers, clock, open) {
                val now = clock()
                if (job.lastProgress == Long.MIN_VALUE || now - job.lastProgress >= 150) {
                    job.lastProgress = now
                    post { progress(job) }
                }
            }
            if (job.transfer.cancelled) return
            val stageId = UUID.randomUUID().toString().replace("-", "")
            val completed = File(root, "$stageId.mp4")
            stage = completed
            try {
                Files.move(temp.toPath(), completed.toPath(), StandardCopyOption.ATOMIC_MOVE)
            } catch (_: Exception) {
                throw VideoMp4Failure("storage")
            }
            post {
                if (active !== job) {
                    completed.delete()
                } else {
                    progress(job, saving = true, force = true)
                    finish(job, mapOf("status" to "staged", "resourceId" to job.identity.resourceId,
                        "stageId" to stageId, "bytes" to job.transfer.received), completed)
                }
            }
            stage = null
        } catch (error: Exception) {
            post {
                finish(job, when {
                    job.transfer.cancelled -> "cancelled"
                    error is VideoMp4Failure -> error.result()
                    else -> "failed"
                })
            }
        } finally {
            part?.delete()
            stage?.delete()
        }
    }

    private fun progress(job: Job, saving: Boolean = false, force: Boolean = false) {
        if (active !== job || job.transfer.cancelled || !force && job.transfer.received == 0L) return
        job.foreground?.progress(job.transfer.received, job.transfer.total)
        val receiver = job.subscriber ?: return
        receiver.progress(mapOf("id" to receiver.id, "received" to job.transfer.received,
            "total" to job.transfer.total, "saving" to saving))
    }

    private fun finish(job: Job, status: Any, stage: File? = null) {
        if (active !== job) return
        active = null
        job.foreground?.close()
        job.foreground = null
        val receiver = job.subscriber
        settled[job.identity] = Receipt(status, clock(), stage, receiver?.owner)
        while (settled.size > 8) {
            val evicted = settled.remove(settled.keys.first())
            if (evicted?.owner == null) evicted?.stage?.delete()
        }
        job.subscriber = null
        receiver?.result?.invoke(status)
    }

    fun detach(owner: Any) {
        val job = active
        if (job?.subscriber?.owner === owner) job.subscriber = null
        settled.values.filter { it.owner === owner }.forEach { it.owner = null }
    }

    fun cancel(owner: Any, id: Any?, key: Any?, scope: Any?) {
        val job = active ?: return
        val receiver = job.subscriber
        if (key != null) {
            if (job.identity.key != key || job.identity.scope != scope) return
        } else if (receiver == null || receiver.owner !== owner || receiver.id != id) return
        job.transfer.cancel()
        finish(job, "cancelled")
    }
}
