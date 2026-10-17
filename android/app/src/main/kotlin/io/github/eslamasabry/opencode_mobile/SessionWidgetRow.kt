package io.github.eslamasabry.opencode_mobile

import android.app.PendingIntent
import android.content.Context
import android.content.res.ColorStateList
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/** A session row binds cached status and controls without changing the snapshot. */
internal class SessionWidgetRow(
    private val context: Context,
    private val id: Int,
    private val snapshot: JSONObject,
    private val connection: WidgetV2Policy.Connection,
    private val palette: WidgetV2Style.Palette
) {
    fun render(session: JSONObject, showTodos: Boolean, list: Boolean): RemoteViews {
        val state = SessionWidgetRowState(session, snapshot, connection, palette)
        val layout = if (list) R.layout.widget_session_v2_list_row else R.layout.widget_session_v2_row
        val views = RemoteViews(context.packageName, layout)
        val open = SessionWidgetIntents.chatIntent(context, id, snapshot, session)
        bindHeader(views, state)
        views.setOnClickPendingIntent(R.id.widget_v2_card, open)
        bindProgress(views, state)
        bindTasks(views, state, showTodos)
        bindTodos(views, state, showTodos, open)
        bindActions(views, state)
        return views
    }

    private fun bindHeader(views: RemoteViews, state: SessionWidgetRowState) {
        views.setTextViewText(R.id.widget_v2_title, state.session.optString("title").take(MAX_STATUS_LENGTH))
        views.setTextColor(R.id.widget_v2_title, palette.text)
        views.setTextColor(R.id.widget_v2_step, state.stateColor)
        views.setTextColor(R.id.widget_v2_timer, state.stateColor)
        views.setTextColor(R.id.widget_v2_tasks, palette.muted)
        val rowConnection = if (state.rowNeedsSettings) WidgetV2Policy.Connection.BACKGROUND_SETTINGS else connection
        views.setTextViewText(R.id.widget_v2_step, when (rowConnection) {
            WidgetV2Policy.Connection.CONNECTED -> state.session.optString("step").take(MAX_STATUS_LENGTH)
            WidgetV2Policy.Connection.ON_DEMAND -> NativeStrings.get(context, R.string.widget_v2_on_demand)
            WidgetV2Policy.Connection.PENDING -> NativeStrings.get(context, R.string.widget_v2_pending)
            else -> NativeStrings.get(context, R.string.widget_v2_offline)
        })
    }

    private fun bindProgress(views: RemoteViews, state: SessionWidgetRowState) {
        val started = state.session.optLong("startedAt")
        views.setViewVisibility(R.id.widget_v2_timer,
            if (WidgetLayoutPolicy.timerTicks(state.busy, started)) View.VISIBLE else View.GONE)
        views.setChronometer(R.id.widget_v2_timer, WidgetLayoutPolicy.chronometerBase(started,
            System.currentTimeMillis(), SystemClock.elapsedRealtime()),
            NativeStrings.get(context, R.string.widget_v2_working, "%s"),
            WidgetLayoutPolicy.timerTicks(state.busy, started))
        views.setViewVisibility(R.id.widget_v2_progress, if (state.busy && state.connected) View.VISIBLE else View.GONE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorStateList(R.id.widget_v2_progress,
                "setIndeterminateTintList", ColorStateList.valueOf(state.stateColor))
        }
    }

    private fun bindTasks(views: RemoteViews, state: SessionWidgetRowState, showTodos: Boolean) {
        val total = state.total
        val done = state.team?.optInt("done") ?: state.session.optInt("tasksDone")
        views.setViewVisibility(R.id.widget_v2_tasks, if (total > 0 && showTodos) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.widget_v2_tasks, NativeStrings.get(context, R.string.widget_v2_tasks,
            done.coerceIn(0, total.coerceAtLeast(0)), total.coerceAtLeast(0)))
        if (total > 0 && !showTodos && state.connected) {
            views.setTextViewText(R.id.widget_v2_step,
                NativeStrings.get(context, R.string.widget_v2_tasks, done.coerceIn(0, total), total))
        }
    }

    private fun bindTodos(
        views: RemoteViews,
        state: SessionWidgetRowState,
        showTodos: Boolean,
        open: PendingIntent
    ) {
        views.removeAllViews(R.id.widget_v2_todos)
        if (showTodos) {
            val todos = state.session.optJSONArray("todos")
            for (i in 0 until minOf(todos?.length() ?: 0, if (state.total > 0) 1 else 2)) {
                val todo = todos?.optJSONObject(i) ?: continue
                views.addView(R.id.widget_v2_todos, todoRow(todo, open))
            }
        }
    }

    private fun todoRow(todo: JSONObject, open: PendingIntent): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.widget_v2_todo)
        val checked = todo.optBoolean("done")
        val title = todo.optString("title").take(MAX_TODO_LENGTH)
        row.setTextViewText(R.id.widget_v2_todo,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) title else "${if (checked) "☑" else "☐"} $title")
        row.setTextColor(R.id.widget_v2_todo, palette.text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            row.setCompoundButtonChecked(R.id.widget_v2_todo, checked)
            row.setColorStateList(R.id.widget_v2_todo, "setButtonTintList", ColorStateList.valueOf(palette.running))
            // Reflection only: prevent local checkbox changes while its row opens chat.
            row.setBoolean(R.id.widget_v2_todo, "setClickable", false)
        }
        row.setOnClickPendingIntent(R.id.widget_v2_todo_row, open)
        return row
    }

    private fun bindActions(views: RemoteViews, state: SessionWidgetRowState) {
        views.setViewVisibility(R.id.widget_v2_primary, View.GONE)
        views.setViewVisibility(R.id.widget_v2_secondary, View.GONE)
        val actions = SessionWidgetRowActions(context, id, snapshot, connection, state)
        when {
            state.rowNeedsSettings -> {
                views.setViewVisibility(R.id.widget_v2_primary, View.VISIBLE)
                views.setTextViewText(R.id.widget_v2_primary,
                    NativeStrings.get(context, R.string.widget_v2_background_settings))
                views.setTextColor(R.id.widget_v2_primary, palette.accent)
                views.setOnClickPendingIntent(R.id.widget_v2_primary,
                    SessionWidgetIntents.backgroundSettingsIntent(context, id))
            }
            state.request -> {
                actions.bind(views, R.id.widget_v2_primary, R.string.widget_v2_allow, "allowOnce")
                actions.bind(views, R.id.widget_v2_secondary, R.string.widget_v2_reject, "reject")
            }
            state.team?.optString("action") == "approvePlan" ->
                actions.bind(views, R.id.widget_v2_primary, R.string.widget_v2_approve, "approvePlan")
            state.team?.optString("action") == "resume" ->
                actions.bind(views, R.id.widget_v2_primary, R.string.widget_v2_resume, "resume")
            state.busy -> actions.bindBusy(views)
        }
    }

    private companion object {
        const val MAX_STATUS_LENGTH = 100
        const val MAX_TODO_LENGTH = 80
    }
}

