package com.zephyr.breeze

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock

/** The OS-visible owner for the process-managed MP4 writer. */
internal class VideoDownloadForegroundService : Service(), VideoDownloadForeground.Host {
    companion object {
        private const val CHANNEL_ID = "breeze_video_download"
        private const val NOTIFICATION_ID = 31471
        private const val ACTION_START = "com.zephyr.breeze.video.START"
        private const val ACTION_CANCEL = "com.zephyr.breeze.video.CANCEL"
        private const val EXTRA_TOKEN = "videoDownloadToken"
        private var coordinator: VideoDownloadForeground? = null

        internal fun forProcess(context: Context): VideoDownloadForeground =
            coordinator ?: VideoDownloadForeground {
                val intent = Intent(context, VideoDownloadForegroundService::class.java)
                    .setAction(ACTION_START)
                try {
                    context.startForegroundService(intent) != null
                } catch (_: IllegalStateException) {
                    false
                } catch (_: SecurityException) {
                    false
                }
            }.also { coordinator = it }
    }

    private val notifications by lazy { getSystemService(NotificationManager::class.java) }
    private val openApp by lazy {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, NOTIFICATION_ID, it, PendingIntent.FLAG_IMMUTABLE)
        }
    }
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastStartId = 0
    private var lastUpdate = 0L
    private var foreground = false
    private var activeToken: String? = null
    private var cancelAction: Pair<String, PendingIntent>? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lastStartId = startId
        if (intent?.action == ACTION_CANCEL) {
            coordinator?.cancel(intent.getStringExtra(EXTRA_TOKEN))
            if (!foreground) stopSelfResult(startId)
            return START_NOT_STICKY
        }
        val owner = coordinator
        val notice = owner?.notice
        if (intent?.action != ACTION_START) {
            if (!foreground) stopSelfResult(startId)
            return START_NOT_STICKY
        }
        try {
            notifications.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, getString(R.string.video_download_notification_title), NotificationManager.IMPORTANCE_LOW,
            ))
            val notification = buildNotification(notice)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            foreground = true
            // A queued start can arrive after the user cancelled. Acknowledge
            // its promotion first, then stop this empty service.
            if (owner == null || notice == null) {
                stop()
                return START_NOT_STICKY
            }
            activateNotice(notice.token)
            lastUpdate = SystemClock.elapsedRealtime()
            if (!owner.bind(this, notice.token)) stop()
        } catch (_: RuntimeException) {
            if (notice != null) owner?.rejected(notice.token)
            stop()
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(notice: VideoDownloadForeground.Notice?): Notification {
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(getString(R.string.video_download_notification_title))
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
        if (notice != null) {
            val total = notice.total
            val percent = if (total > 0) (notice.received.toDouble() / total * 100).toInt().coerceIn(0, 100) else 0
            builder.setProgress(100, percent, total <= 0)
            builder.addAction(Notification.Action.Builder(
                null, getString(R.string.video_download_notification_cancel), cancelIntent(notice.token),
            ).build())
        }
        openApp?.let(builder::setContentIntent)
        return builder.build()
    }

    private fun cancelIntent(token: String): PendingIntent {
        val existing = cancelAction
        if (existing?.first == token) return existing.second
        existing?.second?.cancel()
        val intent = Intent(this, VideoDownloadForegroundService::class.java)
            .setAction(ACTION_CANCEL)
            .setData(Uri.Builder().scheme("breeze").authority("video-download").appendPath(token).build())
            .putExtra(EXTRA_TOKEN, token)
        return PendingIntent.getService(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            .also { cancelAction = token to it }
    }

    override fun update(notice: VideoDownloadForeground.Notice) {
        if (!foreground) return
        val changed = activeToken != notice.token
        if (changed) activateNotice(notice.token)
        val now = SystemClock.elapsedRealtime()
        if (!changed && now - lastUpdate < 1000L) return
        lastUpdate = now
        try {
            notifications.notify(NOTIFICATION_ID, buildNotification(notice))
        } catch (_: RuntimeException) {
            // The system can withhold notification display without ending the transfer.
        }
    }

    private fun activateNotice(token: String) {
        if (activeToken == token) return
        releaseWakeLock()
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Breeze:VideoDownload")
            .apply {
                setReferenceCounted(false)
                acquire(VideoMp4Transfer.MAX_TRANSFER_MILLIS + 60_000L)
            }
        activeToken = token
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    private fun releaseForeground() {
        activeToken = null
        cancelAction?.second?.cancel()
        cancelAction = null
        releaseWakeLock()
        if (foreground) stopForeground(STOP_FOREGROUND_REMOVE)
        foreground = false
    }

    override fun stop() {
        releaseForeground()
        stopSelfResult(lastStartId)
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        releaseForeground()
        stopSelf()
        coordinator?.interrupted(this, "timeout")
    }

    override fun onDestroy() {
        releaseForeground()
        coordinator?.interrupted(this, "unavailable")
        super.onDestroy()
    }
}
