package com.zephyr.breeze

import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URI

internal fun videoHttps(raw: String): URI? = try {
    URI(raw).takeIf {
        it.scheme == "https" && !it.host.isNullOrEmpty() && it.rawUserInfo == null &&
            (it.port == -1 || it.port == 443) && it.rawFragment == null
    }
} catch (_: IllegalArgumentException) {
    null
} catch (_: java.net.URISyntaxException) {
    null
}

internal class VideoMp4Failure(val reason: String, val httpStatus: Int? = null) : IOException() {
    fun result(): Map<String, Any> = buildMap {
        put("status", "failed")
        put("reason", reason)
        httpStatus?.let { put("httpStatus", it) }
    }
}

/** One cancellable transport shared by managed transfers and direct Files export. */
internal class VideoMp4Transfer {
    companion object {
        const val MAX_TRANSFER_MILLIS = 3_600_000L
    }

    @Volatile var cancelled = false
        private set
    @Volatile var received = 0L
        private set
    @Volatile var total = -1L
        private set
    private var connection: HttpURLConnection? = null

    fun cancel() {
        val pending = synchronized(this) {
            cancelled = true
            connection.also { connection = null }
        }
        pending?.disconnect()
    }

    fun download(
        file: File,
        original: URI,
        referer: URI,
        headers: Map<String, String>,
        clock: () -> Long,
        open: (URI) -> HttpURLConnection,
        progress: () -> Unit,
    ) {
        val started = clock()
        var target = original
        repeat(6) { hop ->
            check(!cancelled)
            val attempt = try {
                open(target)
            } catch (error: VideoMp4Failure) {
                throw error
            } catch (_: IOException) {
                throw VideoMp4Failure("network")
            }
            try {
                synchronized(this) {
                    check(!cancelled)
                    connection = attempt
                }
                attempt.instanceFollowRedirects = false
                attempt.connectTimeout = 45000
                attempt.readTimeout = 45000
                attempt.useCaches = false
                attempt.setRequestProperty("Accept-Encoding", "identity")
                if (target.host == original.host) {
                    attempt.setRequestProperty("Referer", referer.toString())
                }
                for ((name, value) in headers) {
                    if (name == "User-Agent" || target.host == original.host) {
                        attempt.setRequestProperty(name, value)
                    }
                }
                val code = attempt.responseCode
                if (code in listOf(301, 302, 303, 307, 308)) {
                    val location = attempt.getHeaderField("Location")
                    target = try {
                        if (hop == 5 || location == null) null else videoHttps(target.resolve(location).toString())
                    } catch (_: IllegalArgumentException) {
                        null
                    } ?: throw VideoMp4Failure("redirectRejected")
                    return@repeat
                }
                if (code != HttpURLConnection.HTTP_OK) {
                    throw VideoMp4Failure(when (code) {
                        401, 403 -> "httpForbidden"
                        404, 410 -> "httpNotFound"
                        206 -> "incomplete"
                        else -> "httpError"
                    }, code.takeIf { it in 100..599 })
                }
                val mime = attempt.contentType?.substringBefore(';')?.trim()?.lowercase().orEmpty()
                if (mime.isNotEmpty() && mime !in setOf(
                        "video/mp4", "application/mp4", "application/octet-stream", "binary/octet-stream",
                    )) {
                    throw VideoMp4Failure("mediaRejected")
                }
                total = attempt.contentLengthLong
                attempt.inputStream.buffered().use { input ->
                    val header = ByteArray(12)
                    var offset = 0
                    while (offset < header.size) {
                        val count = input.read(header, offset, header.size - offset)
                        if (count <= 0) throw VideoMp4Failure("incomplete")
                        offset += count
                    }
                    if (String(header, 4, 4, Charsets.US_ASCII) != "ftyp") {
                        throw VideoMp4Failure("mediaRejected")
                    }
                    val output = try {
                        file.outputStream()
                    } catch (_: IOException) {
                        throw VideoMp4Failure("storage")
                    }
                    output.use {
                        fun write(bytes: ByteArray, count: Int) {
                            try {
                                output.write(bytes, 0, count)
                            } catch (_: IOException) {
                                throw VideoMp4Failure("storage")
                            }
                            received += count
                        }
                        write(header, header.size)
                        val buffer = ByteArray(128 * 1024)
                        while (!cancelled) {
                            if (clock() - started >= MAX_TRANSFER_MILLIS) throw VideoMp4Failure("timeout")
                            val count = input.read(buffer)
                            if (count < 0) break
                            write(buffer, count)
                            progress()
                        }
                    }
                }
                check(!cancelled)
                if (received <= 12 || total >= 0 && received != total) {
                    throw VideoMp4Failure("incomplete")
                }
                return
            } catch (error: VideoMp4Failure) {
                throw error
            } catch (_: SocketTimeoutException) {
                throw VideoMp4Failure("timeout")
            } catch (_: IOException) {
                throw VideoMp4Failure("network")
            } finally {
                synchronized(this) {
                    if (connection === attempt) connection = null
                }
                attempt.disconnect()
            }
        }
    }
}