internal class SessionWidgetRowState(
    val session: JSONObject,
    snapshot: JSONObject,
    connection: WidgetV2Policy.Connection,
    palette: WidgetV2Style.Palette
) {
    val connected = connection == WidgetV2Policy.Connection.CONNECTED
    val valid = SessionWidgetActions.validActions(snapshot, session)
    val advertised = if (snapshot.optJSONObject("onDemand")?.optString("fingerprint")?.isNotBlank() == true)
        SessionWidgetActions.advertisedActions(session) else emptySet()
    val rowNeedsSettings = connection == WidgetV2Policy.Connection.ON_DEMAND &&
        SessionWidgetActions.candidateActions(session).isNotEmpty() && valid.none { it in advertised }
    val busy = session.optBoolean("busy")
    val request = session.optString("requestID").isNotBlank()
    val stateColor = if (request) palette.attention else if (busy) palette.running else palette.neutral
    val team = session.optJSONObject("team")
    val total = team?.optInt("total") ?: session.optInt("tasksTotal")
}

internal class SessionWidgetRowActions(
    private val context: Context,
    private val id: Int,
    private val snapshot: JSONObject,
    private val connection: WidgetV2Policy.Connection,
    private val state: SessionWidgetRowState
) {
    fun bind(views: RemoteViews, viewId: Int, label: Int, name: String, route: Boolean = false) {
        // Overlay controls still need a live engine. Background actions
        // carry only cached identity; dispatch reconciles it afresh.
        val enabled = if (route) state.connected else
            WidgetV2Policy.actionEnabled(connection, name, state.advertised, name in state.valid)
        if (enabled) {
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setTextViewText(viewId, NativeStrings.get(context, label))
            views.setTextColor(viewId, state.stateColor)
            views.setOnClickPendingIntent(viewId,
                if (route) WidgetV2Bridge.routeIntent(context, id, snapshot, state.session, name)
                else WidgetV2Bridge.actionIntent(context, id, snapshot, state.session, name))
        }
    }

    fun bindBusy(views: RemoteViews) {
        bind(views, R.id.widget_v2_primary, R.string.widget_v2_stop, "stop")
        if (WidgetV2Bridge.overlayReady(context) &&
            state.session.optString("steerMode") in setOf("steer", "afterReply")) {
            bind(views, R.id.widget_v2_secondary,
                if (state.session.optString("steerMode") == "afterReply") R.string.widget_v2_after_reply
                else R.string.widget_v2_steer, "steer", true)
        }
    }
}
