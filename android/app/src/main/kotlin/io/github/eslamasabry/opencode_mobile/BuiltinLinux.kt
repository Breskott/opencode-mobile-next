package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.os.Build
import android.system.Os
import android.system.OsConstants
import android.util.Log
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.zip.GZIPInputStream

/**
 * Ubuntu inside the app, with no Termux.
 *
 * The APK ships proot, its loader and the two libraries it needs as native
 * libraries (see tool/builtin_linux/fetch_proot.sh): Android unpacks those into
 * an executable folder, while this app may not run programs from its own
 * storage. proot runs Ubuntu's programs through its loader, so every program
 * in the Ubuntu tree is started by proot, never by the system.
 *
 * Ubuntu is Canonical's own minimal root filesystem (Ubuntu Base), pinned by
 * version and SHA-256, unpacked into app storage. Uninstalling the app removes
 * it.
 */
class BuiltinLinux(private val context: Context) {
    data class Image(val url: String, val sha256: String)

    data class Result(val exitCode: Int, val output: String)

    val home = File(context.filesDir, "linux")
    val rootfs = File(home, "ubuntu")
    private val ready = File(home, "ubuntu.ready")
    private val nativeDir = context.applicationInfo.nativeLibraryDir

    val installed: Boolean get() = ready.isFile

    enum class InstallStage { DOWNLOAD, UNPACK }

    /** How [install] reports to a setup job (SetupRunner.kt), and hears a cancel. */
    interface InstallProgress {
        fun stage(which: InstallStage) {}
        fun bytes(done: Long, total: Long) {}
        fun log(line: String) {}
        val cancelled: Boolean get() = false
    }

    class Cancelled : Exception("cancelled")

    fun install(image: Image = imageForDevice(), log: (String) -> Unit = {}) =
        install(
            image,
            object : InstallProgress {
                override fun log(line: String) = log(line)
            },
        )

    /**
     * Downloads (resuming a partial archive) and unpacks Ubuntu. The archive
     * stays in the cache until the unpack has finished, so an install killed
     * while unpacking starts again from the unpack, not the download.
     */
    fun install(image: Image = imageForDevice(), progress: InstallProgress) {
        if (installed) return
        home.mkdirs()
        val archive = File(context.cacheDir, "ubuntu-base.tar.gz")
        progress.stage(InstallStage.DOWNLOAD)
        progress.log("Downloading ${image.url}")
        download(image, archive, progress)
        progress.stage(InstallStage.UNPACK)
        progress.log("Unpacking Ubuntu Base $VERSION")
        rootfs.deleteRecursively()
        rootfs.mkdirs()
        unpack(archive, rootfs, progress)
        configure()
        ready.writeText(image.sha256)
        phase = "ready"
        message = null
        archive.delete()
        progress.log("Ubuntu Base $VERSION is installed")
    }

