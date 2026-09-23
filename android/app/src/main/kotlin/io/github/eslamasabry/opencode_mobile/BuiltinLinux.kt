package io.github.eslamasabry.opencode_mobile

import android.content.Context
import android.os.Build
import android.system.Os
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

    fun install(image: Image = imageForDevice(), log: (String) -> Unit = {}) {
        if (installed) return
        home.mkdirs()
        val archive = File(context.cacheDir, "ubuntu-base.tar.gz")
        log("downloading ${image.url}")
        download(image, archive)
        log("unpacking")
        rootfs.deleteRecursively()
        rootfs.mkdirs()
        unpack(archive, rootfs)
        archive.delete()
        configure()
        ready.writeText(image.sha256)
        log("installed")
    }

    /** Runs [script] with /bin/sh inside Ubuntu as root (faked by proot). */
    fun run(script: String, timeoutSeconds: Long = 600): Result {
        val tmp = File(context.cacheDir, "proot-tmp").apply { mkdirs() }
        val command = listOf(
            "$nativeDir/libproot.so",
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
            "/bin/sh", "-c", script,
        )
        val process = ProcessBuilder(command)
            .redirectErrorStream(true)
            .apply {
                environment()["PROOT_LOADER"] = "$nativeDir/libproot-loader.so"
                environment()["PROOT_TMP_DIR"] = tmp.absolutePath
                environment()["LD_LIBRARY_PATH"] = nativeDir
            }
            .start()
        process.outputStream.close()
        val output = StringBuilder()
        val reader = Thread {
            process.inputStream.bufferedReader().forEachLine { line ->
                Log.i(TAG, line)
                synchronized(output) { output.appendLine(line) }
            }
        }.apply { start() }
        val finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS)
        if (!finished) process.destroyForcibly()
        reader.join(2000)
        return Result(if (finished) process.exitValue() else -1, output.toString())
    }

    private fun download(image: Image, target: File) {
        val digest = MessageDigest.getInstance("SHA-256")
        var url = URL(image.url)
        var connection: HttpURLConnection
        var redirects = 0
        while (true) {
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 20_000
            connection.readTimeout = 60_000
            connection.instanceFollowRedirects = false
            val code = connection.responseCode
            if (code in 300..399 && redirects < 5) {
                url = URL(url, connection.getHeaderField("Location"))
                redirects++
                connection.disconnect()
                continue
            }
            if (code != 200) error("download failed: HTTP $code from ${url.host}")
            break
        }
        connection.inputStream.use { input ->
            FileOutputStream(target).use { out ->
                val buffer = ByteArray(1 shl 16)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    digest.update(buffer, 0, read)
                    out.write(buffer, 0, read)
                }
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        if (actual != image.sha256) {
            target.delete()
            error("checksum mismatch for ${image.url}")
        }
    }

    private fun unpack(archive: File, into: File) {
        // Hard links are made after everything else is in place: their targets
        // may come later in the archive.
        val hardLinks = mutableListOf<Pair<File, File>>()
        TarArchiveInputStream(GZIPInputStream(BufferedInputStream(archive.inputStream()))).use { tar ->
            while (true) {
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
        const val TAG = "OcLinux"

        // Ubuntu Base 24.04.5 (noble), from Canonical's SHA256SUMS.
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
