package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.os.Build
import android.system.Os
import android.system.OsConstants
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.concurrent.FutureTask
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.util.UUID

/** Native executable and credentials stay outside the proot filesystem. */
internal class PhoneEngineNative(private val context: Context) {
    class Failure(val code: String) : Exception("The phone engine is unavailable.")

    private val filesRoot: File get() = context.filesDir.canonicalFile
    private var activeProfile: String? = null
    private var activePort: Int? = null
    private var process: Process? = null
    private var restartRequired = false
    private var verifiedBoundary = false
    private var executionAvailable = false
    private var boundaryReason = "boundary_unverified"
    private var boundaryGeneration: String? = null

    fun stopTracked() { activeProfile?.let { stop(it) } }

    fun status(profile: String): Map<String, Any?> {
        validateProfile(profile)
        val running = activeProfile == profile && process?.isAlive == true
        return mapOf(
            "running" to running, "profileId" to profile,
            "port" to if (running) activePort else null,
            "boundary" to (running && verifiedBoundary), "execution" to (running && executionAvailable),
            "restartRequired" to (running && restartRequired),
            "boundaryReason" to boundaryReason, "boundaryGeneration" to if (running) boundaryGeneration else null,
        )
    }

    fun start(profile: String, port: Int, serverRunning: Boolean, reason: String,
        proofFactory: (File) -> PhoneEngineAttestation.Receipt?): Process {
        validateProfile(profile)
        if (port !in 1024..65535 || port == 4097) throw Failure("invalid_port")
        if (process?.isAlive == true) {
            if (activeProfile != profile) throw Failure("engine_in_use")
            return process!!
        }
        // Interrupted deletion is completed before a new profile generation is
        // allowed to recreate state. Tombstones never carry credentials.
        if (deletionMarker(profile).exists()) delete(profile)
        val executable = File(context.applicationInfo.nativeLibraryDir, "libaiteam_engine.so")
        if (!executable.isFile || !executable.canExecute()) throw Failure("engine_not_packaged")
        verifyBundle(context, "libaiteam_engine.so")
        val root = privateRoot(profile, create = true)
        var fallbackReason = reason
        val proof = try { proofFactory(root) } catch (failure: Failure) {
            fallbackReason = failure.code
            null
        }
        val tokenFile = File(root, "auth.token")
        // A credential observed during a previous unconfined generation must
        // not authorize the freshly protected generation.
        val freshToken = ByteArray(32).also { SecureRandom().nextBytes(it) }
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        writePrivate(tokenFile, freshToken)
        val token = readPrivate(tokenFile)
        if (!TOKEN.matches(token)) throw Failure("private_state_invalid")
        val source = File(filesRoot, "linux/ubuntu/root/.oc-builtin/server.password")
        val credentials = File(root, "oc1-credentials.json")
        // A missing server password is an unavailable execution prerequisite,
        // while the durable store can still run. Never keep an obsolete copy.
        if (regularNoLinks(source)) {
            val password = readPrivate(source)
            if (password.length !in 1..4096) throw Failure("server_auth_unavailable")
            writePrivate(credentials, JSONObject().put("username", "opencode")
                .put("password", password).toString())
        } else if (credentials.exists() && !credentials.delete()) {
            throw Failure("private_state_unavailable")
        }
        val config = File(root, "native-config.json")
        val workerRoot = safePath("linux/ubuntu/root/aiteam/work/$profile")
        val boundary = JSONObject().put("verified", false)
            .put("reason", if (proof != null) "boundary_attested" else fallbackReason)
            .put("restartRequired", serverRunning)
        if (proof != null) boundary.put("receiptFile", proof.file.absolutePath)
            .put("publicKeyFile", proof.publicKeyFile.absolutePath).put("generation", proof.generation)
        writePrivate(config, JSONObject()
            .put("schemaVersion", 1).put("profileId", profile)
            .put("privateRoot", root.absolutePath).put("workerRoot", workerRoot.absolutePath)
            .put("guestWorkerRoot", "/root/aiteam/work/$profile")
            .put("sourceRoots", org.json.JSONArray().put(JSONObject()
                .put("hostRoot", safePath("projects").absolutePath)
                .put("guestRoot", "/root/projects")))
            .put("port", 0).put("authTokenFile", tokenFile.absolutePath)
            .put("oc1CredentialFile", credentials.absolutePath)
            .put("oc1BaseUrl", "http://127.0.0.1:4097")
            .put("boundary", boundary)
            .toString())
        // No secrets in argv, environment, logs or exception text. Only the
        // shipped ELF is executable; Android 10 forbids app-data executables.
        val child = try {
            val args = mutableListOf(executable.absolutePath, "--config", config.absolutePath)
            if (proof != null) args.addAll(listOf("--trusted-public-key-sha256", proof.keySha256,
                "--native-generation", proof.generation, "--policy-sha256", proof.policySha256))
            ProcessBuilder(args)
                .directory(root).apply {
                    environment().clear()
                    environment()["PATH"] = "/system/bin"
                    redirectError(File("/dev/null"))
                }.start()
        } catch (_: Exception) { throw Failure("engine_start_failed") }
        // Keep stdin open: EOF binds the daemon lifetime to the app process,
        // rather than the short-lived MethodChannel launch thread.
        activeProfile = profile
        activePort = null
        process = child
        restartRequired = serverRunning
        verifiedBoundary = false
        executionAvailable = false
        boundaryGeneration = proof?.generation
        boundaryReason = if (proof != null) "attestation_pending" else fallbackReason
        try {
            val actualPort = awaitReady(child, token, profile)
            activePort = actualPort
            val health = awaitHealth(child, actualPort, token, profile)
            verifiedBoundary = proof != null && health.optJSONObject("capabilities")?.optBoolean("boundary") == true
            executionAvailable = verifiedBoundary && health.optJSONObject("capabilities")?.optBoolean("execution") == true
            if (proof != null) boundaryReason = if (verifiedBoundary) "boundary_attested" else "attestation_rejected"
        } catch (failure: Failure) {
            stop(profile)
            throw failure
        }
        return child
    }

