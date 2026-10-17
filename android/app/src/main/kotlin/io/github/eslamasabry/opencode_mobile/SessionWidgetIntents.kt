package io.github.eslamasabry.opencode_mobile

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONObject

internal object SessionWidgetIntents {
    fun backgroundSettingsIntent(context: Context, id: Int): PendingIntent =
        PendingIntent.getActivity(context, id, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = Uri.parse("opencode-widget://background-settings/$id")
            putExtra(MainActivity.EXTRA_LAUNCH_ACTION, WidgetV2Policy.BACKGROUND_SETTINGS_ACTION)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun chatIntent(context: Context, id: Int, snapshot: JSONObject, session: JSONObject?): PendingIntent =
        PendingIntent.getActivity(context, id, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = Uri.Builder().scheme("opencode").authority("widget").appendPath(snapshot.optString("profileID"))
                .appendPath(session?.optString("id").orEmpty()).build()
            // Team rows have synthetic IDs, not chat session IDs. Open the app until
            // an explicit project deep-link contract exists.
            if (session != null && session.optJSONObject("team") == null) {
                putExtra(BackgroundConnectionService.EXTRA_CODING_ALERT_KIND, "complete")
                putExtra(BackgroundConnectionService.EXTRA_CODING_ALERT_SESSION_ID, session.optString("id"))
                putExtra(BackgroundConnectionService.EXTRA_CODING_ALERT_PROFILE_ID, snapshot.optString("profileID"))
            }
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}
