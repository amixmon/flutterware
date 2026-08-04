import org.gradle.api.file.RelativePath
import org.gradle.api.tasks.Sync

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.flutterware.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.flutterware.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += "arm64-v8a"
        }

        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=none"
            }
        }
    }

    androidResources {
        noCompress += "zip"
    }

    sourceSets {
        getByName("main") {
            // Reuse the production launcher artwork as the default icon source
            // for APKs packaged locally by Flutterware.
            assets.srcDir("src/main/res/mipmap-xxxhdpi")
            jniLibs.srcDir(layout.buildDirectory.dir("generated/flutterware/jniLibs").get().asFile)
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    packaging {
        jniLibs {
            // Executable toolchain entry points must be real files below
            // applicationInfo.nativeLibraryDir, not mmap'd directly from the APK.
            useLegacyPackaging = true
            keepDebugSymbols += "**/libflutterware_*.so"
        }
    }

    lint {
        disable += "ExpiredTargetSdkVersion"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

val generatedLauncherDirectory =
    layout.buildDirectory.dir("generated/flutterware/jniLibs/arm64-v8a")
val expectedNativeLaunchers = listOf(
    "libflutterware_probe.so",
    "libflutterware_dart.so",
    "libflutterware_dartvm.so",
    "libflutterware_dartaotruntime.so",
    "libflutterware_java.so",
    "libflutterware_javac.so",
    "libflutterware_jar.so",
    "libflutterware_jarsigner.so",
    "libflutterware_keytool.so",
    "libflutterware_jexec.so",
    "libflutterware_jspawnhelper.so",
    "libflutterware_aapt2.so",
)

val prepareNativeLaunchers by tasks.registering(Sync::class) {
    into(generatedLauncherDirectory)
    includeEmptyDirs = false

    fun org.gradle.api.file.CopySpec.singleFile(
        archive: File,
        sourcePath: String,
        outputName: String,
    ) {
        from(zipTree(archive)) {
            include(sourcePath)
            eachFile { relativePath = RelativePath(true, outputName) }
            includeEmptyDirs = false
        }
    }

    singleFile(
        file("src/main/assets/dart/dart-sdk-3.12.2-android-arm64.zip"),
        "dart-sdk/bin/dart",
        "libflutterware_dart.so",
    )
    singleFile(
        file("src/main/assets/dart/dart-sdk-3.12.2-android-arm64.zip"),
        "dart-sdk/bin/dartvm",
        "libflutterware_dartvm.so",
    )
    singleFile(
        file("src/main/assets/dart/dart-sdk-3.12.2-android-arm64.zip"),
        "dart-sdk/bin/dartaotruntime",
        "libflutterware_dartaotruntime.so",
    )
    for (launcher in listOf("java", "javac", "jar", "jarsigner", "keytool")) {
        singleFile(
            file("src/main/assets/jdk/openjdk-21.0.12-android-arm64.zip"),
            "jdk/bin/$launcher",
            "libflutterware_$launcher.so",
        )
    }
    singleFile(
        file("src/main/assets/jdk/openjdk-21.0.12-android-arm64.zip"),
        "jdk/lib/jexec",
        "libflutterware_jexec.so",
    )
    singleFile(
        file("src/main/assets/jdk/openjdk-21.0.12-android-arm64.zip"),
        "jdk/lib/jspawnhelper",
        "libflutterware_jspawnhelper.so",
    )
    singleFile(
        file("src/main/assets/android-sdk/android-sdk-36-arm64.zip"),
        "android-sdk/build-tools/36.0.0/aapt2",
        "libflutterware_aapt2.so",
    )
    from(file("../../../../poc/android-runner/app/src/main/assets/native/fluttware-probe-arm64-v8a")) {
        rename { "libflutterware_probe.so" }
    }

    doLast {
        val outputDirectory = generatedLauncherDirectory.get().asFile
        val elfMagic = byteArrayOf(0x7f, 'E'.code.toByte(), 'L'.code.toByte(), 'F'.code.toByte())
        for (name in expectedNativeLaunchers) {
            val launcher = outputDirectory.resolve(name)
            check(launcher.isFile && launcher.length() > 4) {
                "Required native launcher was not generated: $launcher"
            }
            val magic = launcher.inputStream().use { it.readNBytes(4) }
            check(magic.contentEquals(elfMagic)) {
                "Native launcher is not an ELF file: $launcher"
            }
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(prepareNativeLaunchers)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