    fun credentials(profile: String): Map<String, String> {
        if (status(profile)["running"] != true) throw Failure("engine_not_running")
        val token = readPrivate(File(privateRoot(profile, false), "auth.token"))
        if (!TOKEN.matches(token)) throw Failure("private_state_invalid")
        if (process?.isAlive != true || activePort == null) throw Failure("engine_not_running")
        return mapOf("baseUrl" to "http://127.0.0.1:$activePort", "bearerToken" to token)
    }

    fun stop(profile: String) {
        validateProfile(profile)
        if (activeProfile != profile) return
        val child = process
        try { child?.outputStream?.close() } catch (_: Exception) { }
        if (child?.isAlive == true) {
            child.destroy()
            if (!child.waitFor(3, TimeUnit.SECONDS)) child.destroyForcibly()
            if (!child.waitFor(3, TimeUnit.SECONDS)) throw Failure("engine_stop_failed")
        }
        try { child?.inputStream?.close() } catch (_: Exception) { }
        val credentials = File(privateRoot(profile, false), "oc1-credentials.json")
        try { Os.remove(credentials.absolutePath) } catch (error: android.system.ErrnoException) {
            if (error.errno != OsConstants.ENOENT) throw Failure("private_state_unavailable")
        }
        process = null
        activeProfile = null
        activePort = null
        restartRequired = false
        verifiedBoundary = false
        executionAvailable = false
        boundaryGeneration = null
    }

