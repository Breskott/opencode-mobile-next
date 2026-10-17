package io.github.eslamasabry.opencode_mobile

import android.app.Notification
import android.content.Context

/**
 * Stands in for the one shared status row. Its own copy and localization are
 * covered by StatusNotificationModelTest; the services only have to ask for
 * the row with their owner and any supplied title.
 */
object StatusNotification {
    const val ID = 4097
    const val OWNER_SERVER = "server"
    val begun = mutableListOf<Pair<String, String?>>()
    private val owners = mutableSetOf<String>()

    fun begin(context: Context, owner: String, title: String?): Notification {
        begun.add(owner to title)
        owners.add(owner)
        return Notification().apply { this.title = title ?: "status-row" }
    }

    /** True when [owner] was the last one holding the row. */
    fun end(context: Context, owner: String): Boolean {
        owners.remove(owner)
        return owners.isEmpty()
    }
}
