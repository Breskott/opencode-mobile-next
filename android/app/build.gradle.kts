import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

android {
    namespace = "io.github.eslamasabry.opencode_mobile"
    // flutter_secure_storage 11 ships AAR metadata that requires API 37;
    // Flutter 3.47 still defaults to 36. Pin explicitly until Flutter's
    // default catches up, then drop this back to flutter.compileSdkVersion.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.eslamasabry.opencode_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let(::file)
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

android {
    // proot and its loader ship as native libraries and must exist as real
    // files in the app's native library folder: the one place this app may
    // run programs from (BuiltinLinux.kt).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    // ShortcutManagerCompat for the pinned-session launcher shortcuts
    // (PinnedSessionShortcuts.kt); same major line the Flutter embedding
    // already pulls in transitively, pinned so the compile classpath is
    // explicit rather than inherited.
    implementation("androidx.core:core:1.13.1")
    // Reads the Ubuntu Base tarball for the built-in Linux (BuiltinLinux.kt).
    implementation("org.apache.commons:commons-compress:1.27.1")
    // The local terminal's PTY (LocalTerminal.kt): Termux's terminal-emulator
    // library, Apache 2.0 (NOTICE). Only this module: termux-app itself and
    // termux-shared are GPLv3 and must not be used.
    implementation("com.github.termux.termux-app:terminal-emulator:v0.118.3")
}

repositories {
    // JitPack builds the Termux terminal libraries from their release tags.
    // Limited to that group so no other dependency can resolve from it.
    exclusiveContent {
        forRepository { maven("https://jitpack.io") }
        filter { includeGroup("com.github.termux.termux-app") }
    }
}
