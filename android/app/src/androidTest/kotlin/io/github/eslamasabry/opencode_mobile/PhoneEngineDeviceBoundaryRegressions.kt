package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.os.SystemClock
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

/** No models, credential reads, fake receipts, or authority from diagnostics. */
internal object PhoneEngineDeviceBoundaryRegressions {
    private val controls = listOf(
        "positiveWrite", "positiveGit", "directOpenDenied", "directStatDenied",
        "directReadlinkDenied", "procSelfRootDenied", "procParentRootDenied",
        "parentEnvironDenied", "parentCmdlineDenied", "fdHygiene",
        "tracerEscapeDenied", "complete",
    )

    /** The preview activity must be foregrounded by its instrumentation runner. */
    fun run(context: Context, bootstrap: Boolean = true): Map<String, Any?> {
        check(context.packageName == "io.github.eslamasabry.opencode_mobile.preview") {
            "preview_required"
        }
        val linux = BuiltinLinux.get(context)
        check(linux.runningServices().isEmpty()) { "idle_runtime_required" }
        check(LocalTerminal.get(context).list().none { it.running }) { "idle_terminals_required" }
        if (!linux.installed) {
            check(bootstrap) { "ubuntu_not_initialized" }
            // The pinned installer verifies its archive; deliberately discard logs.
            linux.install(log = {})
        }
        val git = linux.run(if (bootstrap) """
            set -eu
            command -v git >/dev/null 2>&1 || {
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -qq >/dev/null 2>&1
                apt-get install -y -qq git >/dev/null 2>&1
            }
            command -v git >/dev/null 2>&1
        """.trimIndent() else "command -v git >/dev/null 2>&1", 180)
        check(git.exitCode == 0) { "git_not_initialized" }

        val kernelExit = kernelProbe(context)
        val diagnostic = linux.runProotViewBoundaryProbe()
        check(diagnostic["positiveWrite"] == true) { "positive_write_failed" }
        check(diagnostic["positiveGit"] == true) { "positive_git_failed" }
        check(controls.all { diagnostic[it] is Boolean }) { "diagnostic_controls_missing" }
        // Preserve the actual controls. Their conjunction is evidence only.
        val result = linkedMapOf<String, Any?>(
            "kernelProbeStable" to true,
            "kernelExit" to kernelExit,
            "landlockAvailable" to (kernelExit == 0),
            "ubuntuInitialized" to true,
        )
        controls.forEach { result[it] = diagnostic[it] }
        val complete = controls.filter { it != "complete" }.all { diagnostic[it] == true }
        check(diagnostic["complete"] == complete) { "diagnostic_complete_inconsistent" }

        val profile = "qa_device_${UUID.randomUUID().toString().replace("-", "")}"
        val script = "exec sleep 600"
        var ownsService = false
        try {
            check(linux.phoneEngineStatus(profile)["unconfinedChildren"] == false) {
                "idle_processes_required"
            }
            // Exercise the same tracked stop/activation/restart sequence as setup,
            // without a real server, port listener, model, or provider password.
            linux.startServer(script, 4097)
            ownsService = true
            waitUntil(5_000, "fixture_service_not_running") { linux.serverRunning }
            linux.stopServer()
            check(!linux.serverRunning) { "fixture_service_not_stopped" }
            var unsupported = false
            val started = SystemClock.elapsedRealtime()
            try {
                val status = linux.startPhoneEngine(profile, 4098, null)
                check(kernelExit == 0) { "unsupported_kernel_activated_engine" }
                check(status["running"] == true && status["boundary"] == true) {
                    "production_boundary_not_verified"
                }
                result["productionBoundaryVerified"] = true
            } catch (failure: PhoneEngineNative.Failure) {
                check(kernelExit == 78 && failure.code == "boundary_unsupported") {
                    "unsupported_failure_code_invalid"
                }
                unsupported = true
                result["typedUnsupported"] = true
            }
            check(SystemClock.elapsedRealtime() - started < 90_000) { "activation_timeout" }
            if (unsupported) {
                val status = linux.phoneEngineStatus(profile)
                check(status["running"] != true && status["boundary"] != true &&
                    status["execution"] != true) { "unsupported_authority_enabled" }
                waitUntil(10_000, "failed_activation_did_not_restore_server") { linux.serverRunning }
                result["failedActivationRestoredServer"] = true
            } else {
                // This branch remains useful on genuinely supported phones;
                // it does not weaken the API 34/35 unsupported assertions.
                linux.stopPhoneEngine(profile)
                linux.startServer(script, 4097)
            }
            Thread.sleep(300)
            val before = linux.serverUptimeMs ?: error("fixture_service_uptime_missing")
            linux.startServer(script, 4097)
            val after = linux.serverUptimeMs ?: error("fixture_service_uptime_missing")
            check(after >= before) { "identical_server_start_rotated_process" }
            result["serverRestartIdempotent"] = true
            return result
        } finally {
            // Attempt every cleanup even if an earlier one fails. Never kill by
            // pattern or stop a service that existed before this isolated run.
            try { linux.stopPhoneEngine(profile) } finally {
                try { linux.deletePhoneEngine(profile) } finally {
                    if (ownsService) linux.stopServer()
                }
            }
        }
    }

    private fun kernelProbe(context: Context): Int {
        PhoneEngineNative.verifyBundle(context, "libaiteam_sandbox.so")
        val binary = File(context.applicationInfo.nativeLibraryDir, "libaiteam_sandbox.so")
        val process = ProcessBuilder(binary.absolutePath, "--check-kernel")
            .redirectOutput(ProcessBuilder.Redirect.to(File("/dev/null")))
            .redirectError(ProcessBuilder.Redirect.to(File("/dev/null")))
            .apply { environment().clear() }.start()
        try {
            process.outputStream.close()
            check(process.waitFor(15, TimeUnit.SECONDS)) { "kernel_probe_timeout" }
            return process.exitValue().also {
                check(it == 0 || it == 78) { "kernel_probe_signalled_or_invalid" }
            }
        } finally {
            if (process.isAlive) process.destroyForcibly()
            process.waitFor(2, TimeUnit.SECONDS)
        }
    }

    private fun waitUntil(timeoutMs: Long, safeCode: String, ready: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        while (!ready()) {
            check(SystemClock.elapsedRealtime() < deadline) { safeCode }
            Thread.sleep(50)
        }
    }
}
