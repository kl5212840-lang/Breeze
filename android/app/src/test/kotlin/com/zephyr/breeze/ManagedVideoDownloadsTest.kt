package com.zephyr.breeze

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executor

class ManagedVideoDownloadsTest {
    @get:Rule val temp = TemporaryFolder()

    private class Queue : Executor {
        private val work = ArrayDeque<Runnable>()
        override fun execute(command: Runnable) { work.add(command) }
        fun drain() { while (work.isNotEmpty()) work.removeFirst().run() }
    }

    private class Receiver(id: String) {
        val results = mutableListOf<Any?>()
        val progress = mutableListOf<Map<String, Any>>()
        val subscription = ManagedVideoSubscriber(Any(), id, { results.add(it) }, { progress.add(it) })
    }

    private class ForegroundHost : VideoDownloadForeground.Host {
        val updates = mutableListOf<VideoDownloadForeground.Notice>()
        var stops = 0
        override fun update(notice: VideoDownloadForeground.Notice) { updates.add(notice) }
        override fun stop() { stops++ }
    }

    private val identity = ManagedVideoAttempt("a".repeat(64), "b".repeat(64), "d".repeat(64))
    private val media = URI("https://video.test/signed.mp4?token=temporary")
    private val referer = URI("https://source.test/videos/fixture")
    private val bytes = ByteArray(4096).apply { "ftyp".encodeToByteArray().copyInto(this, 4) }

    private class Response(
        target: URI,
        private val code: Int = 200,
        private val body: ByteArray = byteArrayOf(),
        private val mime: String = "video/mp4",
        private val length: Long = body.size.toLong(),
        private val location: String? = null,
    ) : HttpURLConnection(target.toURL()) {
        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy() = false
        override fun getResponseCode() = code
        override fun getInputStream() = ByteArrayInputStream(body)
        override fun getContentType() = mime
        override fun getContentLengthLong() = length
        override fun getHeaderField(name: String?) = if (name == "Location") location else null
    }