    /** Runs [script] with /bin/sh inside Ubuntu as root (faked by proot). */
    fun run(script: String, timeoutSeconds: Long = 600): Result {
        val process = start(script, null)
        process.outputStream.close()
        val output = StringBuilder()
        val reader = Thread {
            process.inputStream.bufferedReader().forEachLine { line ->
                Log.i(TAG, line)
                synchronized(output) {
                    output.appendLine(line)
                    // Keep the tail: that is where a failing command says why.
                    if (output.length > OUTPUT_CAP * 2) {
                        output.delete(0, output.length - OUTPUT_CAP)
                    }
                }
            }
        }.apply { start() }
        val finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS)
        if (!finished) stopTree(process)
        reader.join(2000)
        val text = synchronized(output) { output.takeLast(OUTPUT_CAP).toString() }
        return Result(if (finished) process.exitValue() else -1, text)
    }

    /**
     * Starts [script] inside Ubuntu with its output appended to [log], or piped
     * back when [log] is null. proot is given --kill-on-exit, so stopping it
     * stops everything the script started.
     */
    fun start(script: String, log: File?): Process {
        return ProcessBuilder(prootCommand(listOf("/bin/sh", "-c", script)))
            .redirectErrorStream(true)
            .apply {
                environment().putAll(prootEnvironment())
                if (log != null) {
                    log.parentFile?.mkdirs()
                    redirectOutput(ProcessBuilder.Redirect.appendTo(log))
                }
            }
            .start()
    }

    /** proot's own path: the program a terminal session (LocalTerminal.kt) starts. */
    val prootPath: String get() = "$nativeDir/libproot.so"

    /**
     * The proot command line that runs [program] inside Ubuntu as root, with
     * a clean environment. [start] and the local terminal (LocalTerminal.kt)
     * both use it, so a shell sees exactly what the app's scripts see.
     */
    fun prootCommand(program: List<String>): List<String> = listOf(
        prootPath,
        "--root-id",
        "--kill-on-exit",
        // Android does not let apps make hard links; dpkg and git do.
        "--link2symlink",
        "-L",
        "--sysvipc",
        "--rootfs=${rootfs.absolutePath}",
        "--bind=/dev",
        "--bind=/proc",
        "--bind=/sys",
        "--bind=${File(rootfs, "tmp").absolutePath}:/dev/shm",
        "--cwd=/root",
        "/usr/bin/env", "-i",
        "HOME=/root",
        "LANG=C.UTF-8",
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "TERM=xterm-256color",
        "TMPDIR=/tmp",
    ) + program

    /** What proot itself needs in its environment, on top of the app's own. */
    fun prootEnvironment(): Map<String, String> {
        val tmp = File(context.cacheDir, "proot-tmp").apply { mkdirs() }
        return mapOf(
            "PROOT_LOADER" to "$nativeDir/libproot-loader.so",
            "PROOT_TMP_DIR" to tmp.absolutePath,
            "LD_LIBRARY_PATH" to nativeDir,
        )
    }

    // ---- long-running services ---------------------------------------------

    /**
     * A long-running program inside Ubuntu that the app owns: the OpenCode
     * server ([SERVER]) and, when it is on, the AI Team supervisor. Each runs
     * in its own proot, started and stopped here and nowhere else, because a
     * program a script leaves running in the background dies with that
     * script's proot (`--kill-on-exit`).
     */
    private class Service(val process: Process, val port: Int?, val notice: String?)

    private val services = LinkedHashMap<String, Service>()

    val serverLog = File(home, "server.log")

    val serverRunning: Boolean get() = serviceRunning(SERVER)

    val port: Int? get() = servicePort(SERVER)

    @Synchronized
    fun serviceRunning(name: String): Boolean = services[name]?.process?.isAlive == true

    @Synchronized
    fun servicePort(name: String): Int? =
        services[name]?.takeIf { it.process.isAlive }?.port

    /** The names of the services that run now. */
    @Synchronized
    fun runningServices(): List<String> =
        services.filterValues { it.process.isAlive }.keys.toList()

    fun startServer(script: String, port: Int) = startService(SERVER, script, port, null)

    fun stopServer() = stopService(SERVER)

    /**
     * Starts [script] as the service [name], stopping an earlier run of the
     * same service first. [notice] is what the ongoing notification says
     * while this service runs (the app sends it in its own language); the
     * newest service with one wins, so "OpenCode and AI Team are running"
     * replaces "OpenCode is running" when the team starts.
     */
    @Synchronized
    fun startService(name: String, script: String, port: Int?, notice: String?) {
        check(installed) { "Ubuntu is not installed in the app yet" }
        require(NAME.matches(name)) { "Invalid service name: $name" }
        stopService(name)
        val log = serviceLogFile(name)
        // One log per run; the previous one stays for a look after a crash.
        if (log.isFile) log.renameTo(File(home, "$name.previous.log"))
        val process = start(script, log).also { it.outputStream.close() }
        services[name] = Service(process, port, notice)
        BuiltinServerService.start(context, currentNotice())
        // A service that exits on its own (a crash, a bad config) takes its
        // share of the "running" notification with it.
        Thread {
            process.waitFor()
            synchronized(this) {
                if (services[name]?.process === process) {
                    services.remove(name)
                    serviceSetChanged()
                }
            }
        }.start()
    }

    @Synchronized
    fun stopService(name: String) {
        val service = services.remove(name) ?: return
        stopTree(service.process)
        serviceSetChanged()
    }

    /** Stops every service; Stop in the notification and uninstall use it. */
    @Synchronized
    fun stopAllServices() {
        for (name in services.keys.toList()) stopService(name)
    }

    /** Keeps the foreground service exactly as long as any service runs. */
    private fun serviceSetChanged() {
        if (services.values.none { it.process.isAlive }) {
            BuiltinServerService.stop(context)
            return
        }
        // Only the words change here. Android refuses to (re)start a
        // foreground service from the background, and a service can end
        // while the app is away; the notification then keeps its old text.
        try {
            BuiltinServerService.start(context, currentNotice())
        } catch (error: Exception) {
            Log.w(TAG, "notification not updated", error)
        }
    }

    private fun currentNotice(): String? =
        services.values.lastOrNull { it.process.isAlive && it.notice != null }?.notice

    private fun serviceLogFile(name: String): File =
        if (name == SERVER) serverLog else File(home, "$name.log")

    fun serverLogTail(tailBytes: Int): String = serviceLogTail(SERVER, tailBytes)

    fun serviceLogTail(name: String, tailBytes: Int): String {
        if (!NAME.matches(name)) return ""
        val log = serviceLogFile(name)
        if (!log.isFile) return ""
        val skip = (log.length() - tailBytes).coerceAtLeast(0)
        log.inputStream().use { input ->
            input.skip(skip)
            return input.readBytes().toString(Charsets.UTF_8)
        }
    }

    // ---- install state -----------------------------------------------------

    @Volatile var phase: String = if (ready.isFile) "ready" else "idle"
        private set

    @Volatile var message: String? = null
        private set

    /** Starts [install] on its own thread; [phase] says how it went. */
    @Synchronized
    fun installInBackground() {
        if (phase == "installing") return
        if (installed) {
            phase = "ready"
            return
        }
        phase = "installing"
        message = null
        Thread {
            try {
                install { step -> message = step }
                phase = "ready"
                message = null
            } catch (error: Throwable) {
                Log.e(TAG, "install failed", error)
                phase = "failed"
                message = error.message ?: error.javaClass.simpleName
            }
        }.start()
    }

    fun uninstall() {
        // Every service first (OpenCode, AI Team with its store and agents):
        // deleting files under a running program leaves it spinning on
        // nothing.
        stopAllServices()
        ready.delete()
        rootfs.deleteRecursively()
        serverLog.delete()
        home.listFiles()?.filter { it.name.endsWith(".log") }?.forEach { it.delete() }
        // A finished setup job would otherwise still read as "done".
        File(home, "setup.json").delete()
        File(home, "setup.log").delete()
        phase = "idle"
        message = null
    }

    /** Disk used by Ubuntu and what is installed in it, measured at most once a minute. */
    @Volatile private var measured: Pair<Long, Long>? = null

    fun bytesUsed(): Long? {
        val now = System.currentTimeMillis()
        val last = measured
        if (last == null || now - last.first > 60_000) {
            measured = now to (last?.second ?: -1L)
            Thread { measured = System.currentTimeMillis() to sizeOf(rootfs) }.start()
        }
        return measured?.second?.takeIf { it >= 0 }
    }

    private fun sizeOf(file: File): Long {
        // lstat, not the link target: Ubuntu's links point at absolute paths
        // that resolve outside the tree from here.
        val stat = try {
            Os.lstat(file.absolutePath)
        } catch (_: Exception) {
            return 0
        }
        if (OsConstants.S_ISLNK(stat.st_mode)) return 0
        if (!file.isDirectory) return stat.st_size
        return file.listFiles()?.sumOf { sizeOf(it) } ?: 0
    }

    /**
     * Fetches [image] into [target], continuing a partial [target] with an
     * HTTP Range request. The server answers 206 (append), 200 (it ignores
     * ranges: start over) or 416 (the file is already whole: just check it).
     * The checksum covers the whole file, so a partial one is hashed first.
     */
    private fun download(image: Image, target: File, progress: InstallProgress) {
        val digest = MessageDigest.getInstance("SHA-256")
        var have = if (target.isFile) target.length() else 0L
        var url = URL(image.url)
        var connection: HttpURLConnection
        var redirects = 0
        var code: Int
        while (true) {
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 20_000
            connection.readTimeout = 60_000
            connection.instanceFollowRedirects = false
            if (have > 0) connection.setRequestProperty("Range", "bytes=$have-")
            code = connection.responseCode
            if (code in 300..399 && redirects < 5) {
                url = URL(url, connection.getHeaderField("Location"))
                redirects++
                connection.disconnect()
                continue
            }
            if (code != 200 && code != 206 && !(code == 416 && have > 0)) {
                error("download failed: HTTP $code from ${url.host}")
            }
            break
        }
        val total: Long = when (code) {
            206 -> connection.getHeaderField("Content-Range")
                ?.substringAfterLast('/')?.toLongOrNull() ?: -1L
            416 -> have
            else -> connection.contentLengthLong
        }
        if (code == 200) have = 0
        if (have > 0) {
            progress.log("Resuming the download at $have bytes")
            target.inputStream().use { input ->
                val buffer = ByteArray(1 shl 16)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    digest.update(buffer, 0, read)
                }
            }
        }
        progress.bytes(have, total.coerceAtLeast(0))
        if (code != 416) {
            connection.inputStream.use { input ->
                FileOutputStream(target, have > 0).use { out ->
                    val buffer = ByteArray(1 shl 16)
                    var done = have
                    var reported = 0L
                    while (true) {
                        if (progress.cancelled) throw Cancelled()
                        val read = input.read(buffer)
                        if (read < 0) break
                        digest.update(buffer, 0, read)
                        out.write(buffer, 0, read)
                        done += read
                        val now = System.currentTimeMillis()
                        if (now - reported >= 250) {
                            reported = now
                            progress.bytes(done, total.coerceAtLeast(0))
                        }
                    }
                    progress.bytes(done, total.coerceAtLeast(done))
                }
            }
        }
        connection.disconnect()
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        if (actual != image.sha256) {
            target.delete()
            error("checksum mismatch for ${image.url}")
        }
    }

    private fun unpack(archive: File, into: File, progress: InstallProgress) {
        // Hard links are made after everything else is in place: their targets
        // may come later in the archive.
        val hardLinks = mutableListOf<Pair<File, File>>()
        // Progress is the compressed bytes read so far against the archive's
        // size: the only total known before the end.
        val size = archive.length()
        var reported = 0L
        val counting = object : java.io.FilterInputStream(archive.inputStream()) {
            var count = 0L

            override fun read(): Int = super.read().also { if (it >= 0) count++ }

            override fun read(b: ByteArray, off: Int, len: Int): Int =
                super.read(b, off, len).also { if (it > 0) count += it }
        }
        TarArchiveInputStream(GZIPInputStream(BufferedInputStream(counting))).use { tar ->
            while (true) {
                if (progress.cancelled) throw Cancelled()
                val now = System.currentTimeMillis()
                if (now - reported >= 250) {
                    reported = now
                    progress.bytes(counting.count, size)
                }
                val entry: TarArchiveEntry = tar.nextEntry ?: break
                val name = entry.name.removePrefix("./").trimEnd('/')
                if (name.isEmpty() || name.split('/').contains("..")) continue
                val target = File(into, name)
                when {
                    entry.isDirectory -> {
                        target.mkdirs()
                        chmod(target, entry.mode or 0b111_000_000)
                    }
                    entry.isSymbolicLink -> {
                        target.parentFile?.mkdirs()
                        target.delete()
                        Os.symlink(entry.linkName, target.absolutePath)
                    }
                    entry.isLink -> hardLinks += target to File(into, entry.linkName.removePrefix("./"))
                    entry.isFile -> {
                        target.parentFile?.mkdirs()
                        target.delete()
                        FileOutputStream(target).use { tar.copyTo(it) }
                        chmod(target, entry.mode or 0b110_000_000)
                    }
                }
            }
        }
        for ((link, source) in hardLinks) {
            link.parentFile?.mkdirs()
            link.delete()
            source.copyTo(link)
            chmod(link, Os.stat(source.absolutePath).st_mode and 0xFFF)
        }
    }

    /**
     * Gives the app's Android groups (inet, everybody, its cache group…) a
     * name in Ubuntu's /etc/group. A login shell runs `groups`, which
     * otherwise prints "cannot find name for group ID 3003" once per group;
     * proot-distro adds the same lines. The group ids are per install, so
     * this is checked each time a terminal starts and costs one read.
     */
    fun nameAndroidGroups() {
        val file = File(rootfs, "etc/group")
        if (!file.isFile) return
        val gids = try {
            File("/proc/self/status").readLines()
                .firstOrNull { it.startsWith("Groups:") }
                ?.substringAfter(':')?.trim()?.split(Regex("\\s+"))
                ?.mapNotNull { it.toIntOrNull() }
                .orEmpty()
        } catch (_: Exception) {
            return
        }
        val existing = file.readLines().mapNotNull { it.split(':').getOrNull(2)?.toIntOrNull() }.toSet()
        val missing = gids.filter { it !in existing }.distinct()
        if (missing.isEmpty()) return
        file.appendText(missing.joinToString("") { "aid_$it:x:$it:\n" })
    }

    /** What proot-distro does after unpacking, trimmed to what Ubuntu needs. */
    private fun configure() {
        val etc = File(rootfs, "etc")
        File(etc, "resolv.conf").apply {
            delete()
            writeText("nameserver 1.1.1.1\nnameserver 8.8.8.8\n")
        }
        File(etc, "hosts").writeText(
            "127.0.0.1 localhost\n::1 localhost ip6-localhost ip6-loopback\n",
        )
        // apt drops to its own user to download; proot's fake root cannot
        // switch users, so apt downloads as root.
        File(etc, "apt/apt.conf.d/01-oc-sandbox").apply {
            parentFile?.mkdirs()
            writeText("APT::Sandbox::User \"root\";\n")
        }
        File(rootfs, "tmp").apply { mkdirs(); chmod(this, 0b111_111_111 or 0x200) }
        File(rootfs, "root").mkdirs()
    }

    private fun chmod(file: File, mode: Int) {
        try {
            Os.chmod(file.absolutePath, mode and 0xFFF)
        } catch (_: Exception) {
        }
    }

    companion object {
        /**
         * Stops a proot [process] together with everything it started.
         *
         * Neither half works alone: proot ignores SIGTERM, and killing proot
         * with SIGKILL detaches its tracees, which then run on as orphans
         * (seen on the emulator: an OpenCode server kept port 4097 after its
         * proot was killed, so the next start failed "port in use"). So the
         * programs inside get SIGTERM first, to finish cleanly; whatever is
         * left after [graceMs] gets SIGKILL, proot last.
         */
        fun stopTree(process: Process, graceMs: Long = 3000) {
            val root = pidOf(process)
            if (root == null) {
                process.destroy()
                if (!process.waitFor(graceMs, TimeUnit.MILLISECONDS)) process.destroyForcibly()
                return
            }
            for (pid in descendants(root)) signal(pid, OsConstants.SIGTERM)
            if (process.waitFor(graceMs, TimeUnit.MILLISECONDS)) {
                // proot left when its command did; a straggler may remain.
                return
            }
            for (pid in descendants(root)) signal(pid, OsConstants.SIGKILL)
            process.destroyForcibly()
            process.waitFor(graceMs, TimeUnit.MILLISECONDS)
        }

        /**
         * [stopTree] for a process the app knows only by [root] pid (a
         * terminal session started through a PTY). [exited] waits up to the
         * given milliseconds for it to end and says whether it did.
         *
         * An interactive shell ignores SIGTERM, so the programs inside get
         * SIGHUP too, as when a terminal closes; SIGKILL follows after
         * [graceMs], proot last.
         */
        fun stopPidTree(root: Int, exited: (Long) -> Boolean, graceMs: Long = 2000) {
            for (pid in descendants(root)) {
                signal(pid, OsConstants.SIGHUP)
                signal(pid, OsConstants.SIGTERM)
            }
            if (exited(graceMs)) return
            for (pid in descendants(root)) signal(pid, OsConstants.SIGKILL)
            signal(root, OsConstants.SIGKILL)
            exited(graceMs)
        }

        /** How many processes run as this app's user now, the app itself included. */
        fun appProcessCount(): Int {
            val uid = android.os.Process.myUid()
            return File("/proc").listFiles()?.count { dir ->
                dir.name.toIntOrNull() != null &&
                    try {
                        Os.stat(dir.absolutePath).st_uid == uid
                    } catch (_: Exception) {
                        false
                    }
            } ?: 0
        }

        private fun signal(pid: Int, signal: Int) {
            try {
                Os.kill(pid, signal)
            } catch (_: Exception) {
                // Already gone.
            }
        }

        /** Android's ProcessImpl keeps the pid in a private field; no public API has it. */
        private fun pidOf(process: Process): Int? {
            return try {
                process.javaClass.getDeclaredField("pid").run {
                    isAccessible = true
                    getInt(process)
                }
            } catch (_: Throwable) {
                null
            }
        }

        /** Every process below [root], read from /proc (same app, same user). */
        private fun descendants(root: Int): List<Int> {
            val parents = HashMap<Int, Int>()
            File("/proc").listFiles()?.forEach { dir ->
                val pid = dir.name.toIntOrNull() ?: return@forEach
                val stat = try {
                    File(dir, "stat").readText()
                } catch (_: Exception) {
                    return@forEach
                }
                // "pid (comm) state ppid …"; comm may hold spaces and parens.
                val ppid = stat.substringAfterLast(')').trim().split(' ').getOrNull(1)?.toIntOrNull()
                if (ppid != null) parents[pid] = ppid
            }
            val found = mutableListOf<Int>()
            var frontier = listOf(root)
            while (frontier.isNotEmpty()) {
                val next = parents.filter { it.value in frontier }.keys.toList()
                found += next
                frontier = next
            }
            return found
        }

        const val TAG = "OcLinux"
        private const val OUTPUT_CAP = 64 * 1024

        /** The OpenCode server's service name. */
        const val SERVER = "server"

        /** Service names double as log file names. */
        private val NAME = Regex("[a-z][a-z0-9-]{0,31}")

        @Volatile private var instance: BuiltinLinux? = null

        /** One Ubuntu per app: it owns the server process and the install state. */
        fun get(context: Context): BuiltinLinux =
            instance ?: synchronized(this) {
                instance ?: BuiltinLinux(context.applicationContext).also { instance = it }
            }

        // Ubuntu Base 24.04.5 (noble), from Canonical's SHA256SUMS.
        /** What the setup checklist shows for the Linux base once installed. */
        const val VERSION = "24.04.5"

        private const val BASE =
            "https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/"
        val arm64 = Image(
            BASE + "ubuntu-base-24.04.5-base-arm64.tar.gz",
            "a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2",
        )
        val amd64 = Image(
            BASE + "ubuntu-base-24.04.5-base-amd64.tar.gz",
            "e77b6f10c2590cef872b33ee9f635a0e3fd1f57fb074c0e52b5c7f56147a0c86",
        )

        fun imageForDevice(): Image =
            if (Build.SUPPORTED_ABIS.firstOrNull() == "x86_64") amd64 else arm64
    }
}
