package io.github.eslamasabry.opencode_mobile

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Cosmetic per-widget settings do not require a live conversation scope. */
internal class WidgetOverlayStyle(
    private val activity: Activity,
    launch: Map<String, Any?>,
    private val widgetId: Int,
) {
    // A widget may be placed before any profile exists.
    private val owner = (launch["profileID"] as? String)?.takeIf { it.isNotBlank() } ?: WidgetV2Bridge.DEVICE_STYLE_KEY
    private val key = "flutter.oc.widgetStyle.$owner"

    fun read(): Map<String, String> {
        val prefs = activity.getSharedPreferences(WidgetV2Bridge.PREFS, Context.MODE_PRIVATE)
        val saved = runCatching {
            JSONObject(prefs.getString(key, "{}") ?: "{}").optJSONObject(widgetId.toString())
        }.getOrNull()
        return mapOf(
            "background" to (saved?.optString("background", "solid") ?: "solid"),
            "accent" to (saved?.optString("accent", "wallpaper") ?: "wallpaper"),
        )
    }

    fun save(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val background = args?.get("background") as? String
        val accent = args?.get("accent") as? String
        if (background !in setOf("solid", "tinted", "transparent") ||
            accent !in setOf("wallpaper", "app", "green", "amber", "blue", "teal")
        ) {
            result.error("invalidStyle", null, null)
        } else {
            val prefs = activity.getSharedPreferences(WidgetV2Bridge.PREFS, Context.MODE_PRIVATE)
            val styles = runCatching { JSONObject(prefs.getString(key, "{}") ?: "{}") }.getOrElse { JSONObject() }
            styles.put(widgetId.toString(), JSONObject(mapOf("background" to background, "accent" to accent)))
            if (!prefs.edit().putString(key, styles.toString()).commit()) {
                result.error("unavailable", null, null)
            } else {
                SessionsWidgetProvider.refreshAll(activity)
                UsageWidgetProvider.refreshAll(activity)
                activity.setResult(Activity.RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                result.success(mapOf("saved" to true))
                activity.finish()
            }
        }
    }
}
