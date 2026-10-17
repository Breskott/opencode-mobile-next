package io.github.eslamasabry.opencode_mobile

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

private data class InstallerTicket(val id: String, val observed: List<Int> = emptyList())
private data class Drain(val server: List<Int>)

private class FixtureProcess : Process() {
    var live = true
    override fun isAlive() = live
    override fun getInputStream() = ByteArrayInputStream(byteArrayOf())
    override fun getErrorStream() = ByteArrayInputStream(byteArrayOf())
    override fun getOutputStream() = ByteArrayOutputStream()
    override fun waitFor(): Int { check(!live); return 0 }
    override fun exitValue(): Int { check(!live); return 0 }
    override fun destroy() { error("only the exact drain stub may stop this fixture") }
}

private class BuiltinLinux(private val scenario: String) {
    private val componentUpdateFailure = "A component update could not be restored. Run setup again."
    private val installerGuard = Any()
    @Volatile private var installerProcess: Process? = null
    private var installerLaunchId: String? = null
    // Kept in the fixture even when extracting the pre-fix production source:
    // the base must compile and fail the behavior assertion, not compilation.
    private var installerMonitorFailure: Throwable? = null
    private var componentUpdatesRecovered = true
    private var ticket: InstallerTicket? = null
    private val observedFailure = IllegalStateException("ownershipUnknown")
    private val monitorReached = CountDownLatch(1)
    private val first = FixtureProcess()
    private val second = FixtureProcess()
    private var drains = 0
    private var clears = 0
    private var releases = 0
    private val workLeases = object {
        fun release(process: Process) { check(process === first || process === second); releases++ }
    }
    private val installerPreferences = object {
        fun edit() = Editor()
    }
    private inner class Editor {
        fun remove(key: String): Editor { check(key == "ticket"); return this }
        fun commit(): Boolean { ticket = null; clears++; return true }
    }
    private fun installerTicket() = ticket
    private fun saveInstaller(value: InstallerTicket) { ticket = value }
    private fun liveInstallerPlan(candidate: InstallerTicket, process: Process, nonce: String): Drain {
        check(process === first && candidate.id == "first" && nonce == "first")
        if (scenario == "stale-monitor-new-launch") {
            // Deterministic replacement at the observation/catch boundary.
            // The catch must recheck the exact launch before recording failure.
            first.live = false
            select(second, "second")
            monitorReached.countDown()
        }
        throw observedFailure
    }
    private fun drainInstaller(candidate: InstallerTicket, process: Process, nonce: String) {
        check(installerProcess === process && installerLaunchId == nonce && ticket == candidate)
        (process as FixtureProcess).live = false
        drains++
        monitorReached.countDown()
    }
    private fun select(process: FixtureProcess, nonce: String) {
        check(Thread.holdsLock(this))
        installerProcess = process
        installerLaunchId = nonce
        ticket = InstallerTicket(nonce)
    }
    fun verify() {
        synchronized(this) {
            select(first, "first")
            monitorInstallerOwnership(first, "first", ticket!!)
        }
        check(monitorReached.await(3, TimeUnit.SECONDS)) { "monitor never reached its injected failure" }
        synchronized(this) {
            if (scenario == "stale-monitor-new-launch") {
                // The old monitor still needs to reacquire this lock for its
                // catch. Let it finish before checking the new launch below.
            } else {
                check(first.exitValue() == 0) { "fixture must model PRoot zero exit after guest termination" }
                val failure = runCatching { finishInstaller(first) }.exceptionOrNull()
                check(failure != null) { "ownership monitor termination was reported as successful setup" }
                check(generateSequence(failure) { it.cause }.any { it === observedFailure }) {
                    "monitor failure cause was lost"
                }
                check(installerProcess == null && installerLaunchId == null && ticket == null) {
                    "failed launch blocked an in-app retry"
                }
                check(installerMonitorFailure == null && clears == 1 && drains == 2 && releases == 1)
                check(!componentUpdatesRecovered) { "retry skipped interrupted component recovery" }
                if (scenario == "retry-same-runtime") {
                    select(second, "second")
                    second.live = false
                    finishInstaller(second)
                    check(installerProcess == null && ticket == null && clears == 2 && releases == 2)
                }
            }
        }
        if (scenario == "stale-monitor-new-launch") {
            // Join by exact thread identity; no sleep-based race assertions.
            val monitor = Thread.getAllStackTraces().keys.singleOrNull {
                it.name == "phone-installer-ownership" && it.isAlive
            }
            monitor?.join(3000)
            check(monitor?.isAlive != true) { "stale monitor did not exit" }
            synchronized(this) {
                check(installerProcess === second && installerLaunchId == "second" && second.live)
                check(installerMonitorFailure == null && drains == 0 && clears == 0)
                second.live = false
                finishInstaller(second)
                check(installerProcess == null && ticket == null && clears == 1)
            }
        }
    }
    /* PRODUCTION_MONITOR */
    /* PRODUCTION_FINISH */
    companion object { private const val OWNERSHIP_POLL_MS = 1L }
}

fun main(args: Array<String>) {
    val scenario = args.single()
    BuiltinLinux(scenario).verify()
    println("PASS $scenario")
}
