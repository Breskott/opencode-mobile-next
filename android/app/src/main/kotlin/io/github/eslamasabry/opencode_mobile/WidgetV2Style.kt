package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject

/** Per-widget presentation only. State colours deliberately never use the error/red role. */
object WidgetV2Style {
    private const val RUNNING_DARK = -9185633
    private const val RUNNING_LIGHT = -15242421
    private const val ATTENTION_DARK = -1524381
    private const val ATTENTION_LIGHT = -7642624
    private const val ACCENT_GREEN = -12014481
    private const val ACCENT_AMBER = -4553696
    private const val ACCENT_BLUE = -12482611
    private const val ACCENT_TEAL = -14317693
    private const val LIGHT_TEXT_THRESHOLD = 128
    private const val USAGE_BLEND_START = 20
    private const val USAGE_BLEND_RANGE = 80f
    private const val BACKGROUND_TINT_FRACTION = 0.16f
    private const val HSV_COMPONENT_COUNT = 3
    private const val RED_SATURATION_THRESHOLD = 0.2f
    private const val RED_HUE_LOW = 30f
    private const val RED_HUE_HIGH = 330f

    data class Palette(val background: Int, val text: Int, val muted: Int, val accent: Int) {
        val running: Int = if (Color.red(text) > LIGHT_TEXT_THRESHOLD) RUNNING_DARK else RUNNING_LIGHT
        val attention: Int = if (Color.red(text) > LIGHT_TEXT_THRESHOLD) ATTENTION_DARK else ATTENTION_LIGHT
        val neutral: Int get() = muted
        fun usage(left: Int): Int {
            if (WidgetLayoutPolicy.usageRole(left) == "neutral") return neutral
            val amount = ((left - USAGE_BLEND_START) / USAGE_BLEND_RANGE).coerceIn(0f, 1f)
            return blend(attention, running, amount)
        }
    }

    fun palette(context: Context, widgetId: Int, snapshot: JSONObject?): Palette {
        val style = savedStyle(context, widgetId, snapshot?.optString("profileID").orEmpty())
        val theme = snapshot?.optJSONObject("appTheme")
        val dark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
        val appBackground = themeColor(context, theme, "background", R.color.widgetBackground)
        val appText = themeColor(context, theme, "text", R.color.widgetText)
        val appMuted = themeColor(context, theme, "muted", R.color.widgetHint)
        val appAccent = themeColor(context, theme, "accent", R.color.widgetAccent)
        val wallpaper = style.optString("accent", "wallpaper") == "wallpaper" &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        val accent = accent(context, style, dark, wallpaper, appAccent)
        val base = if (wallpaper) context.getColor(
            if (dark) android.R.color.system_neutral1_900 else android.R.color.system_neutral1_50
        ) else appBackground
        val background = when (style.optString("background", "solid")) {
            "transparent" -> Color.TRANSPARENT
            "tinted" -> blend(base, accent, BACKGROUND_TINT_FRACTION)
            else -> base
        }
        return Palette(background, if (wallpaper) context.getColor(
            if (dark) android.R.color.system_neutral1_50 else android.R.color.system_neutral1_900
        ) else appText, appMuted, accent)
    }

    private fun themeColor(context: Context, theme: JSONObject?, key: String, fallback: Int): Int =
        theme?.optLong(key)?.takeIf { it != 0L }?.toInt() ?: context.getColor(fallback)

    private fun savedStyle(context: Context, widgetId: Int, profile: String): JSONObject {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        fun saved(key: String): JSONObject? = try {
            JSONObject(prefs.getString("flutter.oc.widgetStyle.$key", "{}") ?: "{}")
                .optJSONObject(widgetId.toString())
        } catch (_: Exception) { null }
        // A widget styled before the app published its first snapshot keeps
        // that style under the device key until its profile saves one.
        return (if (profile.isNotBlank()) saved(profile) else null)
            ?: saved(WidgetV2Bridge.DEVICE_STYLE_KEY) ?: JSONObject()
    }

    private fun accent(
        context: Context,
        style: JSONObject,
        dark: Boolean,
        wallpaper: Boolean,
        appAccent: Int
    ): Int {
        return when (style.optString("accent", "wallpaper")) {
            "green" -> ACCENT_GREEN
            "amber" -> ACCENT_AMBER
            "blue" -> ACCENT_BLUE
            "teal" -> ACCENT_TEAL
            "wallpaper" -> if (wallpaper) context.getColor(
                if (dark) android.R.color.system_accent1_200 else android.R.color.system_accent1_700
            ) else appAccent
            else -> appAccent
        }.let { noRed(it) }
    }

    fun apply(context: Context, views: RemoteViews, widgetId: Int, snapshot: JSONObject? = null) {
        val palette = palette(context, widgetId, snapshot)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorStateList(
                android.R.id.background, "setBackgroundTintList", ColorStateList.valueOf(palette.background)
            )
        } else {
            views.setInt(android.R.id.background, "setBackgroundColor", palette.background)
        }
    }

    private fun noRed(color: Int): Int {
        val hsv = FloatArray(HSV_COMPONENT_COUNT)
        Color.colorToHSV(color, hsv)
        return if (hsv[1] > RED_SATURATION_THRESHOLD && (hsv[0] < RED_HUE_LOW || hsv[0] > RED_HUE_HIGH))
            RUNNING_LIGHT else color
    }

    private fun blend(a: Int, b: Int, fraction: Float): Int = Color.rgb(
        (Color.red(a) + (Color.red(b) - Color.red(a)) * fraction).toInt(),
        (Color.green(a) + (Color.green(b) - Color.green(a)) * fraction).toInt(),
        (Color.blue(a) + (Color.blue(b) - Color.blue(a)) * fraction).toInt()
    )
}
