package io.github.eslamasabry.opencode_mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import org.json.JSONObject

/** Event-driven, privacy-safe snapshot renderer. Never opens a network connection. */
class SessionsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, buildViews(context, it, manager.getAppWidgetOptions(it))) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        manager.updateAppWidget(id, buildViews(context, id, options))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetV2Bridge.deleteWidgets(context, ids)
    }

    companion object {
        private const val COMPACT_EDGE = 40
        private const val CARD_WIDTH = 120
        private const val LIST_WIDTH = 250
        private const val SHORT_HEIGHT = 110
        private const val TODO_HEIGHT = 180
        private const val TALL_HEIGHT = 280

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, SessionsWidgetProvider::class.java)).forEach {
                manager.updateAppWidget(it, buildViews(context, it, manager.getAppWidgetOptions(it)))
            }
        }

        private fun readSnapshot(context: Context): JSONObject = try {
            JSONObject(context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.oc.widgetSessions", "{}") ?: "{}")
        } catch (_: Exception) { JSONObject() }

        private fun buildViews(context: Context, id: Int, options: Bundle): RemoteViews {
            val snapshot = readSnapshot(context)
            val renderer = SessionWidgetRenderer(context, id, snapshot)
            fun variant(width: Int, height: Int) =
                SizeF(width.toFloat(), height.toFloat()) to renderer.render(width, height)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return RemoteViews(linkedMapOf(
                    variant(COMPACT_EDGE, COMPACT_EDGE),
                    variant(CARD_WIDTH, SHORT_HEIGHT),
                    variant(CARD_WIDTH, TODO_HEIGHT),
                    variant(LIST_WIDTH, SHORT_HEIGHT),
                    variant(LIST_WIDTH, TODO_HEIGHT),
                    variant(LIST_WIDTH, TALL_HEIGHT)
                ))
            }
            return renderer.render(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, CARD_WIDTH),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, SHORT_HEIGHT))
        }
    }
}
