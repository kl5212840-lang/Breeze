package com.zephyr.breeze

import android.os.SystemClock
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URI
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToLong

internal class HlsTransferFailure(val reason: String, val httpStatus: Int? = null) : IOException() {
    fun value(): Map<String, Any> = buildMap {
        put("status", if (reason == "unsupported") "unsupported" else "failed")
        put("reason", reason)
        httpStatus?.let { put("httpStatus", it) }
    }
}

private const val MAX_PLAYLIST_BYTES = 2 * 1024 * 1024
private const val MAX_MEDIA_BYTES = 256 * 1024 * 1024L
private const val MIN_FREE_BYTES = 32 * 1024 * 1024L
private const val MAX_PACKAGE_BYTES = 8L * 1024 * 1024 * 1024

/** Stores finite, unprotected HLS as a self-contained package for Media3's file source. */
internal class AndroidHlsTransfer(
    private val directory: File,
    private val original: URI,
    private val headers: Map<String, String>,
    private val open: (URI) -> HttpURLConnection,
    private val progress: (Long, Long?, Long?) -> Unit,
) {
    private val started = SystemClock.elapsedRealtime()
    private val connectionLock = Any()
    private var connection: HttpURLConnection? = null
    @Volatile private var stopped = false
    private var bytes = 0L
    private var nextFile = 0
    private var lastProgress = 0L
    private var captionDeadline: Long? = null
    private var captionBytes = 0

    fun cancel() {
        synchronized(connectionLock) {
            stopped = true
            connection
        }?.disconnect()
    }

    fun run(): Long {
        val (url, lines) = playlist(original)
        val master = HlsManifest.master(lines)
        if (master == null) return media(url, lines, "index.m3u8", reportTime = true)
        val (videoUrl, videoLines) = playlist(resolve(url, master.video))
        val hasExtraFiles = master.audio.any { it.uri != null } || master.subtitles.isNotEmpty()
        val duration = media(videoUrl, videoLines, "video.m3u8", reportTime = !hasExtraFiles)
        master.audio.forEachIndexed { index, track ->
            track.uri?.let { remote ->
                val (audioUrl, audioLines) = playlist(resolve(url, remote))
                media(audioUrl, audioLines, "audio-${index + 1}.m3u8", reportTime = false)
            }
        }
        downloadCaptions(url, master.subtitles, duration)
        write("index.m3u8", master.localPlaylist())
        return duration
    }

    private fun playlist(uri: URI): Pair<URI, List<String>> {
        val (url, text) = textResource(uri, limit = MAX_PLAYLIST_BYTES)
        return url to HlsManifest.read(text)
    }

    private fun textResource(uri: URI, range: HlsRange? = null, limit: Int): Pair<URI, String> =
        request(uri, range) { final, response ->
            val output = ByteArrayOutputStream()
            response.inputStream.use { input ->
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    checkActive()
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > limit) throw HlsTransferFailure("unsupported")
                    if (captionDeadline != null) {
                        captionBytes += count
                        if (captionBytes > 32 * 1024 * 1024) throw HlsTransferFailure("captionBudget")
                    }
                    output.write(buffer, 0, count)
                }
            }
            if (range != null && output.size().toLong() != range.length) throw HlsTransferFailure("incomplete")
            final to output.toString(Charsets.UTF_8.name())
        }

    private fun downloadCaptions(url: URI, tracks: List<HlsTrack>, duration: Long) {
        if (tracks.isEmpty()) return
        val sidecar = JSONArray()
        captionDeadline = SystemClock.elapsedRealtime() + 40_000
        try {
            for ((index, track) in tracks.withIndex()) {
                try {
                    val caption = subtitles(resolve(url, checkNotNull(track.uri)), duration)
                    val file = "subtitle-${index + 1}.vtt"
                    write(file, caption)
                    sidecar.put(JSONObject().put("file", file).put("label", track.label))
                } catch (error: HlsTransferFailure) {
                    if (error.reason == "captionBudget") break
                    // Unsupported or unavailable optional captions do not
                    // invalidate the already complete video and audio.
                    if (error.reason !in OPTIONAL_CAPTION_ERRORS) throw error
                }
            }
        } finally {
            captionDeadline = null
        }
        if (sidecar.length() > 0) write("captions.json", sidecar.toString())
    }

    private fun subtitles(uri: URI, durationMs: Long): String {
        val (url, lines) = playlist(uri)
        val manifest = HlsManifest.media(lines)
        if (manifest.entries.any {
                it.line.startsWith("#EXT-X-MAP") || it.line.startsWith("#EXT-X-DISCONTINUITY") ||
                    it.line.startsWith("#EXT-X-KEY")
            }) throw HlsTransferFailure("unsupported")
        val parts = manifest.entries.mapNotNull { it.part }
        if (parts.size > 4096) throw HlsTransferFailure("unsupported")
        val captions = HlsWebVtt(durationMs)
        var segmentStart = 0L
        for (part in parts) {
            val (_, text) = textResource(resolve(url, part.uri), part.range, HlsWebVtt.MAX_SEGMENT_BYTES)
            captions.add(text, segmentStart, segmentStart + part.durationMs)
            segmentStart += part.durationMs
        }
        return captions.file()
    }

    private fun media(uri: URI, lines: List<String>, name: String, reportTime: Boolean): Long {
        val manifest = HlsManifest.media(lines)
        val files = mutableMapOf<HlsPart, String>()
        var elapsed = 0L
        val content = buildString {
            for (entry in manifest.entries) {
                val part = entry.part
                if (part == null) {
                    appendLine(entry.line)
                    continue
                }
                val file = files.getOrPut(part) {
                    val local = "part-${++nextFile}.${part.extension}"
                    transfer(resolve(uri, part.uri), part.range, local, part.extension == "key")
                    local
                }
                appendLine(entry.line.replace("@FILE@", file))
                if (reportTime && part.durationMs > 0) {
                    elapsed += part.durationMs
                    emit(elapsed, manifest.durationMs, force = true)
                }
            }
        }
        write(name, content)
        return manifest.durationMs
    }

    private fun transfer(uri: URI, range: HlsRange?, name: String, key: Boolean) {
        val file = File(directory, name)
        request(uri, range) { _, response ->
            val expected = range?.length ?: response.contentLengthLong.takeIf { it >= 0 }
            val limit = if (key) 16L else MAX_MEDIA_BYTES
            if (expected != null && (expected <= 0 || expected > limit)) throw HlsTransferFailure("mediaRejected")
            checkSpace(expected ?: 0)
            var written = 0L
            var nextSpaceCheck = 4 * 1024 * 1024L
            response.inputStream.use { input ->
                try {
                    FileOutputStream(file).use { output ->
                        val buffer = ByteArray(128 * 1024)
                        while (true) {
                            checkActive()
                            val count = input.read(buffer)
                            if (count < 0) break
                            written += count
                            if (bytes + count > MAX_PACKAGE_BYTES || nextFile > 24_000) {
                                throw HlsTransferFailure("unsupported")
                            }
                            if (written > limit || expected != null && written > expected) {
                                throw HlsTransferFailure("incomplete")
                            }
                            if (written >= nextSpaceCheck) {
                                checkSpace(0)
                                nextSpaceCheck = written + 4 * 1024 * 1024L
                            }
                            try {
                                output.write(buffer, 0, count)
                            } catch (_: IOException) {
                                throw HlsTransferFailure(if (directory.usableSpace < MIN_FREE_BYTES) "outOfSpace" else "storage")
                            }
                            bytes += count
                            emit(null, null)
                        }
                        if (written == 0L || expected != null && written != expected || key && written != 16L) {
                            throw HlsTransferFailure("incomplete")
                        }
                        try {
                            output.fd.sync()
                        } catch (_: IOException) {
                            throw HlsTransferFailure("storage")
                        }
                    }
                } catch (error: java.io.FileNotFoundException) {
                    throw HlsTransferFailure(if (directory.usableSpace < MIN_FREE_BYTES) "outOfSpace" else "storage")
                }
            }
        }
    }

    private fun write(name: String, value: String) {
        checkActive()
        val content = value.toByteArray(Charsets.UTF_8)
        if (bytes + content.size > MAX_PACKAGE_BYTES) throw HlsTransferFailure("unsupported")
        checkSpace(content.size.toLong())
        try {
            FileOutputStream(File(directory, name)).use { output ->
                output.write(content)
                output.fd.sync()
            }
        } catch (_: IOException) {
            throw HlsTransferFailure("storage")
        }
        bytes += content.size
    }

    private fun checkSpace(needed: Long) {
        if (directory.usableSpace < MIN_FREE_BYTES + needed) throw HlsTransferFailure("outOfSpace")
    }

    private fun emit(loadedMs: Long?, totalMs: Long?, force: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (force || now - lastProgress >= 300) {
            lastProgress = now
            progress(bytes, loadedMs, totalMs)
        }
    }

    private fun checkActive() {
        if (stopped) throw HlsTransferFailure("cancelled")
        val now = SystemClock.elapsedRealtime()
        if (now - started >= VideoMp4Transfer.MAX_TRANSFER_MILLIS) throw HlsTransferFailure("timeout")
        if (captionDeadline?.let { now >= it } == true) throw HlsTransferFailure("captionBudget")
    }

    private fun <T> request(initial: URI, range: HlsRange?, read: (URI, HttpURLConnection) -> T): T {
        var target = initial
        repeat(6) { hop ->
            checkActive()
            val request = try { open(target) } catch (error: HlsTransferFailure) { throw error }
                catch (_: IOException) { throw HlsTransferFailure("network") }
            try {
                synchronized(connectionLock) {
                    checkActive()
                    connection = request
                }
                request.instanceFollowRedirects = false
                val timeout = captionDeadline?.let { (it - SystemClock.elapsedRealtime()).coerceIn(1, 15_000).toInt() } ?: 15_000
                request.connectTimeout = timeout
                request.readTimeout = timeout
                request.useCaches = false
                request.setRequestProperty("Accept-Encoding", "identity")
                for ((key, value) in headers) {
                    if (key == "User-Agent" || target.host.equals(original.host, ignoreCase = true)) {
                        request.setRequestProperty(key, value)
                    }
                }
                if (range != null) request.setRequestProperty("Range", "bytes=${range.start}-${range.end}")
                val code = request.responseCode
                if (code in setOf(301, 302, 303, 307, 308)) {
                    val location = request.getHeaderField("Location")
                    if (hop == 5 || location == null) throw HlsTransferFailure("redirectRejected")
                    target = resolve(target, location)
                    return@repeat
                }
                if (code != if (range == null) 200 else 206) throw HlsTransferFailure(
                    when (code) {
                        401, 403 -> "httpForbidden"
                        404, 410 -> "httpNotFound"
                        200, 206, 416 -> "incomplete"
                        else -> "httpError"
                    },
                    code.takeIf { it in 100..599 },
                )
                if (range != null && !range.matches(request.getHeaderField("Content-Range"))) {
                    throw HlsTransferFailure("incomplete")
                }
                return read(target, request)
            } catch (error: HlsTransferFailure) {
                throw error
            } catch (_: SocketTimeoutException) {
                checkActive()
                throw HlsTransferFailure("timeout")
            } catch (_: IOException) {
                checkActive()
                throw HlsTransferFailure("network")
            } finally {
                synchronized(connectionLock) {
                    if (connection === request) connection = null
                }
                request.disconnect()
            }
        }
        throw HlsTransferFailure("redirectRejected")
    }

    private companion object {
        val OPTIONAL_CAPTION_ERRORS = setOf("unsupported", "mediaRejected", "redirectRejected",
            "httpForbidden", "httpNotFound", "incomplete", "timeout")
    }

    private fun resolve(base: URI, value: String): URI {
        val resolved = try { base.resolve(value) } catch (_: IllegalArgumentException) { null }
        return resolved?.let { hlsHttps(it.toASCIIString()) }
            ?: throw HlsTransferFailure("redirectRejected")
    }
}

