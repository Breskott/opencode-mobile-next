package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/** Renders one responsive widget size from the same cached snapshot. */
internal class SessionWidgetRenderer(
    private val context: Context,
    private val id: Int,
    private val snapshot: JSONObject
) {
    fun render(width: Int, height: Int): RemoteViews {
        val size = WidgetLayoutPolicy.size(width, height)
        val views = RemoteViews(context.packageName, when (size) {
            WidgetV2Policy.Size.COMPACT -> R.layout.widget_sessions_compact
            WidgetV2Policy.Size.CARD -> R.layout.widget_sessions_card
            WidgetV2Policy.Size.LIST -> R.layout.widget_sessions
        })
        WidgetV2Style.apply(context, views, id, snapshot)
        val palette = WidgetV2Style.palette(context, id, snapshot)
        val state = SessionWidgetSnapshot(snapshot)
        bindSummary(views, state, palette)
        if (size == WidgetV2Policy.Size.COMPACT) {
            val color = when {
                state.needs > 0 -> palette.attention
                state.running > 0 -> palette.running
                else -> palette.neutral
            }
            views.setTextColor(R.id.widget_v2_dot, color)
        } else {
            bindControls(views, state.connection, size, palette)
            bindRows(views, state, palette, size, height)
        }
        return views
    }

    private fun bindSummary(views: RemoteViews, state: SessionWidgetSnapshot, palette: WidgetV2Style.Palette) {
        val showSettings = state.connection == WidgetV2Policy.Connection.BACKGROUND_SETTINGS
        val summary = if (state.sessions.isEmpty()) NativeStrings.get(context, R.string.widget_empty)
            else NativeStrings.get(context, R.string.widget_v2_summary, state.running, state.needs)
        val notice = WidgetV2Policy.actionResultNotice(snapshot.optJSONObject("actionResult")?.optString("status"))
        val resultCopy = when (notice) {
            "rejected" -> R.string.widget_v2_failed
            "uncertain" -> R.string.widget_v2_uncertain
            else -> null
        }
        views.setTextViewText(R.id.widget_v2_summary, when {
            showSettings -> NativeStrings.get(context, R.string.widget_v2_background_settings)
            state.connection == WidgetV2Policy.Connection.PENDING ->
                NativeStrings.get(context, R.string.widget_v2_pending)
            resultCopy != null -> "$summary · ${NativeStrings.get(context, resultCopy)}"
            else -> summary
        })
        views.setTextColor(R.id.widget_v2_summary, if (showSettings) palette.accent else palette.text)
        val open = SessionWidgetIntents.chatIntent(context, id, snapshot, state.sessions.firstOrNull())
        views.setOnClickPendingIntent(android.R.id.background, open)
        views.setOnClickPendingIntent(R.id.widget_v2_summary,
            if (showSettings) SessionWidgetIntents.backgroundSettingsIntent(context, id) else open)
    }

    private fun bindControls(
        views: RemoteViews,
        connection: WidgetV2Policy.Connection,
        size: WidgetV2Policy.Size,
        palette: WidgetV2Style.Palette
    ) {
        val overlays = WidgetV2Bridge.overlayReady(context)
        val connected = connection == WidgetV2Policy.Connection.CONNECTED
        views.setViewVisibility(R.id.widget_v2_configure,
            if (overlays && size == WidgetV2Policy.Size.LIST) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.widget_v2_voice, NativeStrings.get(context, R.string.widget_v2_voice))
        views.setTextViewText(R.id.widget_v2_configure, NativeStrings.get(context, R.string.widget_v2_configure))
        views.setTextColor(R.id.widget_v2_voice, palette.accent)
        views.setTextColor(R.id.widget_v2_configure, palette.accent)
        views.setOnClickPendingIntent(R.id.widget_v2_configure,
            WidgetV2Bridge.routeIntent(context, id, snapshot, null, "configure"))
        views.setViewVisibility(R.id.widget_v2_voice,
            if (overlays && connected && snapshot.optString("lastProjectID").isNotBlank()) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.widget_v2_voice,
            WidgetV2Bridge.routeIntent(context, id, snapshot, null, "voice"))
    }

    private fun bindRows(
        views: RemoteViews,
        state: SessionWidgetSnapshot,
        palette: WidgetV2Style.Palette,
        size: WidgetV2Policy.Size,
        height: Int
    ) {
        val container = if (size == WidgetV2Policy.Size.CARD) R.id.widget_v2_flipper else R.id.widget_v2_rows
        views.removeAllViews(container)
        val rows = SessionWidgetRow(context, id, snapshot, state.connection, palette)
        state.chosenSessions(size, height).forEach { session ->
            views.addView(container, rows.render(session,
                size == WidgetV2Policy.Size.CARD && height >= TODO_HEIGHT, size == WidgetV2Policy.Size.LIST))
        }
    }

    private companion object {
        const val TODO_HEIGHT = 180
    }
}

internal class SessionWidgetSnapshot(private val snapshot: JSONObject) {
    val sessions: List<JSONObject> = visibleSessions()
    val running = snapshot.optInt("runningCount", sessions.count { it.optBoolean("busy") }).coerceAtLeast(0)
    val needs = snapshot.optInt("pendingCount").coerceAtLeast(0)
    val connection: WidgetV2Policy.Connection = connection()

    private fun visibleSessions(): List<JSONObject> {
        val array = snapshot.optJSONArray("sessions")
        val rows = (0 until (array?.length() ?: 0)).mapNotNull { array?.optJSONObject(it) }
            .filter { it.optString("id").isNotBlank() }.take(MAX_SESSIONS)
        val chats = rows.any { it.optJSONObject("team") == null }
        return rows.filter {
            WidgetLayoutPolicy.showRow(it.optJSONObject("team") != null,
                it.optJSONObject("team")?.optString("action").orEmpty(), it.optString("requestID"), chats)
        }.sortedBy {
            if (it.optString("requestID").isNotBlank()) 0 else if (it.optBoolean("busy")) 1 else 2
        }
    }

    private fun connection(): WidgetV2Policy.Connection {
        val receipt = snapshot.optJSONObject("actionResult")
        val onDemandAvailable = sessions.any { session ->
            WidgetV2Policy.onDemandAvailable(
                snapshot.optInt("version"),
                snapshot.optJSONObject("onDemand")?.optString("fingerprint")?.isNotBlank() == true,
                SessionWidgetActions.advertisedActions(session), SessionWidgetActions.validActions(snapshot, session))
        }
        return WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(snapshot.optInt("version"),
            snapshot.optBoolean("connected"), BackgroundConnectionService.active,
            onDemandAvailable, BackgroundConnectionService.widgetActionPending,
            WidgetV2Policy.needsBackgroundSettings(receipt?.optString("status"), receipt?.optString("error"))))
    }

    fun chosenSessions(size: WidgetV2Policy.Size, height: Int): List<JSONObject> =
        if (size == WidgetV2Policy.Size.CARD) {
            if (connection == WidgetV2Policy.Connection.CONNECTED &&
                sessions.firstOrNull()?.optString("requestID").isNullOrBlank()) {
                sessions.filter { it.optBoolean("busy") }.take(MAX_CAROUSEL_SESSIONS).ifEmpty { sessions.take(1) }
            } else sessions.take(1)
        } else sessions.take(WidgetLayoutPolicy.rowCount(height))

    private companion object {
        const val MAX_SESSIONS = 12
        const val MAX_CAROUSEL_SESSIONS = 4
    }
}
