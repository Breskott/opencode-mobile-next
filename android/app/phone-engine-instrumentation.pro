# Preview-only: keep the ABI shared by separately shrunk app/test APKs.
# Native proofs use the same packaged executables and hashes as other releases.
-keep class kotlin.** { *; }
-keep class io.github.eslamasabry.opencode_mobile.** { *; }
