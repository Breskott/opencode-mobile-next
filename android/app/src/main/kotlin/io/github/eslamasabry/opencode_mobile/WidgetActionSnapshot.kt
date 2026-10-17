package io.github.eslamasabry.opencode_mobile

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Whitelisted action settlement patches; never persists arbitrary plugin data. */
internal object WidgetActionSnapshot {
    fun apply(context: Context, payload: Map<String, Any?>, value: Map<*, *>?) {
        if (value == null) return
        val current = WidgetV2Bridge.snapshot(context) ?: return
        if (matchesScope(current, payload, value)) {
            val rows = current.optJSONArray("sessions")
            val updated = if (rows != null) {
                (value["sessions"] as? List<*>)?.filterIsInstance<Map<*, *>>()
            } else null
            if (rows != null && updated != null && patchRows(context, payload, rows, updated)) {
                save(context, current, rows)
            }
        }
    }

    private fun matchesScope(current: JSONObject, payload: Map<String, Any?>, value: Map<*, *>): Boolean =
        current.optString("profileID") == payload["profileID"] &&
            current.optString("scopeToken") == payload["scopeToken"] && matchesPatchScope(payload, value)

    private fun matchesPatchScope(payload: Map<String, Any?>, value: Map<*, *>): Boolean =
        value["profileID"] == payload["profileID"] && value["scopeToken"] == payload["scopeToken"] &&
            value["version"] == 2

    private fun patchRows(
        context: Context,
        payload: Map<String, Any?>,
        rows: JSONArray,
        updated: List<Map<*, *>>,
    ): Boolean {
        for (index in 0 until rows.length()) {
            val row = rows.optJSONObject(index)
            if (row != null && row.optString("id") == payload["sessionID"]) {
                // A concurrent foreground update wins over the old action result.
                if (WidgetActionPolicy.validate(payload, WidgetV2Bridge.currentIdentity(context, payload)) != null) {
                    return false
                }
                updated.firstOrNull { it["id"] == payload["sessionID"] }?.let { patchRow(row, payload, it) }
            }
        }
        return true
    }

    private fun patchRow(row: JSONObject, payload: Map<String, Any?>, patch: Map<*, *>) {
        (patch["busy"] as? Boolean)?.let { row.put("busy", it) }
        // Only removal of an answered request is permitted here.
        if ((patch["requestID"] as? String).isNullOrEmpty()) row.remove("requestID")
        if (patch["busy"] == false) row.remove("startedAt")
        if (payload["action"] in setOf("approvePlan", "resume") &&
            (patch["team"] as? Map<*, *>)?.get("action").let { it == null || it == "" }
        ) {
            row.optJSONObject("team")?.remove("action")
        }
        val allowed = (patch["onDemandActions"] as? List<*>)?.filterIsInstance<String>()
            ?.filter { it in WidgetActionLease.actions }
        if (allowed != null) row.put("onDemandActions", JSONArray(allowed))
    }

    private fun save(context: Context, current: JSONObject, rows: JSONArray) {
        current.put("connected", BackgroundConnectionService.active && current.optBoolean("connected"))
        current.put("runningCount", (0 until rows.length()).count {
            rows.optJSONObject(it)?.optBoolean("busy") == true
        })
        current.put("pendingCount", (0 until rows.length()).count {
            !rows.optJSONObject(it)?.optString("requestID").isNullOrEmpty()
        })
        context.getSharedPreferences(WidgetV2Bridge.PREFS, Context.MODE_PRIVATE).edit()
            .putString(WidgetV2Bridge.SNAPSHOT_KEY, current.toString()).commit()
    }
}
