package io.github.eslamasabry.opencode_mobile
import android.content.Context
import java.io.File
class BuiltinLinux private constructor(context: Context) {
    val home: File = context.filesDir
    val installed = true
    enum class InstallStage { DOWNLOAD, UNPACK }
    interface InstallProgress {
        fun stage(which: InstallStage)
        fun bytes(done: Long, total: Long)
        fun log(line: String)
        val cancelled: Boolean
    }
    fun install(progress: InstallProgress) {}
    fun start(script: String, directory: String?): Process = ProcessBuilder("sh", "-c", script).start()
    companion object {
        const val TAG = "test"
        const val VERSION = "test"
        fun get(context: Context) = BuiltinLinux(context)
        fun stopTree(process: Process, graceMs: Long = 0) { process.destroyForcibly() }
    }
}
object SetupService {
    fun start(context: Context, channel: String, title: String, text: String) {}
    fun stop(context: Context) {}
    fun finish(context: Context, channel: String, title: String, done: Boolean) {}
    fun update(context: Context, channel: String, title: String, text: String) {}
}
