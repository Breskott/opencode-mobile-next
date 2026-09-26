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
 * Keeps the app alive while the OpenCode server (and, when it is on, AI Team)
 * runs inside it.
 *
 * The services are children of the app's process, so when Android reclaims
 * the process they go with it, mid-task. While any of them runs, this service
 * holds the app in the foreground state with an ongoing notification that
 * says so and offers Stop, which stops them all. It starts with the first
 * service and ends with the last (BuiltinLinux.startService/stopService).
 */
class BuiltinServerService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Storage measurement/removal can hold the runtime lifecycle lock.
            // Waiting for that lock (and stopping process trees) must not block UI.
            Thread {
                BuiltinLinux.get(applicationContext).stopAllServices()
                stopSelf(startId)
            }.start()
            return START_NOT_STICKY
        }
        createChannel()
        val notification = buildNotification(intent?.getStringExtra(EXTRA_TITLE))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "OpenCode on this phone",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while the OpenCode server runs inside the app"
                setShowBadge(false)
            },
        )
    }

    private fun buildNotification(title: String?): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, BuiltinServerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title ?: "OpenCode is running on this phone")
            .setContentText("Your agent keeps working while you use other apps.")
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "opencode_builtin_server"
        private const val NOTIFICATION_ID = 4097
        private const val ACTION_STOP = "stop"
        private const val EXTRA_TITLE = "title"

        /** Starts the service, or updates its notification to [title]. */
        fun start(context: Context, title: String? = null) {
            val intent = Intent(context, BuiltinServerService::class.java)
                .putExtra(EXTRA_TITLE, title)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BuiltinServerService::class.java))
        }
    }
}
