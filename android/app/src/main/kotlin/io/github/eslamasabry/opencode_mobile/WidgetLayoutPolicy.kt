package io.github.eslamasabry.opencode_mobile

/** Pure layout and presentation rules shared by the widget renderers. */
object WidgetLayoutPolicy {
    private const val MIN_CARD_WIDTH_DP = 120
    private const val MIN_CARD_HEIGHT_DP = 110
    private const val MIN_LIST_WIDTH_DP = 250
    private const val ATTENTION_PERCENT = 20
    private const val LIST_HEADER_HEIGHT_DP = 34
    private const val LIST_ROW_HEIGHT_DP = 36
    private const val MAX_LIST_ROWS = 4

    fun size(widthDp: Int, heightDp: Int): WidgetV2Policy.Size = when {
        widthDp < MIN_CARD_WIDTH_DP || heightDp < MIN_CARD_HEIGHT_DP -> WidgetV2Policy.Size.COMPACT
        widthDp >= MIN_LIST_WIDTH_DP -> WidgetV2Policy.Size.LIST
        else -> WidgetV2Policy.Size.CARD
    }
    fun usageRole(left: Int): String = when {
        left <= 0 -> "neutral"
        left <= ATTENTION_PERCENT -> "attention"
        else -> "running"
    }
    fun chronometerBase(startedAt: Long, wallNow: Long, elapsedNow: Long): Long =
        elapsedNow - (wallNow - startedAt).coerceIn(0L, elapsedNow)
    /** The elapsed timer follows the turn, not the connection: a reply that
     * runs while the widget only connects on tap still shows how long it has run. */
    fun timerTicks(busy: Boolean, startedAt: Long): Boolean = busy && startedAt > 0
    /** A project row from AI Team is not a conversation. With no conversations
     * to show it stays out of the list unless it is waiting on the user. */
    fun showRow(isTeam: Boolean, teamAction: String, requestID: String, anyConversation: Boolean): Boolean =
        !isTeam || anyConversation || teamAction.isNotBlank() || requestID.isNotBlank()
    fun rowCount(heightDp: Int): Int =
        ((heightDp - LIST_HEADER_HEIGHT_DP) / LIST_ROW_HEIGHT_DP).coerceIn(1, MAX_LIST_ROWS)

}
