package com.zephyr.breeze

import java.util.UUID

/** Main-queue ownership for a single managed video transfer and its notification. */
internal class VideoDownloadForeground(private val launchService: () -> Boolean) {
    data class Notice(val token: String, val received: Long = 0, val total: Long = -1)

    interface Host {
        fun update(notice: Notice)
        fun stop()
    }

    inner class Lease internal constructor(
        internal val ready: () -> Unit,
        internal val interrupted: (String?) -> Unit,
    ) {
        internal var notice = Notice(UUID.randomUUID().toString())
        internal var host: Host? = null
        internal var started = false

        fun launch(): Boolean = current === this && launchService()

        fun progress(received: Long, total: Long) {
            if (current !== this) return
            notice = notice.copy(received = received, total = total)
            host?.update(notice)
        }

        fun close() {
            if (current !== this) return
            current = null
            host?.stop()
            host = null
        }
    }

    private var current: Lease? = null
    val notice: Notice? get() = current?.notice

    fun acquire(ready: () -> Unit, interrupted: (String?) -> Unit): Lease? {
        if (current != null) return null
        val lease = Lease(ready, interrupted)
        current = lease
        return lease
    }

    fun bind(host: Host, token: String): Boolean {
        val lease = current?.takeIf { it.notice.token == token } ?: return false
        lease.host = host
        if (!lease.started) {
            lease.started = true
            lease.ready()
        }
        return true
    }

    fun cancel(token: String?) {
        current?.takeIf { it.notice.token == token }?.interrupted?.invoke(null)
    }

    fun rejected(token: String) {
        current?.takeIf { it.notice.token == token }?.interrupted?.invoke("unavailable")
    }

    fun interrupted(host: Host, reason: String) {
        val lease = current?.takeIf { it.host === host } ?: return
        lease.host = null
        lease.interrupted(reason)
    }
}