    fun delete(profile: String) {
        if (status(profile)["running"] == true) {
            val auth = credentials(profile)
            val connection = URL("${auth["baseUrl"]}/v1/profile").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "DELETE"
                connection.connectTimeout = 2000
                connection.readTimeout = 10000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Authorization", "Bearer ${auth["bearerToken"]}")
                if (connection.responseCode !in 200..299) throw Failure("engine_delete_failed")
            } catch (_: Exception) { throw Failure("engine_delete_failed")
            } finally { connection.disconnect() }
        }
        stop(profile)
        val marker = deletionMarker(profile)
        writePrivate(marker, "deleting-v1")
        val worker = File(filesRoot, "linux/ubuntu/root/aiteam/work/$profile")
        if (worker.exists()) {
            // Do not traverse a substituted parent directory out of the rootfs.
            var parent = worker.parentFile
            while (parent != null && parent != filesRoot) {
                if (OsConstants.S_ISLNK(Os.lstat(parent.absolutePath).st_mode))
                    throw Failure("private_state_invalid")
                parent = parent.parentFile
            }
            eraseNoLinks(worker)
        }
        val root = privateRoot(profile, false)
        if (root.exists()) eraseNoLinks(root)
        if (!marker.delete()) throw Failure("engine_delete_failed")
        syncDirectory(filesRoot)
    }

    private fun deletionMarker(profile: String): File =
        File(filesRoot, "oc.teamEngineDeletion.$profile")

    /** Only the private child stdout pipe can select the authenticated TCP port. */
    private fun awaitReady(child: Process, token: String, profile: String): Int {
        val task = FutureTask<Int> {
            val output = java.io.ByteArrayOutputStream()
            while (output.size() <= 1024) {
                val byte = child.inputStream.read()
                if (byte < 0) throw Failure("engine_start_failed")
                if (byte == 10) break
                output.write(byte)
            }
            if (output.size() > 1024) throw Failure("engine_ready_invalid")
            verifiedReadyPort(output.toString("UTF-8"), token, profile)
        }
        Thread(task, "phone-engine-ready").apply { isDaemon = true; start() }
        try {
            val port = task.get(10, TimeUnit.SECONDS)
            if (!child.isAlive) throw Failure("engine_start_failed")
            return port
        } catch (_: Exception) {
            task.cancel(true)
            throw Failure("engine_ready_invalid")
        }
    }

    /** Resolve the system-owned app-data ancestor, never an agent-owned child. */
    private fun safePath(relative: String): File {
        var path = filesRoot
        for (component in relative.split('/')) {
            if (component.isEmpty() || component == "." || component == "..") throw Failure("private_state_invalid")
            path = File(path, component)
            try {
                if (OsConstants.S_ISLNK(Os.lstat(path.absolutePath).st_mode)) throw Failure("private_state_invalid")
            } catch (error: android.system.ErrnoException) {
                if (error.errno != OsConstants.ENOENT) throw Failure("private_state_unavailable")
            }
        }
        return path
    }

    private fun awaitHealth(child: Process, port: Int, token: String, profile: String): JSONObject {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
        while (child.isAlive && System.nanoTime() < deadline) {
            val connection = URL("http://127.0.0.1:$port/v1/health")
                .openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 300
                connection.readTimeout = 300
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Authorization", "Bearer $token")
                if (connection.responseCode == 200) {
                    val bytes = connection.inputStream.use { readBounded(it) }
                    if (bytes.size > 8192) throw Failure("engine_health_invalid")
                    val health = JSONObject(String(bytes, Charsets.UTF_8))
                    if (health.optInt("schemaVersion") != 1 ||
                        health.optString("profileId") != profile) throw Failure("engine_health_invalid")
                    if (!child.isAlive) throw Failure("engine_start_failed")
                    return health
                }
            } catch (failure: Failure) { throw failure
            } catch (_: Exception) { /* Startup polling; no raw error is logged. */
            } finally { connection.disconnect() }
            Thread.sleep(100)
        }
        throw Failure("engine_start_failed")
    }

    private fun privateRoot(profile: String, create: Boolean): File {
        validateProfile(profile)
        val root = File(filesRoot, "oc.teamEngine.$profile")
        if (create && !root.exists() && !root.mkdir()) throw Failure("private_state_unavailable")
        if (root.exists()) {
            val stat = Os.lstat(root.absolutePath)
            if (!OsConstants.S_ISDIR(stat.st_mode) || root.canonicalFile.parentFile !=
                filesRoot) throw Failure("private_state_invalid")
            Os.chmod(root.absolutePath, 448) // 0700
        }
        return root
    }

    private fun regularNoLinks(file: File): Boolean = try {
        var cursor: File? = file
        while (cursor != null && cursor != filesRoot.parentFile) {
            if (OsConstants.S_ISLNK(Os.lstat(cursor.absolutePath).st_mode)) return false
            cursor = cursor.parentFile
        }
        OsConstants.S_ISREG(Os.lstat(file.absolutePath).st_mode)
    } catch (_: Exception) { false }

    private fun readPrivate(file: File): String {
        if (!regularNoLinks(file)) throw Failure("private_state_invalid")
        val fd = Os.open(file.absolutePath, OsConstants.O_RDONLY or OsConstants.O_NOFOLLOW, 0)
        return java.io.FileInputStream(fd).use { input ->
            val bytes = readBounded(input)
            if (bytes.size > 8192) throw Failure("private_state_invalid")
            String(bytes, Charsets.UTF_8)
        }
    }

    private fun writePrivate(file: File, text: String) {
        if (file.exists() && !regularNoLinks(file)) throw Failure("private_state_invalid")
        val temporary = File(file.parentFile, ".${file.name}.new")
        // A crash may leave the exact temporary name; unlink it, never follow it.
        if (temporary.exists() && !temporary.delete()) throw Failure("private_state_unavailable")
        val fd = Os.open(temporary.absolutePath, OsConstants.O_WRONLY or OsConstants.O_CREAT or
            OsConstants.O_EXCL or OsConstants.O_NOFOLLOW, 384) // 0600
        try {
            FileOutputStream(fd).use { output ->
                output.write(text.toByteArray(Charsets.UTF_8))
                output.flush()
                output.fd.sync()
            }
            Os.rename(temporary.absolutePath, file.absolutePath)
            syncDirectory(file.parentFile!!)
        } finally { temporary.delete() }
    }

    private fun syncDirectory(directory: File) {
        val fd = Os.open(directory.absolutePath, OsConstants.O_RDONLY or
            OsConstants.O_NOFOLLOW or OsConstants.O_NONBLOCK or OsConstants.O_CLOEXEC, 0)
        try {
            if (!OsConstants.S_ISDIR(Os.fstat(fd).st_mode)) throw Failure("private_state_unavailable")
            Os.fsync(fd)
        } finally { Os.close(fd) }
    }

    private fun eraseNoLinks(file: File) {
        val stat = try { Os.lstat(file.absolutePath) } catch (error: android.system.ErrnoException) {
            if (error.errno == OsConstants.ENOENT) return
            throw Failure("private_state_unavailable")
        }
        if (OsConstants.S_ISDIR(stat.st_mode)) {
            val directory = Os.open(file.absolutePath, OsConstants.O_RDONLY or
                OsConstants.O_NOFOLLOW or OsConstants.O_NONBLOCK or OsConstants.O_CLOEXEC, 0)
            try {
                val opened = Os.fstat(directory)
                if (!OsConstants.S_ISDIR(opened.st_mode) || opened.st_dev != stat.st_dev || opened.st_ino != stat.st_ino)
                    throw Failure("private_state_unavailable")
                Os.fchmod(directory, 448) // 0700, on the verified directory descriptor.
            } finally { Os.close(directory) }
            for (child in file.listFiles() ?: throw Failure("private_state_unavailable")) eraseNoLinks(child)
        }
        if (!file.delete()) throw Failure("private_state_unavailable")
    }

    private fun validateProfile(profile: String) {
        if (!PROFILE.matches(profile)) throw Failure("invalid_profile")
    }

    private fun readBounded(input: java.io.InputStream): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(1024)
        while (output.size() <= 8192) {
            val count = input.read(buffer, 0, minOf(buffer.size, 8193 - output.size()))
            if (count < 0) break
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    companion object {
        internal fun verifiedReadyPort(line: String, token: String, profile: String): Int {
            try {
                if (line.toByteArray(Charsets.UTF_8).size > 1024 || !TOKEN.matches(token)) throw Failure("engine_ready_invalid")
                val ready = JSONObject(line)
                val nonce = ready.getString("nonce")
                val port = ready.getInt("port")
                val signature = ready.getString("mac")
                if (ready.length() != 5 || ready.getInt("schemaVersion") != 1 ||
                    ready.getString("profileId") != profile || port !in 1024..65535 || port == 4097 ||
                    nonce.length != 36 || UUID.fromString(nonce).toString() != nonce || !TOKEN.matches(signature)) {
                    throw Failure("engine_ready_invalid")
                }
                val mac = Mac.getInstance("HmacSHA256")
                mac.init(SecretKeySpec(token.toByteArray(Charsets.UTF_8), "HmacSHA256"))
                val message = "oc-phone-engine-ready-v1\n$profile\n$port\n$nonce"
                val expected = mac.doFinal(message.toByteArray(Charsets.UTF_8))
                    .joinToString("") { "%02x".format(it.toInt() and 255) }
                if (!MessageDigest.isEqual(expected.toByteArray(Charsets.US_ASCII), signature.toByteArray(Charsets.US_ASCII))) {
                    throw Failure("engine_ready_invalid")
                }
                return port
            } catch (_: Exception) { throw Failure("engine_ready_invalid") }
        }

        fun verifyBundle(context: Context, vararg names: String) {
            try {
                if (names.isEmpty() || names.any { it !in BUNDLE_NAMES } || !android.os.Process.is64Bit()) {
                    throw Failure("engine_bundle_invalid")
                }
                val manifest = context.assets.open("aiteam-engine-manifest.json").bufferedReader().use {
                    JSONObject(it.readText())
                }
                // Android may advertise several ABIs, including translated
                // ones. The installed ELF selects its own manifest entry;
                // SUPPORTED_ABIS is a compatibility check, never the selector.
                var abi: String? = null
                val actualHashes = mutableMapOf<String, String>()
                for (name in BUNDLE_NAMES) {
                    val file = File(context.applicationInfo.nativeLibraryDir, name)
                    val fd = Os.open(file.absolutePath, OsConstants.O_RDONLY or
                        OsConstants.O_NOFOLLOW or OsConstants.O_NONBLOCK or OsConstants.O_CLOEXEC, 0)
                    try {
                        if (!OsConstants.S_ISREG(Os.fstat(fd).st_mode)) throw Failure("engine_bundle_invalid")
                        val header = ByteArray(64)
                        var offset = 0
                        while (offset < header.size) {
                            val count = Os.read(fd, header, offset, header.size - offset)
                            if (count <= 0) throw Failure("engine_bundle_invalid")
                            offset += count
                        }
                        val actualAbi = packagedAbi(header)
                        if (actualAbi !in Build.SUPPORTED_ABIS || (abi != null && abi != actualAbi)) {
                            throw Failure("engine_bundle_invalid")
                        }
                        abi = actualAbi
                        val digest = MessageDigest.getInstance("SHA-256")
                        digest.update(header)
                        val buffer = ByteArray(65536)
                        while (true) {
                            val size = Os.read(fd, buffer, 0, buffer.size)
                            if (size == 0) break
                            if (size < 0) throw Failure("engine_bundle_invalid")
                            digest.update(buffer, 0, size)
                        }
                        actualHashes[name] = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
                    } finally { Os.close(fd) }
                }
                val selectedAbi = abi ?: throw Failure("engine_bundle_invalid")
                val entry = when (manifest.getInt("schemaVersion")) {
                    1 -> {
                        if (selectedAbi != "arm64-v8a") throw Failure("engine_bundle_invalid")
                        manifest
                    }
                    2 -> manifest.getJSONObject("abis").getJSONObject(selectedAbi)
                    else -> throw Failure("engine_bundle_invalid")
                }
                val target = if (selectedAbi == "arm64-v8a") "aarch64-linux-android" else "x86_64-linux-android"
                if (entry.getString("target") != target || entry.getInt("api") != 26) {
                    throw Failure("engine_bundle_invalid")
                }
                val hashes = entry.getJSONObject("sha256")
                for (name in BUNDLE_NAMES) {
                    val expected = hashes.getString(name)
                    if (!Regex("[0-9a-f]{64}").matches(expected)) throw Failure("engine_bundle_invalid")
                    val actual = actualHashes.getValue(name)
                    if (!MessageDigest.isEqual(expected.toByteArray(Charsets.US_ASCII), actual.toByteArray(Charsets.US_ASCII))) {
                        throw Failure("engine_bundle_invalid")
                    }
                }
            } catch (_: Exception) { throw Failure("engine_bundle_invalid") }
        }

        /** Strict ELF64 little-endian PIE parser, independent of device preference order. */
        internal fun packagedAbi(header: ByteArray): String {
            fun byte(index: Int) = header[index].toInt() and 255
            if (header.size != 64 || byte(0) != 0x7f || byte(1) != 0x45 || byte(2) != 0x4c ||
                byte(3) != 0x46 || byte(4) != 2 || byte(5) != 1 || byte(6) != 1 ||
                byte(16) != 3 || byte(17) != 0 || byte(20) != 1 ||
                (21..23).any { byte(it) != 0 } || byte(52) != 64 || byte(53) != 0) {
                throw Failure("engine_bundle_invalid")
            }
            return when (byte(18) or (byte(19) shl 8)) {
                183 -> "arm64-v8a"
                62 -> "x86_64"
                else -> throw Failure("engine_bundle_invalid")
            }
        }

        private val BUNDLE_NAMES = listOf("libaiteam_engine.so", "libaiteam_sandbox.so", "libaiteam_boundary_probe.so")
        private val PROFILE = Regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$")
        private val TOKEN = Regex("^[a-f0-9]{64}$")
    }
}
