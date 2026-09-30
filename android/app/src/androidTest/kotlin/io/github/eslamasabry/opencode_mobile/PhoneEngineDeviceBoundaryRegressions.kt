package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.os.SystemClock
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

/** No models, credential reads, fake receipts, or authority from diagnostics. */
internal object PhoneEngineDeviceBoundaryRegressions {
    private val controls = listOf(
        "positiveWrite", "positiveRead", "positiveGit", "positiveStat", "positiveReadlink", "positiveTracerIdentity", "workerAliasDenied", "fixtureUnchanged", "directOpenDenied", "directStatDenied",
        "directReadlinkDenied", "procSelfRootDenied", "procParentRootDenied",
        "parentEnvironDenied", "parentCmdlineDenied", "fdHygiene",
        "tracerEscapeDenied", "complete",
    )

    /** The preview activity must be foregrounded by its instrumentation runner. */
    fun run(context: Context, bootstrap: Boolean = true, onStage: (String) -> Unit = {}): Map<String, Any?> {
        check(context.packageName == "io.github.eslamasabry.opencode_mobile.preview") {
            "preview_required"
        }
        val linux = BuiltinLinux.get(context)
        check(linux.runningServices().isEmpty()) { "idle_runtime_required" }
        check(LocalTerminal.get(context).list().none { it.running }) { "idle_terminals_required" }
        if (!linux.installed) {
            onStage("bootstrap_ubuntu")
            check(bootstrap) { "ubuntu_not_initialized" }
            // The pinned installer verifies its archive; deliberately discard logs.
            linux.install(log = {})
        }
        onStage("bootstrap_git")
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

        onStage("kernel_probe")
        val kernelExit = kernelProbe(context)
        val profile = "qa_device_${UUID.randomUUID().toString().replace("-", "")}"
        val result = linkedMapOf<String, Any?>("kernelProbeStable" to true,
            "kernelExit" to kernelExit, "landlockAvailable" to (kernelExit == 0))
        val passwordFile = File(linux.rootfs, "root/.oc-builtin/server.password")
        val createdPassword = !passwordFile.exists()
        if (createdPassword) {
            passwordFile.parentFile!!.mkdirs()
            val bytes = ByteArray(32).also { java.security.SecureRandom().nextBytes(it) }
            passwordFile.writeText(bytes.joinToString("") { "%02x".format(it.toInt() and 255) })
            android.system.Os.chmod(passwordFile.absolutePath, 384)
        }
        var ownsService = false
        val script = """
            set -eu
            mkdir -p /root/projects
            cd /root/projects
            password=${'$'}(cat /root/.oc-builtin/server.password)
            export OPENCODE_SERVER_USERNAME=opencode
            export OPENCODE_SERVER_PASSWORD="${'$'}password"
            export OPENCODE_PASSWORD="${'$'}password"
            unset password
            exec opencode serve --hostname 127.0.0.1 --port 4097
        """.trimIndent()
        try {
            onStage("bootstrap_opencode")
            val installed = linux.run("""
                set -eu
                if ! command -v opencode >/dev/null 2>&1; then
                    export DEBIAN_FRONTEND=noninteractive
                    command -v curl >/dev/null 2>&1 || {
                        apt-get update -qq >/dev/null 2>&1
                        apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null 2>&1
                    }
                    case "${'$'}(uname -m)" in
                        x86_64) archive=opencode-linux-x64-baseline.tar.gz; expected=763af386ef88a8cab18df00fcf055690e5a55e31a7088beabe02307142a6adce;;
                        aarch64) archive=opencode-linux-arm64.tar.gz; expected=568461b7d4d8c19865c97e9a1102e613049c6039d01fe772154de873c1865840;;
                        *) exit 78;;
                    esac
                    curl --fail --location --retry 3 --max-time 180 --silent --show-error "https://github.com/anomalyco/opencode/releases/download/v1.18.32/${'$'}archive" -o /tmp/phone-engine-qa-opencode.tar.gz >/dev/null 2>&1
                    printf '%s  %s\n' "${'$'}expected" /tmp/phone-engine-qa-opencode.tar.gz | sha256sum -c - >/dev/null 2>&1
                    tar -xzf /tmp/phone-engine-qa-opencode.tar.gz -C /usr/local/bin opencode
                    chmod 755 /usr/local/bin/opencode
                    rm -f /tmp/phone-engine-qa-opencode.tar.gz
                fi
                [ "${'$'}(opencode --version 2>/dev/null)" = '1.18.32' ]
            """.trimIndent(), 300)
            check(installed.exitCode == 0) { "opencode_not_initialized" }
            onStage("activation_proof")
            linux.startServer(script, 4097)
            ownsService = true
            waitUntil(5_000, "fixture_service_not_running") { linux.serverRunning }
            linux.stopServer(forPhoneEngineSetup = true)
            val status = linux.startPhoneEngine(profile, 4098, null)
            val tier = if (kernelExit == 0) "landlock" else "proot"
            check(status["running"] == true && status["boundary"] == true && status["boundaryTier"] == tier) {
                "production_boundary_not_verified"
            }
            result["boundaryTier"] = tier
            result["productionBoundaryVerified"] = true
            val root = File(context.filesDir.canonicalFile, "oc.teamEngine.$profile")
            val receipt = org.json.JSONObject(File(root, "boundary-receipt.json").readText())
            check(receipt.getInt("schemaVersion") == 2 && receipt.getString("tier") == tier) { "signed_tier_invalid" }
            val signed = receipt.getJSONObject("controls")
            result["signedTierVerified"] = true
            if (tier == "proot") {
                result.putAll(linux.phoneBoundaryControls())
                for (control in listOf("canonicalPathsDenied", "daemonProcDenied", "fdHygiene", "parentInspectionDenied",
                    "prootGitCompatible", "fixtureUnchanged", "complete")) {
                    check(signed.getBoolean(control)) { "production_boundary_not_verified" }
                    result[control] = true
                }
                check(!signed.getBoolean("nativeAttacksDenied")) { "proot_claimed_kernel_boundary" }
            }
            onStage("protected_server_restart")
            linux.startProtectedPhoneServer(profile, script, 4097)
            val auth = linux.phoneEngineCredentials(profile)
            fun health(): org.json.JSONObject {
                val c = java.net.URL("${auth["baseUrl"]}/v1/health").openConnection() as java.net.HttpURLConnection
                try {
                    c.connectTimeout = 2000; c.readTimeout = 3000
                    c.setRequestProperty("Authorization", "Bearer ${auth["bearerToken"]}")
                    check(c.responseCode == 200) { "engine_health_unavailable" }
                    return org.json.JSONObject(c.inputStream.bufferedReader().use { it.readText() })
                } finally { c.disconnect() }
            }
            onStage("execution_capability")
            waitUntil(120_000, "execution_capability_unavailable") {
                val h = health()
                h.getJSONObject("capabilities").getBoolean("execution") && h.getString("boundaryTier") == tier
            }
            result["executionEnabled"] = true
            result["oc1ProtocolVerified"] = true
            val before = linux.serverUptimeMs ?: error("fixture_service_uptime_missing")
            linux.startServer(script, 4097)
            check((linux.serverUptimeMs ?: 0) >= before) { "identical_server_start_rotated_process" }
            result["serverRestartIdempotent"] = true
            onStage("signed_receipt_tamper")
            val file = File(root, "boundary-receipt.json")
            val original = file.readBytes()
            try {
                PhoneEngineAttestation.write(file, receipt.put("tier", if (tier == "proot") "landlock" else "proot").toString().toByteArray())
                val h = health()
                check(!h.getJSONObject("capabilities").getBoolean("boundary") &&
                    !h.getJSONObject("capabilities").getBoolean("execution") && h.getString("boundaryTier") == "none") {
                    "tampered_receipt_enabled_authority"
                }
                result["tamperedReceiptDenied"] = true
            } finally { PhoneEngineAttestation.write(file, original) }
            return result
        } finally {
            try { if (ownsService) linux.stopServer() } finally {
                try { linux.stopPhoneEngine(profile) } finally {
                    linux.deletePhoneEngine(profile)
                    if (createdPassword) passwordFile.delete()
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
