package io.github.eslamasabry.opencode_mobile

import android.content.Context
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

/** Native executable and credentials stay outside the proot filesystem. */
internal class PhoneEngineNative(private val context: Context) {
    class Failure(val code: String) : Exception("The phone engine is unavailable.")

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
            if (activeProfile != profile || activePort != port) throw Failure("engine_in_use")
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
        val source = File(context.filesDir, "linux/ubuntu/root/.oc-builtin/server.password")
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
        val workerRoot = File(context.filesDir, "linux/ubuntu/root/aiteam/work/$profile")
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
                .put("hostRoot", File(context.filesDir, "projects").absolutePath)
                .put("guestRoot", "/root/projects")))
            .put("port", port).put("authTokenFile", tokenFile.absolutePath)
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
                    redirectOutput(File("/dev/null"))
                    redirectError(File("/dev/null"))
                }.start()
        } catch (_: Exception) { throw Failure("engine_start_failed") }
        child.outputStream.close()
        activeProfile = profile
        activePort = port
        process = child
        restartRequired = serverRunning
        verifiedBoundary = false
        executionAvailable = false
        boundaryGeneration = proof?.generation
        boundaryReason = if (proof != null) "attestation_pending" else fallbackReason
        try {
            val health = awaitHealth(child, port, token, profile)
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
        return mapOf("baseUrl" to "http://127.0.0.1:$activePort", "bearerToken" to token)
    }

    fun stop(profile: String) {
        validateProfile(profile)
        if (activeProfile != profile) return
        val child = process
        if (child?.isAlive == true) {
            child.destroy()
            if (!child.waitFor(3, TimeUnit.SECONDS)) child.destroyForcibly()
            if (!child.waitFor(3, TimeUnit.SECONDS)) throw Failure("engine_stop_failed")
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
        val worker = File(context.filesDir, "linux/ubuntu/root/aiteam/work/$profile")
        if (worker.exists()) {
            // Do not traverse a substituted parent directory out of the rootfs.
            var parent = worker.parentFile
            while (parent != null && parent != context.filesDir) {
                if (OsConstants.S_ISLNK(Os.lstat(parent.absolutePath).st_mode))
                    throw Failure("private_state_invalid")
                parent = parent.parentFile
            }
            eraseNoLinks(worker)
        }
        val root = privateRoot(profile, false)
        if (root.exists()) eraseNoLinks(root)
        if (!marker.delete()) throw Failure("engine_delete_failed")
        syncDirectory(context.filesDir)
    }

    private fun deletionMarker(profile: String): File =
        File(context.filesDir, "oc.teamEngineDeletion.$profile")

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
        val root = File(context.filesDir, "oc.teamEngine.$profile")
        if (create && !root.exists() && !root.mkdir()) throw Failure("private_state_unavailable")
        if (root.exists()) {
            val stat = Os.lstat(root.absolutePath)
            if (!OsConstants.S_ISDIR(stat.st_mode) || root.canonicalFile.parentFile !=
                context.filesDir.canonicalFile) throw Failure("private_state_invalid")
            Os.chmod(root.absolutePath, 448) // 0700
        }
        return root
    }

    private fun regularNoLinks(file: File): Boolean = try {
        var cursor: File? = file
        while (cursor != null && cursor != context.filesDir.parentFile) {
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
        val stat = Os.lstat(file.absolutePath)
        if (OsConstants.S_ISDIR(stat.st_mode)) {
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
        fun verifyBundle(context: Context, vararg names: String) {
            try {
                val manifest = context.assets.open("aiteam-engine-manifest.json").bufferedReader().use {
                    JSONObject(it.readText())
                }
                if (manifest.getInt("schemaVersion") != 1 || manifest.getString("target") != "aarch64-linux-android") {
                    throw Failure("engine_bundle_invalid")
                }
                val hashes = manifest.getJSONObject("sha256")
                for (name in names) {
                    val expected = hashes.getString(name)
                    if (!Regex("[0-9a-f]{64}").matches(expected)) throw Failure("engine_bundle_invalid")
                    val file = File(context.applicationInfo.nativeLibraryDir, name)
                    if (!OsConstants.S_ISREG(Os.lstat(file.absolutePath).st_mode)) throw Failure("engine_bundle_invalid")
                    val digest = MessageDigest.getInstance("SHA-256")
                    file.inputStream().use { input ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            val size = input.read(buffer)
                            if (size < 0) break
                            digest.update(buffer, 0, size)
                        }
                    }
                    val actual = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
                    if (!MessageDigest.isEqual(expected.toByteArray(Charsets.US_ASCII), actual.toByteArray(Charsets.US_ASCII))) {
                        throw Failure("engine_bundle_invalid")
                    }
                }
            } catch (_: Exception) { throw Failure("engine_bundle_invalid") }
        }

        private val PROFILE = Regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$")
        private val TOKEN = Regex("^[a-f0-9]{64}$")
    }
}