internal fun hlsHttps(raw: String): URI? = videoHttps(raw)?.takeIf {
    val host = it.host.lowercase().trimEnd('.')
    raw.length <= 8192 && host.contains('.') &&
        !host.endsWith(".local") && !host.endsWith(".localhost") &&
        host.any { char -> char in 'a'..'z' } && ':' !in host
}

internal data class HlsRange(val start: Long, val length: Long) {
    val end: Long get() = start + length - 1

    fun matches(header: String?): Boolean {
        val values = header?.let { CONTENT_RANGE.matchEntire(it)?.groupValues } ?: return false
        val total = values[3].toLongOrNull()
        return values[1].toLongOrNull() == start && values[2].toLongOrNull() == end &&
            (values[3] == "*" || total != null && total > end)
    }

    private companion object {
        val CONTENT_RANGE = Regex("""bytes (\d+)-(\d+)/(\d+|\*)""")
    }
}

internal data class HlsPart(val uri: String, val extension: String, val range: HlsRange? = null, val durationMs: Long = 0)
internal data class HlsLine(val line: String, val part: HlsPart? = null)
internal data class HlsMedia(val entries: List<HlsLine>, val durationMs: Long)

internal data class HlsTrack(
    val uri: String?,
    val label: String,
    val language: String?,
    val default: Boolean,
    val autoselect: Boolean,
    val channels: String?,
)

