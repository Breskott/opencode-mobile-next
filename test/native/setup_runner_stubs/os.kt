package android.system
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.StandardCopyOption
object Os {
    fun rename(from: String, to: String) {
        Files.move(Paths.get(from), Paths.get(to), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
    }
}
