package io.github.eslamasabry.opencode_mobile

import android.content.Context
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.SocketTimeoutException
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/** Real packaged daemon, real occupied TCP port, and forged child-pipe control. */
internal object PhoneEngineNativeRegressions {
    fun run(context: Context) {
        check(context.packageName == "io.github.eslamasabry.opencode_mobile.preview")
        refusesUnauthenticatedChildBeforeHttp(context)
        ignoresSquatterAndSurvivesLauncher(context)
    }

    private fun refusesUnauthenticatedChildBeforeHttp(context: Context) {
        ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { squatter ->
            squatter.soTimeout = 300
            val profile = "qa_pipe"
            val token = "a".repeat(64)
            val line = JSONObject().put("schemaVersion", 1).put("profileId", profile)
                .put("port", squatter.localPort).put("nonce", UUID.randomUUID().toString())
                .put("mac", "0".repeat(64)).toString() + "\n"
            var refused = false
            try {
                PhoneEngineNative(context).authenticatedStartup(PipeChild(line), token, profile)
            } catch (failure: PhoneEngineNative.Failure) {
                check(failure.code == "engine_ready_invalid")
                refused = true
            }
            check(refused) { "An unauthenticated pipe was accepted" }
            try {
                squatter.accept().use { throw IllegalStateException("HTTP opened before pipe authentication") }
            } catch (_: SocketTimeoutException) { }
        }
    }

    private fun ignoresSquatterAndSurvivesLauncher(context: Context) {
        val profile = "qa_native_${UUID.randomUUID().toString().replace("-", "")}"
        val native = PhoneEngineNative(context)
        val failure = AtomicReference<Throwable?>(null)
        val child = AtomicReference<Process?>(null)
        val connections = AtomicInteger(0)
        // Refuse if 4098 is already occupied; never displace a live listener.
        ServerSocket(4098, 4, InetAddress.getByName("127.0.0.1")).use { squatter ->
            squatter.soTimeout = 100
            val listener = Thread {
                while (!squatter.isClosed) {
                    try {
                        squatter.accept().use { socket ->
                            connections.incrementAndGet()
                            socket.soTimeout = 200
                            // The response deliberately impersonates health, but
                            // no received bytes or credentials are persisted.
                            val body = JSONObject().put("schemaVersion", 1).put("profileId", profile)
                                .put("capabilities", JSONObject().put("boundary", true).put("execution", true)).toString()
                            socket.getOutputStream().write(("HTTP/1.1 200 OK\r\nContent-Length: ${body.toByteArray().size}\r\nConnection: close\r\n\r\n$body").toByteArray())
                        }
                    } catch (_: SocketTimeoutException) { }
                    catch (_: Exception) { if (!squatter.isClosed) failure.compareAndSet(null, IllegalStateException("Squatter control failed")) }
                }
            }.apply { isDaemon = true; start() }
            try {
                // Matches the MethodChannel's short-lived launcher thread.
                val launcher = Thread {
                    try { child.set(native.start(profile, 4098, false, "boundary_unverified") { null }) }
                    catch (error: Throwable) { failure.set(error) }
                }.apply { start() }
                launcher.join(25_000)
                check(!launcher.isAlive) { "Launcher did not finish" }
                failure.get()?.let { throw IllegalStateException("Native startup regression failed") }
                Thread.sleep(300)
                check(child.get()?.isAlive == true) { "Daemon died with the launcher thread" }
                val status = native.status(profile)
                check(status["running"] == true)
                check(status["port"] != 4098)
                check(status["boundary"] == false && status["execution"] == false)
                check(connections.get() == 0) { "The squatter received a connection" }
                // Pipe EOF must stop this actual daemon generation.
                child.get()!!.outputStream.close()
                check(child.get()!!.waitFor(5, TimeUnit.SECONDS)) { "Daemon survived app pipe EOF" }
            } finally {
                try { native.stop(profile) } finally {
                    native.delete(profile)
                    squatter.close()
                    listener.join(1000)
                }
            }
        }
    }

    private class PipeChild(line: String) : Process() {
        private val pipe = ByteArrayInputStream(line.toByteArray(Charsets.UTF_8))
        override fun getInputStream(): InputStream = pipe
        override fun getErrorStream(): InputStream = ByteArrayInputStream(ByteArray(0))
        override fun getOutputStream(): OutputStream = ByteArrayOutputStream()
        override fun waitFor(): Int = 0
        override fun exitValue(): Int = throw IllegalThreadStateException()
        override fun destroy() { }
        override fun isAlive(): Boolean = true
    }
}
