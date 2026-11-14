package com.zephyr.breeze

import java.util.Locale

/** Converts media-relative HLS subtitle segments into a bounded offline WebVTT file. */
internal class HlsWebVtt(private val durationMs: Long) {
    private data class Cue(val start: Long, val end: Long, val body: String)
    private val cues = linkedSetOf<Cue>()
    private var cost = 0L

    fun add(input: String, segmentStart: Long, segmentEnd: Long) {
        if ('\uFFFD' in input || input.any { it.code < 32 && it !in "\t\r\n" }) unsupported()
        val lines = input.removePrefix("\uFEFF").lineSequence().map { it.trimEnd() }.toList()
        if (lines.firstOrNull()?.matches(HEADER) != true) unsupported()
        // Embedded MPEG-TS clocks require the video stream's timestamp
        // adjuster. Treat them as unsupported rather than guessing an offset.
        if (lines.any { line ->
                line.startsWith("X-TIMESTAMP-MAP") && line !in IDENTITY_TIMESTAMP_MAPS
            }) unsupported()
        var index = 1
        while (index < lines.size && lines[index].isNotBlank()) index++
        while (index < lines.size) {
            while (index < lines.size && lines[index].isBlank()) index++
            val start = index
            while (index < lines.size && lines[index].isNotBlank()) index++
            if (start == index) break
            val block = lines.subList(start, index)
            val first = block[0]
            if (first == "NOTE" || first.startsWith("NOTE ") || first.startsWith("NOTE\t") ||
                first == "STYLE" || first == "REGION") continue
            val timing = if ("-->" in first) 0 else 1
            if (block.size <= timing + 1) unsupported()
            val range = TIMING.matchEntire(block[timing]) ?: unsupported()
            val from = millis(range.groupValues[1])
            val to = millis(range.groupValues[2])
            if (from >= to || from >= durationMs || to <= segmentStart || from >= segmentEnd) unsupported()
            val body = block.drop(timing + 1).joinToString("\n")
            if (body.length > 4096 || "-->" in body) unsupported()
            val cue = Cue(from, to.coerceAtMost(durationMs), body)
            if (cues.add(cue)) {
                cost += body.toByteArray(Charsets.UTF_8).size + 64
                if (cues.size > 12_000 || cost > MAX_FILE_BYTES) unsupported()
            }
        }
    }

    fun file(): String {
        if (cues.isEmpty()) unsupported()
        return buildString {
            appendLine("WEBVTT")
            appendLine()
            for (cue in cues.sortedBy { it.start }) {
                appendLine("${timestamp(cue.start)} --> ${timestamp(cue.end)}")
                appendLine(cue.body)
                appendLine()
            }
        }
    }

    private fun millis(value: String): Long {
        val matched = TIME.matchEntire(value) ?: unsupported()
        val hours = matched.groupValues[1].ifEmpty { "0" }.toLong()
        val minutes = matched.groupValues[2].toInt()
        val seconds = matched.groupValues[3].toInt()
        if (minutes >= 60 || seconds >= 60) unsupported()
        return hours * 3_600_000 + minutes * 60_000L + seconds * 1000L +
            matched.groupValues[4].toInt()
    }

    private fun timestamp(ms: Long) = String.format(Locale.ROOT, "%02d:%02d:%02d.%03d",
        ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)

    private fun unsupported(): Nothing = throw HlsTransferFailure("unsupported")

    companion object {
        const val MAX_SEGMENT_BYTES = 256 * 1024
        const val MAX_FILE_BYTES = 2 * 1024 * 1024
        private val HEADER = Regex("""WEBVTT(?:[ \t].*)?""")
        private val TIMING = Regex("""(\S+)\s+-->\s+(\S+)(?:\s+.*)?""")
        private val TIME = Regex("""(?:(\d{2,6}):)?(\d{2}):(\d{2})\.(\d{3})""")
        private val IDENTITY_TIMESTAMP_MAPS = setOf(
            "X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0",
            "X-TIMESTAMP-MAP=MPEGTS:0,LOCAL:00:00:00.000",
        )
    }
}