    @Test fun liveAttemptSurvivesDetachAndRebindsProgressAndCommit() {
        val root = temp.newFolder()
        val worker = Queue()
        val owner = Queue()
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 1000L })
        val old = Receiver("old-engine-id")
        val replacement = Receiver("new-engine-id")
        val competing = Receiver("competing-id")
        var connections = 0
        downloads.start(identity, old.subscription, media, referer, emptyMap()) {
            connections++
            Response(it, body = bytes)
        }
        assertEquals("busy", downloads.status(identity))
        downloads.detach(old.subscription.owner)
        assertEquals("active", downloads.status(identity))
        assertFalse(downloads.attach(identity.copy(resourceId = "c".repeat(64)), replacement.subscription))
        assertTrue(downloads.attach(identity, replacement.subscription))
        downloads.cancel(old.subscription.owner, old.subscription.id, null, null)
        assertTrue(downloads.attach(identity, competing.subscription))
        assertEquals(listOf("busy"), competing.results)
        worker.drain()
        owner.drain()

        assertEquals(1, connections)
        assertTrue(old.results.isEmpty())
        assertTrue(replacement.progress.isNotEmpty())
        assertTrue(replacement.progress.all { it["id"] == "new-engine-id" })
        val result = replacement.results.single() as Map<*, *>
        assertEquals("staged", result["status"])
        assertEquals(identity.resourceId, result["resourceId"])
        val stage = File(root, "breeze-video-staging/${result["stageId"]}.mp4")
        assertArrayEquals(bytes, stage.readBytes())
        assertTrue(stage.delete())
        assertNull(downloads.status(identity))
    }

    @Test fun stagedReceiptWaitsForMatchingEngineAndIgnoresLaterAttempt() {
        val root = temp.newFolder()
        val worker = Queue()
        val owner = Queue()
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 2000L })
        val old = Receiver("old")
        downloads.start(identity, old.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        worker.drain()
        downloads.detach(old.subscription.owner)
        owner.drain()

        assertEquals("settled", downloads.status(identity))
        assertNull(downloads.status(identity.copy(key = "c".repeat(64))))
        assertTrue(old.results.isEmpty())
        val attached = Receiver("new")
        assertTrue(downloads.attach(identity, attached.subscription))
        assertEquals("staged", (attached.results.single() as Map<*, *>)["status"])
        assertEquals("busy", downloads.status(identity))
    }

    @Test fun cancellationAfterWriteBeforeOwnerCommitDiscardsStagedBytes() {
        val root = temp.newFolder()
        val worker = Queue()
        val owner = Queue()
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 3000L })
        val old = Receiver("old")
        downloads.start(identity, old.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        downloads.detach(old.subscription.owner)
        worker.drain()
        downloads.cancel(Any(), null, "c".repeat(64), identity.scope)
        assertEquals("active", downloads.status(identity))
        downloads.cancel(Any(), null, identity.key, "e".repeat(64))
        assertEquals("active", downloads.status(identity))
        downloads.cancel(Any(), null, identity.key, identity.scope)
        owner.drain()

        assertTrue(File(root, "breeze-video-staging").list().orEmpty().isEmpty())
        assertTrue(old.results.isEmpty())
        assertNull(downloads.status(identity))
        val attached = Receiver("new")
        assertTrue(downloads.attach(identity, attached.subscription))
        assertEquals(listOf("cancelled"), attached.results)
    }

    @Test fun unfinishedPartDoesNotBecomeAReceiptAfterProcessRestart() {
        val root = temp.newFolder()
        val staging = File(root, "breeze-video-staging").apply { mkdir() }
        val orphan = File(staging, "breeze-managed-interrupted.part").apply { writeBytes(bytes) }
        val oldStage = File(staging, "${"a".repeat(32)}.mp4").apply {
            writeBytes(bytes)
            setLastModified(System.currentTimeMillis() - 2 * 24 * 60 * 60 * 1000L)
        }
        val other = File(staging, "existing.mp4").apply { writeBytes(bytes) }
        val worker = Queue()
        val downloads = ManagedVideoDownloads(root, worker, { it() }, { 4000L })
        worker.drain()

        assertFalse(orphan.exists())
        assertFalse(oldStage.exists())
        assertTrue(other.exists())
        assertNull(downloads.status(identity))
    }

    @Test fun onlyUnclaimedExpiredReceiptDeletesItsStage() {
        val root = temp.newFolder()
        val worker = Queue()
        var now = 5000L
        val downloads = ManagedVideoDownloads(root, worker, { it() }, { now })
        val old = Receiver("old")
        downloads.start(identity, old.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        worker.drain()
        val result = old.results.single() as Map<*, *>
        val stage = File(root, "breeze-video-staging/${result["stageId"]}.mp4")
        now += 11 * 60 * 1000
        assertEquals("busy", downloads.status(identity))
        assertTrue(stage.exists())
        downloads.detach(old.subscription.owner)
        assertNull(downloads.status(identity))
        assertFalse(stage.exists())
    }

    @Test fun changedAccountDiscardsDetachedStageAndCannotReuseIt() {
        val root = temp.newFolder()
        val worker = Queue()
        val owner = Queue()
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 5000L })
        val old = Receiver("old")
        downloads.start(identity, old.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        downloads.detach(old.subscription.owner)
        worker.drain()
        owner.drain()
        assertEquals("settled", downloads.status(identity))

        val changed = identity.copy(scope = "e".repeat(64))
        assertNull(downloads.status(changed))
        assertFalse(downloads.attach(changed, Receiver("new").subscription))
        assertNull(downloads.status(identity))
        assertTrue(File(root, "breeze-video-staging").list().orEmpty().isEmpty())
    }

    @Test fun redirectDropsOriginHeadersAndRejectsIncompleteBytes() {
        val target = temp.newFile()
        var second: Response? = null
        val failure = runCatching {
            VideoMp4Transfer().download(target, media, referer,
                mapOf("Origin" to referer.resolve("/").toString(), "User-Agent" to "fixture"),
                { 5000L }, { uri ->
                    if (uri.host == media.host) Response(uri, 302, location = "https://cdn.test/media")
                    else Response(uri, body = bytes, length = bytes.size + 1L).also { second = it }
                }, {})
        }.exceptionOrNull() as VideoMp4Failure
        assertEquals("incomplete", failure.reason)
        assertNull(second?.getRequestProperty("Origin"))
        assertNull(second?.getRequestProperty("Referer"))
        assertEquals("fixture", second?.getRequestProperty("User-Agent"))
    }

    @Test fun httpFailuresExposeSafeReasonsAndStatusOnly() {
        val failure = runCatching {
            VideoMp4Transfer().download(temp.newFile(), media, referer, emptyMap(),
                { 6000L }, { Response(it, code = 403) }, {})
        }.exceptionOrNull() as VideoMp4Failure
        assertEquals(mapOf("status" to "failed", "reason" to "httpForbidden", "httpStatus" to 403), failure.result())
    }

    @Test fun videoWaitsForPromotionAndFinishesAfterEngineDetaches() {
        val root = temp.newFolder()
        val worker = Queue()
        val owner = Queue()
        var launches = 0
        val foreground = VideoDownloadForeground { launches++; true }
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 1000L }, foreground)
        val engine = Receiver("flutter")
        var connections = 0
        downloads.start(identity, engine.subscription, media, referer, emptyMap()) {
            connections++
            Response(it, body = bytes)
        }
        worker.drain()
        assertEquals(1, launches)
        assertEquals(0, connections)

        downloads.detach(engine.subscription.owner)
        val host = ForegroundHost()
        val token = foreground.notice!!.token
        assertTrue(foreground.bind(host, token))
        assertTrue(foreground.bind(host, token))
        worker.drain()
        owner.drain()

        assertEquals(1, connections)
        assertTrue(engine.results.isEmpty())
        assertTrue(host.updates.any { it.received == bytes.size.toLong() })
        assertEquals(1, host.stops)
        assertNull(foreground.notice)
        assertEquals("settled", downloads.status(identity))
    }

    @Test fun deniedPromotionLeavesRetryableTaskAndNeverStartsWriter() {
        val worker = Queue()
        val foreground = VideoDownloadForeground { false }
        val downloads = ManagedVideoDownloads(temp.newFolder(), worker, { it() }, { 2000L }, foreground)
        val engine = Receiver("flutter")
        downloads.start(identity, engine.subscription, media, referer, emptyMap()) {
            fail("A denied foreground service must not open the network")
            Response(it)
        }
        worker.drain()
        assertEquals(listOf("unavailable"), engine.results)
        assertFalse(downloads.busy)
        assertNull(foreground.notice)
    }

    @Test fun staleNotificationOrServiceCannotStopANewerVideoTransfer() {
        val worker = Queue()
        val owner = Queue()
        val foreground = VideoDownloadForeground { true }
        val downloads = ManagedVideoDownloads(temp.newFolder(), worker, { owner.execute(it) }, { 3000L }, foreground)
        val old = Receiver("old")
        downloads.start(identity, old.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        val oldToken = foreground.notice!!.token
        val oldHost = ForegroundHost()
        foreground.cancel(oldToken)
        assertEquals(listOf("cancelled"), old.results)
        assertFalse(foreground.bind(oldHost, oldToken))

        val next = identity.copy(key = "f".repeat(64))
        val engine = Receiver("new")
        downloads.start(next, engine.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        val nextToken = foreground.notice!!.token
        val nextHost = ForegroundHost()
        assertTrue(foreground.bind(nextHost, nextToken))
        foreground.cancel(oldToken)
        foreground.interrupted(oldHost, "timeout")
        assertTrue(downloads.busy)
        assertTrue(engine.results.isEmpty())
        assertEquals(0, nextHost.stops)

        worker.drain()
        foreground.cancel(nextToken)
        owner.drain()
        assertEquals(listOf("cancelled"), engine.results)
        assertEquals(1, nextHost.stops)
        assertFalse(downloads.busy)
        assertNull(downloads.status(next))
    }

    @Test fun platformTimeoutInterruptsOnlyItsOwnWriterWithoutPublishingAStage() {
        val worker = Queue()
        val owner = Queue()
        val foreground = VideoDownloadForeground { true }
        val root = temp.newFolder()
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 4000L }, foreground)
        val engine = Receiver("flutter")
        downloads.start(identity, engine.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        val host = ForegroundHost()
        assertTrue(foreground.bind(host, foreground.notice!!.token))
        worker.drain()
        foreground.interrupted(host, "timeout")
        owner.drain()
        assertEquals(mapOf("status" to "failed", "reason" to "timeout"), engine.results.single())
        assertNull(foreground.notice)
        assertNull(downloads.status(identity))
        assertTrue(File(root, "breeze-video-staging").list().orEmpty().isEmpty())
    }

    @Test fun foregroundStartsThreeDifferentWritersAndCancelsOnlyTheSelectedOne() {
        val root = temp.newFolder()
        val worker = Queue()
        val owner = Queue()
        var launches = 0
        val foreground = VideoDownloadForeground { launches++; true }
        val downloads = ManagedVideoDownloads(root, worker, { owner.execute(it) }, { 4000L }, foreground)
        val tasks = listOf('a', 'c', 'e').map {
            identity.copy(key = it.toString().repeat(64), resourceId = it.toString().repeat(64))
        }
        val receivers = tasks.mapIndexed { index, _ -> Receiver("engine-$index") }
        var connections = 0
        for ((task, receiver) in tasks.zip(receivers)) {
            downloads.start(task, receiver.subscription, media, referer, emptyMap()) {
                connections++
                Response(it, body = bytes)
            }
        }
        assertEquals(1, launches)
        val fourth = Receiver("fourth")
        downloads.start(identity, fourth.subscription, media, referer, emptyMap()) { Response(it, body = bytes) }
        assertEquals(listOf("busy"), fourth.results)
        val host = ForegroundHost()
        val token = foreground.notice!!.token
        assertTrue(foreground.bind(host, token))
        foreground.cancel(token)
        assertTrue(foreground.notice!!.token != token)
        assertEquals(0, host.stops)

        worker.drain()
        owner.drain()

        assertEquals(2, connections)
        assertEquals(listOf("cancelled"), receivers.first().results)
        for (receiver in receivers.drop(1)) {
            assertEquals("staged", (receiver.results.single() as Map<*, *>)["status"])
        }
        assertEquals(1, host.stops)
        assertFalse(downloads.busy)
    }
}
