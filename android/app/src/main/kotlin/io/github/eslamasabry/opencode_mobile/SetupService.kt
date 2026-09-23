package io.github.eslamasabry.opencode_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app alive while a phone setup job runs (SetupRunner.kt).
 *
 * The job is a thread and child processes of the app's process; without a
 * foreground service Android may reclaim the process as soon as the person
 * switches apps, minutes into a download. The ongoing notification mirrors
 * the overall percent and opens the app when tapped. When the job ends the
 * service stops and leaves one ordinary notification saying how it went.
 *
 * Every text comes from the app, already in the person's language.
 */
class SetupService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channel = intent?.getStringExtra(EXTRA_CHANNEL) ?: "Setup"
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        createChannel(this, channel)
        val notification = build(this, title, text, ongoing = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // Not sticky: a restarted service without the process's job thread
        // would only show a stale percent.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "opencode_phone_setup"
        private const val NOTIFICATION_ID = 4098
        // Its own id: the service's notification goes away when the service
        // stops, which could otherwise take this one with it.
        private const val RESULT_NOTIFICATION_ID = 4099
        private const val EXTRA_CHANNEL = "channel"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"

        fun start(context: Context, channel: String, title: String, text: String) {
            context.getSystemService(NotificationManager::class.java)?.cancel(RESULT_NOTIFICATION_ID)
            val intent = Intent(context, SetupService::class.java)
                .putExtra(EXTRA_CHANNEL, channel)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Replaces the ongoing notification's text; the service keeps running. */
        fun update(context: Context, channel: String, title: String, text: String) {
            createChannel(context, channel)
            context.getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, build(context, title, text, ongoing = true))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SetupService::class.java))
        }

        /** Stops the service and leaves [text] as a plain, dismissable notification. */
        fun finish(context: Context, channel: String, text: String) {
            stop(context)
            createChannel(context, channel)
            context.getSystemService(NotificationManager::class.java)
                ?.notify(RESULT_NOTIFICATION_ID, build(context, text, null, ongoing = false))
        }

        private fun createChannel(context: Context, name: String) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                },
            )
        }

        private fun build(context: Context, title: String, text: String?, ongoing: Boolean): Notification {
            val open = PendingIntent.getActivity(
                context,
                2,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            return builder
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .apply { if (!text.isNullOrEmpty()) setContentText(text) }
                .setOngoing(ongoing)
                .setOnlyAlertOnce(true)
                .setAutoCancel(!ongoing)
                .setContentIntent(open)
                .build()
        }
    }
}
