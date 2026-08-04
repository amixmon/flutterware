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
        // Temporary compatibility mode for the on-device compiler prototype.
        // Android blocks execve() from writable app storage for targetSdk 29+.
        // The production runtime will relocate launchers to nativeLibraryDir.
        targetSdk = 28
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    androidResources {
        noCompress += "zip"
    }

    sourceSets {
        getByName("main") {
            // Reuse the production launcher artwork as the default icon source
            // for APKs packaged locally by Flutterware.
            assets.srcDir("src/main/res/mipmap-xxxhdpi")
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
