plugins {
    id("com.android.application")
}

android {
    namespace = "dev.fluttware.runner"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.fluttware.runner"
        minSdk = 26
        // Deliberately matches Sketchware Pro's legacy execution model for this
        // experiment. Android only permits execve() from the writable app home
        // for apps targeting API 28 or lower. This is not the final production
        // configuration; the modern packaging experiment uses nativeLibraryDir.
        targetSdk = 28
        versionCode = 17
        versionName = "0.17-direct-flutter-debug"
    }
}
