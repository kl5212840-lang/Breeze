package com.zephyr.breeze

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.effect.Presentation
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.inspector.frame.FrameExtractor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InterruptedIOException
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/** Decodes scrub thumbnails in a separate, silent Media3 session. */
@OptIn(markerClass = [UnstableApi::class])
internal class AndroidVideoSeekPreview(context: Context, messenger: BinaryMessenger) {
    private companion object {
        // Media3's extractor queue is process-wide, including across engine
        // recreation. Accessed only from the channel's main thread.
        var decoderBusy = false
    }

    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, "breeze.video.seek-preview")
    private val main = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { main.post(it) }
    private val encoder = Executors.newSingleThreadExecutor()
    private var foreground = true
    private var closed = false
    private var reader: Reader? = null
    private var active: Work? = null
    private var pending: Request? = null
    private val releaseIdleReader = Runnable { if (active == null) closeReader() }

    init {
        channel.setMethodCallHandler(::handle)
    }

    private data class Source(
        val owner: Long,
        val uri: Uri,
        val headers: Map<String, String>,
        val streaming: Boolean,
        val wide: Boolean,
    )

    private data class Request(
        val source: Source,
        val id: Long,
        val milliseconds: Long,
        val result: MethodChannel.Result,
    )

    private class Reader(val source: Source, val gate: ReadGate, val extractor: FrameExtractor)

    private class Work(val request: Request, val reader: Reader) {
        var cancelled = false
        var deadline: Runnable? = null
    }

    private class ReadGate {
        @Volatile var until = 0L

        fun check() {
            if (SystemClock.elapsedRealtime() >= until) {
                throw InterruptedIOException("Preview read ended")
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> result.success(null)
            "frame" -> {
                val request = if (foreground && !closed) parse(call, result) else null
                if (request == null) result.success(null) else enqueue(request)
            }
            "cancel" -> {
                val id = (call.arguments as? Number)?.toLong()
                discardPending { it.id == id }
                active?.takeIf { it.request.id == id }?.let(::abort)
                result.success(null)
            }
            "close" -> {
                val owner = (call.arguments as? Number)?.toLong()
                discardPending { it.source.owner == owner }
                active?.takeIf { it.request.source.owner == owner }?.let(::abort)
                if (active == null && reader?.source?.owner == owner) closeReader()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun parse(call: MethodCall, result: MethodChannel.Result): Request? {
        val uri = call.argument<String>("url")?.let(Uri::parse) ?: return null
        when (uri.scheme) {
            "http", "https" -> if (uri.host.isNullOrEmpty()) return null
            "file" -> if (uri.path.isNullOrEmpty()) return null
            else -> return null
        }
        val owner = call.argument<Number>("owner")?.toLong() ?: return null
        val id = call.argument<Number>("id")?.toLong() ?: return null
        val position = call.argument<Number>("milliseconds")?.toLong() ?: return null
        if (position < 0) return null
        val source = Source(
            owner,
            uri,
            call.argument<Map<String, String>>("headers")?.toMap().orEmpty(),
            call.argument<Boolean>("streaming") == true,
            call.argument<Boolean>("wideThumbnail") == true,
        )
        return Request(source, id, position, result)
    }

    private fun enqueue(request: Request) {
        val work = active
        if (work == null) {
            start(request)
            return
        }
        // Media3 serializes extraction internally. Hold at most the latest
        // pending request here, and never submit until the decoder settles.
        discardPending { true }
        pending = request
        if (work.request.source != request.source) abort(work)
    }

    private fun createReader(source: Source): Reader {
        val gate = ReadGate()
        val http = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(2200)
            .setReadTimeoutMs(2200)
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(source.headers.entries.firstOrNull { it.key.equals("User-Agent", true) }?.value)
            .setDefaultRequestProperties(source.headers)
        val upstream = DefaultDataSource.Factory(context, http)
        val mediaFactory = DefaultMediaSourceFactory(context)
            .setDataSourceFactory {
                val delegate = upstream.createDataSource()
                object : DataSource by delegate {
                    override fun open(dataSpec: DataSpec): Long {
                        gate.check()
                        return delegate.open(dataSpec)
                    }

                    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                        gate.check()
                        return delegate.read(buffer, offset, length)
                    }
                }
            }
            .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy(0))
        val item = MediaItem.Builder().setUri(source.uri).apply {
            if (source.streaming) setMimeType(MimeTypes.APPLICATION_M3U8)
        }.build()
        val extractor = FrameExtractor.Builder(context, item)
            .setMediaSourceFactory(mediaFactory)
            .setSeekParameters(SeekParameters.CLOSEST_SYNC)
            .setEffects(listOf(Presentation.createForHeight(if (source.wide) 216 else 144)))
            .build()
        return Reader(source, gate, extractor)
    }

    private fun start(request: Request) {
        if (decoderBusy) {
            request.result.success(null)
            return
        }
        decoderBusy = true
        main.removeCallbacks(releaseIdleReader)
        try {
            if (reader?.source != request.source) {
                closeReader()
                reader = createReader(request.source)
            }
            val current = checkNotNull(reader)
            val work = Work(request, current)
            active = work
            val local = request.source.uri.scheme == "file"
            current.gate.until = SystemClock.elapsedRealtime() + if (local) 2200L else 5200L
            work.deadline = Runnable { abort(work) }.also {
                main.postDelayed(it, if (local) 2400L else 6000L)
            }
            val frame = current.extractor.getFrame(request.milliseconds)
            frame.addListener({
                if (work.cancelled) {
                    finish(work, null)
                } else {
                    val bitmap = runCatching { frame.get().bitmap }.getOrNull()
                    if (bitmap == null) {
                        finish(work, null)
                    } else {
                        encoder.execute {
                            val bytes = runCatching {
                                ByteArrayOutputStream().use { output ->
                                    if (bitmap.compress(Bitmap.CompressFormat.JPEG, 76, output)) {
                                        output.toByteArray()
                                    } else null
                                }
                            }.getOrNull()
                            main.post { finish(work, bytes) }
                        }
                    }
                }
            }, mainExecutor)
        } catch (_: RuntimeException) {
            val work = active
            if (work != null) {
                finish(work, null)
            } else {
                decoderBusy = false
                closeReader()
                request.result.success(null)
            }
        }
    }

    private fun abort(work: Work) {
        if (active !== work || work.cancelled) return
        work.cancelled = true
        work.reader.gate.until = 0L
        work.deadline?.let(main::removeCallbacks)
        work.request.result.success(null)
        // A cancelled Media3 Future can report completion before its running
        // work stops. The terminal listener alone releases the active slot.
    }

    private fun finish(work: Work, bytes: ByteArray?) {
        if (active !== work) return
        active = null
        decoderBusy = false
        work.deadline?.let(main::removeCallbacks)
        if (work.cancelled || bytes == null) {
            closeReader()
        } else {
            // Preserve the decoder across neighboring targets. Release it
            // promptly when the drag stops, independent of the frame cache.
            work.reader.gate.until = minOf(work.reader.gate.until, SystemClock.elapsedRealtime() + 450L)
            main.postDelayed(releaseIdleReader, 1500L)
        }
        if (!work.cancelled) work.request.result.success(bytes)
        val next = pending
        pending = null
        if (next != null) start(next)
    }

    private fun discardPending(matches: (Request) -> Boolean) {
        val request = pending?.takeIf(matches) ?: return
        pending = null
        request.result.success(null)
    }

    private fun closeReader() {
        main.removeCallbacks(releaseIdleReader)
        val current = reader ?: return
        reader = null
        current.gate.until = 0L
        current.extractor.close()
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (value) return
        discardPending { true }
        val work = active
        if (work == null) closeReader() else abort(work)
    }

    fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        setForeground(false)
        encoder.shutdown()
    }
}