internal data class HlsMaster(
    val video: String,
    val bandwidth: Long,
    val codecs: String?,
    val audio: List<HlsTrack>,
    val subtitles: List<HlsTrack>,
) {
    fun localPlaylist(): String = buildString {
        appendLine("#EXTM3U")
        appendLine("#EXT-X-VERSION:4")
        audio.forEachIndexed { index, track ->
            append("""#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="${track.label}"""")
            append(",DEFAULT=${if (track.default) "YES" else "NO"},AUTOSELECT=${if (track.autoselect || track.default) "YES" else "NO"}")
            track.language?.let { append(""",LANGUAGE="$it"""") }
            track.channels?.let { append(""",CHANNELS="$it"""") }
            if (track.uri != null) append(""",URI="audio-${index + 1}.m3u8"""")
            appendLine()
        }
        append("#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth")
        codecs?.let { append(""",CODECS="$it"""") }
        if (audio.isNotEmpty()) append(""",AUDIO="audio"""")
        appendLine()
        appendLine("video.m3u8")
    }
}

internal object HlsManifest {
    private val codecList = Regex("[a-zA-Z0-9.-]{1,40}(,[a-zA-Z0-9.-]{1,40}){0,15}")
    private val audioChannels = Regex("[1-9][0-9]?(?:/[a-zA-Z0-9.,-]{1,32})?")
    private val attribute = Regex("""([A-Z0-9-]+)=("[^"\r\n]*"|[^",\r\n]+)""")
    private val safePass = mapOf(
        "#EXT-X-VERSION" to Regex("""[1-9]\d?"""),
        "#EXT-X-TARGETDURATION" to Regex("""[1-9]\d{0,5}"""),
        "#EXT-X-MEDIA-SEQUENCE" to Regex("""\d{1,16}"""),
        "#EXT-X-DISCONTINUITY-SEQUENCE" to Regex("""\d{1,10}"""),
    )

    fun read(text: String): List<String> {
        val lines = text.lineSequence().map(String::trim).filter(String::isNotEmpty).toList()
        if (lines.firstOrNull() != "#EXTM3U" || lines.size > 60_000 ||
            lines.any { line -> line.length > 8192 || line.any { it.code < 32 || it.code == 127 } }) {
            throw HlsTransferFailure("mediaRejected")
        }
        return lines
    }

    fun master(lines: List<String>): HlsMaster? {
        if (lines.none { it.startsWith("#EXT-X-STREAM-INF:") }) return null
        val options = mutableListOf<Pair<Map<String, String>, String>>()
        val tracks = mutableListOf<Map<String, String>>()
        var next: Map<String, String>? = null
        for (line in lines.drop(1)) {
            val tag = line.substringBefore(':')
            if (!line.startsWith("#")) {
                val selection = next ?: unsupported()
                options.add(selection to line)
                next = null
                continue
            }
            when (tag) {
                "#EXT-X-STREAM-INF" -> {
                    if (next != null) unsupported()
                    next = attributes(line)
                }
                "#EXT-X-MEDIA" -> tracks.add(attributes(line))
                "#EXT-X-I-FRAME-STREAM-INF", "#EXT-X-SESSION-DATA",
                "#EXT-X-VERSION", "#EXT-X-INDEPENDENT-SEGMENTS" -> Unit
                else -> if (tag.startsWith("#EXT")) unsupported()
            }
        }
        if (next != null) unsupported()
        val (variant, video) = options.maxByOrNull { (values, _) -> values["BANDWIDTH"]?.toLongOrNull() ?: -1 }
            ?: unsupported()
        val bandwidth = variant["BANDWIDTH"]?.toLongOrNull()?.takeIf { it in 1..1_000_000_000 } ?: unsupported()
        if (variant["VIDEO"] != null) unsupported()
        val audio = variant["AUDIO"]?.let { group ->
            renditions(tracks, group, "AUDIO").also { if (it.isEmpty()) unsupported() }
        }.orEmpty()
        val subtitles = variant["SUBTITLES"]?.let { renditions(tracks, it, "SUBTITLES") }.orEmpty()
        val codecs = variant["CODECS"]?.takeIf(codecList::matches)
        return HlsMaster(video, bandwidth, codecs, audio, subtitles)
    }

    private fun renditions(tracks: List<Map<String, String>>, group: String, type: String): List<HlsTrack> {
        val choices = tracks.asSequence()
            .filter { it["TYPE"] == type && it["GROUP-ID"] == group }
            .filter { type == "AUDIO" || !it["URI"].isNullOrBlank() }
            .take(32)
            .toList()
        val ordered = choices.sortedWith(compareByDescending<Map<String, String>> { it["DEFAULT"] == "YES" }
            .thenByDescending { it["AUTOSELECT"] == "YES" })
        val labels = mutableSetOf<String>()
        val media = mutableSetOf<String?>()
        return ordered.asSequence()
            .filter { media.add(it["URI"]) }
            .take(8)
            .mapIndexed { index, attributes ->
                val language = attributes["LANGUAGE"]?.takeIf { it.matches(Regex("[a-zA-Z0-9-]{1,35}")) }
                val fallback = language ?: "${if (type == "AUDIO") "Audio" else "Subtitles"} ${index + 1}"
                val title = attributes["NAME"]?.take(120)?.trim()?.takeIf(String::isNotEmpty) ?: fallback
                var label = title
                var duplicate = 2
                while (!labels.add(label)) label = "$title (${duplicate++})"
                HlsTrack(attributes["URI"], label, language, index == 0 && attributes["DEFAULT"] == "YES",
                    attributes["AUTOSELECT"] == "YES", attributes["CHANNELS"]?.takeIf(audioChannels::matches))
            }.toList()
    }

    fun media(lines: List<String>): HlsMedia {
        val output = mutableListOf(HlsLine("#EXTM3U"))
        var end = false
        var segmentCount = 0
        var total = 0L
        var nextDuration: Long? = null
        var nextRange: String? = null
        var previousRange: Pair<String, HlsRange>? = null
        var hasMap = false
        var lastMap: Pair<String, HlsRange>? = null
        val singleton = mutableSetOf<String>()
        for (line in lines.drop(1)) {
            val tag = line.substringBefore(':')
            val value = line.substringAfter(':', "")
            if (end && (line.startsWith("#EXT") || !line.startsWith("#"))) unsupported()
            when {
                !line.startsWith("#") -> {
                    val duration = nextDuration ?: unsupported()
                    val range = nextRange?.let { range(it, line, previousRange) }
                    previousRange = range?.let { line to it }
                    nextRange = null
                    nextDuration = null
                    if (++segmentCount > 10_000) unsupported()
                    total += duration
                    val extension = when {
                        hasMap -> "m4s"
                        line.substringBefore('?').substringAfterLast('.').lowercase() in setOf("aac", "ac3", "ec3", "mp3", "vtt", "webvtt") ->
                            line.substringBefore('?').substringAfterLast('.').lowercase()
                        else -> "ts"
                    }
                    output.add(HlsLine("@FILE@", HlsPart(line, extension, range, duration)))
                }
                tag == "#EXTINF" -> {
                    if (nextDuration != null) unsupported()
                    val seconds = value.substringBefore(',').toDoubleOrNull()
                        ?.takeIf { it.isFinite() && it > 0 && it <= 86_400 } ?: unsupported()
                    nextDuration = (seconds * 1000).roundToLong()
                    output.add(HlsLine("#EXTINF:${value.substringBefore(',')},"))
                }
                tag == "#EXT-X-BYTERANGE" -> {
                    if (nextRange != null || nextDuration == null) unsupported()
                    nextRange = value
                }
                tag == "#EXT-X-MAP" -> {
                    val attrs = attributes(line)
                    if (attrs.keys.any { it !in setOf("URI", "BYTERANGE") }) unsupported()
                    val mapUri = attrs["URI"] ?: unsupported()
                    val range = attrs["BYTERANGE"]?.let { range(it, mapUri, lastMap) }
                    lastMap = range?.let { mapUri to it }
                    hasMap = true
                    output.add(HlsLine("""#EXT-X-MAP:URI="@FILE@"""", HlsPart(mapUri, "mp4", range)))
                }
                tag == "#EXT-X-KEY" -> {
                    val attrs = attributes(line)
                    when (attrs["METHOD"]) {
                        "NONE" -> {
                            if (attrs.size != 1) unsupported()
                            output.add(HlsLine("#EXT-X-KEY:METHOD=NONE"))
                        }
                        "AES-128" -> {
                            if (attrs.keys.any { it !in setOf("METHOD", "URI", "IV", "KEYFORMAT", "KEYFORMATVERSIONS") } ||
                                attrs["KEYFORMAT"]?.let { it != "identity" } == true ||
                                attrs["KEYFORMATVERSIONS"]?.let { it != "1" } == true) unsupported()
                            val key = attrs["URI"] ?: unsupported()
                            val iv = attrs["IV"]?.let {
                                if (!it.matches(Regex("""0[xX][0-9a-fA-F]{1,32}"""))) unsupported()
                                ",IV=$it"
                            }.orEmpty()
                            output.add(HlsLine("""#EXT-X-KEY:METHOD=AES-128,URI="@FILE@"$iv""", HlsPart(key, "key")))
                        }
                        else -> unsupported()
                    }
                }
                tag == "#EXT-X-ENDLIST" -> {
                    if (line != tag || nextDuration != null || nextRange != null) unsupported()
                    end = true
                    output.add(HlsLine(tag))
                }
                tag in safePass -> {
                    if (!singleton.add(tag) || safePass.getValue(tag).matches(value).not()) unsupported()
                    output.add(HlsLine(line))
                }
                line in setOf("#EXT-X-DISCONTINUITY", "#EXT-X-INDEPENDENT-SEGMENTS") ->
                    output.add(HlsLine(line))
                tag == "#EXT-X-PLAYLIST-TYPE" -> {
                    if (value !in setOf("VOD", "EVENT")) unsupported()
                }
                tag in setOf("#EXT-X-PROGRAM-DATE-TIME", "#EXT-X-DATERANGE", "#EXT-X-START") -> Unit
                tag.startsWith("#EXT") -> unsupported()
            }
        }
        if (!end || segmentCount == 0 || total <= 0 || "#EXT-X-TARGETDURATION" !in singleton) unsupported()
        return HlsMedia(output, total)
    }

    private fun range(value: String, uri: String, previous: Pair<String, HlsRange>?): HlsRange {
        val parts = value.split('@', limit = 2)
        val length = parts[0].toLongOrNull()?.takeIf { it in 1..MAX_MEDIA_BYTES } ?: unsupported()
        val start = if (parts.size == 2) parts[1].toLongOrNull()
            else previous?.takeIf { it.first == uri }?.second?.let { it.end + 1 }
        if (start == null || start < 0 || start > Long.MAX_VALUE - length) unsupported()
        return HlsRange(start, length)
    }

    private fun attributes(line: String): Map<String, String> {
        val values = line.substringAfter(':', "")
        val result = mutableMapOf<String, String>()
        var start = 0
        for (match in attribute.findAll(values)) {
            if (match.range.first != start) unsupported()
            val (key, value) = match.destructured
            if (result.put(key, value.removeSurrounding("\"")) != null) unsupported()
            start = match.range.last + 1
            if (start < values.length && values[start++] != ',') unsupported()
        }
        if (start != values.length || result.isEmpty() || values.endsWith(',')) unsupported()
        return result
    }

    private fun unsupported(): Nothing = throw HlsTransferFailure("unsupported")
}
