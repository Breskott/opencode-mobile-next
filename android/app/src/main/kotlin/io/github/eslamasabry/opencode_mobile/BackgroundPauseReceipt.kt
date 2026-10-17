package io.github.eslamasabry.opencode_mobile

/** Only fixed categories and timestamps are persisted; no OS description. */
data class BackgroundPauseReceipt(
    val phase: String = "none",
    val reason: String = "none",
    val at: Long = 0L,
)

data class BackgroundPauseExit(val reason: Int, val at: Long)

object BackgroundPausePolicy {
    const val TIME_LIMIT = "timeLimit"
    const val BATTERY_RESTRICTED = "batteryRestricted"
    const val USER_STOPPED = "userStopped"
    const val INTERRUPTED = "interrupted"
    const val APP_UPDATED = "appUpdated"
    private const val USER_REQUESTED_EXIT = 10
    private const val USER_STOPPED_EXIT = 11
    private const val PACKAGE_UPDATED_EXIT = 16

    fun reconcile(
        receipt: BackgroundPauseReceipt,
        active: Boolean,
        restricted: Boolean,
        exit: BackgroundPauseExit?,
        now: Long,
    ): BackgroundPauseReceipt {
        return when {
            active -> if (receipt.phase == "running") receipt else BackgroundPauseReceipt("running", at = now)
            receipt.phase != "running" -> {
                // A current-policy statement must not become a historical cause.
                if (receipt.reason == BATTERY_RESTRICTED && !restricted) {
                    receipt.copy(reason = INTERRUPTED)
                } else receipt
            }
            else -> {
                val reason = when {
                    restricted -> BATTERY_RESTRICTED
                    isExitAfter(exit, receipt.at, USER_REQUESTED_EXIT, USER_STOPPED_EXIT) -> USER_STOPPED
                    // An app update ends the process: a known cause, not "unknown".
                    isExitAfter(exit, receipt.at, PACKAGE_UPDATED_EXIT) -> APP_UPDATED
                    else -> INTERRUPTED
                }
                // Battery policy is observed now. The exit timestamp is evidence
                // only when it actually followed this receipt's running period.
                val at = if (reason == USER_STOPPED || reason == APP_UPDATED) checkNotNull(exit).at else now
                BackgroundPauseReceipt("paused", reason, at)
            }
        }
    }

    private fun isExitAfter(exit: BackgroundPauseExit?, startedAt: Long, vararg reasons: Int): Boolean =
        exit != null && exit.at > startedAt && exit.reason in reasons
}
