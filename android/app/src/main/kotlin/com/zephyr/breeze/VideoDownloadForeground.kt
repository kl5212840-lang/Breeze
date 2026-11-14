package com.zephyr.breeze

import java.util.UUID

/** Main-queue ownership for managed video transfers and their foreground notification. */
internal class VideoDownloadForeground(private val launchService: () -> Boolean) {
    companion object {
        const val maxTransfers = 3
    }

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
        internal var started = false

        fun launch(): Boolean {
            if (leases[notice.token] !== this) return false
            val bound = host
            if (bound != null) {
                begin()
                return true
            }
            if (promotionPending) return true
            promotionPending = launchService()
            return promotionPending
        }

        internal fun begin() {
            if (started || leases[notice.token] !== this) return
            started = true
            ready()
        }

        fun progress(received: Long, total: Long) {
            if (leases[notice.token] !== this) return
            notice = notice.copy(received = received, total = total)
            if (this@VideoDownloadForeground.notice?.token == notice.token) host?.update(notice)
        }

        fun close() {
            val wasVisible = this@VideoDownloadForeground.notice?.token == notice.token
            if (leases.remove(notice.token) !== this) return
            val next = this@VideoDownloadForeground.notice
            if (next == null) {
                val bound = host
                host = null
                promotionPending = false
                bound?.stop()
            } else if (wasVisible) {
                host?.update(next)
            }
        }
    }

    private val leases = linkedMapOf<String, Lease>()
    private var host: Host? = null
    private var promotionPending = false
    val notice: Notice? get() = leases.values.firstOrNull()?.notice

    fun acquire(ready: () -> Unit, interrupted: (String?) -> Unit): Lease? {
        if (leases.size >= maxTransfers) return null
        val lease = Lease(ready, interrupted)
        leases[lease.notice.token] = lease
        return lease
    }

    fun bind(host: Host, token: String): Boolean {
        if (token != notice?.token) return false
        this.host = host
        promotionPending = false
        leases.values.toList().forEach { it.begin() }
        return true
    }

    fun cancel(token: String?) {
        leases[token]?.interrupted?.invoke(null)
    }

    fun rejected(token: String) {
        if (token != notice?.token) return
        promotionPending = false
        leases.values.toList().forEach { it.interrupted("unavailable") }
    }

    fun interrupted(host: Host, reason: String) {
        if (this.host !== host) return
        this.host = null
        leases.values.toList().forEach { it.interrupted(reason) }
    }
}
