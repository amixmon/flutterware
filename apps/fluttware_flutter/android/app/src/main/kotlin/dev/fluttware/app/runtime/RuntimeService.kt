package com.flutterware.app.runtime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.system.Os
import androidx.core.content.ContextCompat
import com.flutterware.app.MainActivity
import com.flutterware.app.R
import com.flutterware.app.projects.ProjectStore
import dev.fluttware.runner.AndroidSdkInstaller
import dev.fluttware.runner.DartSdkInstaller
import dev.fluttware.runner.FlutterDebugInstaller
import dev.fluttware.runner.FlutterToolInstaller
import dev.fluttware.runner.JdkInstaller
import java.io.File
import java.io.FileOutputStream
import java.io.BufferedWriter
import java.util.concurrent.Executors

class RuntimeService : Service() {
    private val worker = Executors.newSingleThreadExecutor { task ->
        Thread(task, "fluttware-runtime").apply { isDaemon = true }
    }
    private var processExecutor: ProcessExecutor? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var logFile: File? = null
    private var logWriter: BufferedWriter? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                processExecutor?.cancel()
                RuntimeStateStore.cancelled()
                updateNotification("Build cancelled", 0, false)
            }
            ACTION_CREATE_BUILD -> {
                if (RuntimeStateStore.isBusy()) return START_NOT_STICKY
                val projectId = intent.getStringExtra(EXTRA_PROJECT_ID).orEmpty()
                val projectName = intent.getStringExtra(EXTRA_PROJECT_NAME).orEmpty()
                val androidPackage = intent.getStringExtra(EXTRA_ANDROID_PACKAGE).orEmpty()
                startForeground(NOTIFICATION_ID, notification("Starting local build", 0, true))
                worker.execute {
                    createAndBuild(
                        projectId,
                        projectName,
                        androidPackage,
                    )
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        processExecutor?.cancel()
        worker.shutdownNow()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun createAndBuild(
        projectId: String,
        projectName: String,
        androidPackage: String,
    ) {
        RuntimeStateStore.start(projectId)
        acquireWakeLock()
        val started = System.currentTimeMillis()

        try {
            validateInput(projectId, projectName, androidPackage)
            check(Build.SUPPORTED_ABIS.contains("arm64-v8a")) {
                "This runtime prototype currently requires an ARM64 device"
            }
            check(filesDir.usableSpace > 700L * 1024 * 1024) {
                "At least 700 MB of free internal storage is required"
            }

            val runtimeDir = File(filesDir, "runtime").apply { mkdirs() }
            logFile = File(runtimeDir, "latest-build.log").apply { writeText("") }
            logWriter = logFile!!.bufferedWriter()
            log("Flutterware local build started")
            log("Project: $projectName ($projectId)")

            phase("preparing", "Installing Dart SDK", 0.08)
            val dart = DartSdkInstaller.install(this)
            logInstall("Dart", dart.reused, dart.elapsedMillis)

            phase("preparing", "Installing Flutter tools", 0.18)
            val flutter = FlutterToolInstaller.install(this, dart.sdkRoot)
            logInstall("Flutter tools", flutter.reused, flutter.elapsedMillis)

            phase("preparing", "Installing Flutter debug engine", 0.30)
            val debug = FlutterDebugInstaller.install(this)
            logInstall("Flutter debug engine", debug.reused, debug.elapsedMillis)

            phase("preparing", "Installing OpenJDK", 0.40)
            val jdk = JdkInstaller.install(this)
            logInstall("OpenJDK", jdk.reused, jdk.elapsedMillis)

            phase("preparing", "Installing Android SDK", 0.52)
            val androidSdk = AndroidSdkInstaller.install(this)
            logInstall("Android SDK", androidSdk.reused, androidSdk.elapsedMillis)

            val projectsRoot = File(filesDir, "projects").apply { mkdirs() }
            val project = File(projectsRoot, projectId)
            requireInside(projectsRoot, project)
            ProjectStore.ensureScaffold(this, projectId)
            val baseEnvironment = environment(dart, flutter, jdk, androidSdk)
            processExecutor = ProcessExecutor(::log)

            phase("creating", "Preparing project sources", 0.60)
            log("Using project sources at ${project.absolutePath}")

            phase("resolving", "Resolving Flutter packages", 0.68)
            runChecked(
                listOf(
                    dart.dart().absolutePath,
                    flutter.toolKernel().absolutePath,
                    "--suppress-analytics",
                    "--no-version-check",
                    "pub",
                    "get",
                    "--directory",
                    project.absolutePath,
                ),
                project,
                baseEnvironment,
                "Package resolution",
            )

            val scripts = installScripts()
            val launcherIcon = installLauncherIcon(projectId)
            val buildRoot = File(project, "build/fluttware")
            val kernelRoot = File(buildRoot, "kernel")
            val kernel = File(kernelRoot, "app.dill")
            val apk = File(project, "build/app-debug.apk")
            val signingKey = File(filesDir, "signing/fluttware-debug.jks")
            val generatedPackage = androidPackage

            phase("compiling", "Compiling Dart kernel", 0.78)
            runChecked(
                listOf(
                    "/system/bin/sh",
                    scripts.first.absolutePath,
                    filesDir.absolutePath,
                    flutter.flutterRoot.absolutePath,
                    debug.debugRoot.absolutePath,
                    project.absolutePath,
                    kernelRoot.absolutePath,
                ),
                project,
                baseEnvironment,
                "Dart kernel compilation",
            )

            phase("packaging", "Packaging and signing APK", 0.90)
            runChecked(
                listOf(
                    "/system/bin/sh",
                    scripts.second.absolutePath,
                    jdk.javaHome.absolutePath,
                    androidSdk.sdkRoot.absolutePath,
                    debug.debugRoot.absolutePath,
                    kernel.absolutePath,
                    buildRoot.absolutePath,
                    apk.absolutePath,
                    generatedPackage,
                    safeLabel(projectName),
                    signingKey.absolutePath,
                    launcherIcon.absolutePath,
                ),
                project,
                baseEnvironment,
                "APK packaging",
            )

            check(apk.isFile() && apk.length() > 0) { "Build finished without an APK" }
            val elapsed = System.currentTimeMillis() - started
            log("Build completed in ${elapsed}ms")
            log("APK: ${apk.absolutePath} (${apk.length()} bytes)")
            RuntimeStateStore.complete(apk.absolutePath, generatedPackage)
            updateNotification("APK ready", 100, false)
        } catch (_: InterruptedException) {
            RuntimeStateStore.cancelled()
            updateNotification("Build cancelled", 0, false)
        } catch (error: Throwable) {
            log("ERROR: ${error.stackTraceToString()}")
            RuntimeStateStore.fail(error)
            updateNotification("Build failed", 0, false)
        } finally {
            runCatching { logWriter?.flush() }
            runCatching { logWriter?.close() }
            logWriter = null
            processExecutor = null
            releaseWakeLock()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun environment(
        dart: DartSdkInstaller.Result,
        flutter: FlutterToolInstaller.Result,
        jdk: JdkInstaller.Result,
        androidSdk: AndroidSdkInstaller.Result,
    ): Map<String, String> {
        val pubCache = File(filesDir, "pub-cache").apply { mkdirs() }
        val temporary = File(cacheDir, "build-tmp").apply { mkdirs() }
        return mapOf(
            "HOME" to filesDir.absolutePath,
            "TMPDIR" to temporary.absolutePath,
            "PUB_CACHE" to pubCache.absolutePath,
            "JAVA_HOME" to jdk.javaHome.absolutePath,
            "ANDROID_HOME" to androidSdk.sdkRoot.absolutePath,
            "ANDROID_SDK_ROOT" to androidSdk.sdkRoot.absolutePath,
            "FLUTTER_ROOT" to flutter.flutterRoot.absolutePath,
            "FLUTTER_ALREADY_LOCKED" to "true",
            "CI" to "true",
            "LD_LIBRARY_PATH" to "${androidSdk.libraryPath()}:${jdk.libraryPath()}",
            "PATH" to listOf(
                File(jdk.javaHome, "bin").absolutePath,
                flutter.compatibilityBin.absolutePath,
                File(flutter.flutterRoot, "bin").absolutePath,
                File(dart.sdkRoot, "bin").absolutePath,
                "/system/bin",
                "/system/xbin",
            ).joinToString(":"),
        )
    }

    private fun runChecked(
        command: List<String>,
        directory: File,
        environment: Map<String, String>,
        label: String,
    ) {
        val result = processExecutor!!.run(command, directory, environment)
        log("$label exit=${result.exitCode} elapsedMs=${result.elapsedMillis}")
        check(result.exitCode == 0) { "$label failed with exit code ${result.exitCode}" }
    }

    private fun installScripts(): Pair<File, File> {
        val directory = File(cacheDir, "runtime-scripts").apply { mkdirs() }
        val kernel = File(directory, "flutter-kernel.sh")
        val packageApk = File(directory, "package-flutter-debug.sh")
        copyAsset("direct-build/flutter-kernel.sh", kernel)
        copyAsset("direct-build/package-flutter-debug.sh", packageApk)
        Os.chmod(kernel.absolutePath, 0x1C0)
        Os.chmod(packageApk.absolutePath, 0x1C0)
        return kernel to packageApk
    }

    private fun installLauncherIcon(projectId: String): File {
        val icon = File(cacheDir, "runtime-scripts/ic_launcher.png")
        val customIcon = ProjectStore.launcherIcon(this, projectId)
        if (customIcon == null) {
            copyAsset("ic_launcher.png", icon)
        } else {
            customIcon.inputStream().use { input ->
                FileOutputStream(icon).use { output -> input.copyTo(output, 256 * 1024) }
            }
        }
        check(icon.isFile && icon.length() > 0) { "Default launcher icon is missing" }
        return icon
    }

    private fun copyAsset(asset: String, destination: File) {
        destination.parentFile?.mkdirs()
        assets.open(asset).use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output, 256 * 1024) }
        }
    }

    private fun validateInput(
        projectId: String,
        projectName: String,
        androidPackage: String,
    ) {
        require(Regex("^[a-z][a-z0-9_]{2,30}$").matches(projectId)) {
            "Invalid project identifier"
        }
        require(projectName.isNotBlank() && projectName.length <= 40) {
            "Project name must contain 1 to 40 characters"
        }
        require(Regex("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$").matches(androidPackage)) {
            "Invalid Android package name"
        }
    }

    private fun safeLabel(value: String): String =
        value.replace(Regex("[^A-Za-z0-9 _-]"), "").take(40).ifBlank { "Flutterware App" }

    private fun requireInside(parent: File, child: File) {
        val parentPath = parent.canonicalPath + File.separator
        require(child.canonicalPath.startsWith(parentPath)) { "Project path escaped workspace" }
    }

    private fun logInstall(name: String, reused: Boolean, elapsed: Long) {
        log("$name ${if (reused) "reused" else "installed"} in ${elapsed}ms")
    }

    private fun phase(id: String, text: String, progress: Double) {
        runCatching { logWriter?.flush() }
        RuntimeStateStore.update(id, text, progress)
        updateNotification(text, (progress * 100).toInt(), true)
        log(text)
    }

    private fun log(line: String) {
        RuntimeStateStore.log(line)
        synchronized(this) {
            logWriter?.apply {
                write(line)
                newLine()
            }
        }
    }

    private fun acquireWakeLock() {
        val manager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Flutterware:LocalBuild")
            .apply { acquire(20 * 60 * 1000L) }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Local builds",
                NotificationManager.IMPORTANCE_LOW,
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun notification(text: String, progress: Int, ongoing: Boolean): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(getColor(R.color.flutterware_brand_primary))
            .setContentTitle("Flutterware local build")
            .setContentText(text)
            .setContentIntent(openApp)
            .setOnlyAlertOnce(true)
            .setOngoing(ongoing)
            .setProgress(100, progress, progress <= 0 && ongoing)
            .build()
    }

    private fun updateNotification(text: String, progress: Int, ongoing: Boolean) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification(text, progress, ongoing))
    }

    companion object {
        private const val CHANNEL_ID = "flutterware_builds"
        private const val NOTIFICATION_ID = 4127
        private const val ACTION_CREATE_BUILD = "com.flutterware.app.CREATE_BUILD"
        private const val ACTION_CANCEL = "com.flutterware.app.CANCEL_BUILD"
        private const val EXTRA_PROJECT_ID = "project_id"
        private const val EXTRA_PROJECT_NAME = "project_name"
        private const val EXTRA_ANDROID_PACKAGE = "android_package"

        fun start(
            context: Context,
            projectId: String,
            projectName: String,
            androidPackage: String,
        ) {
            val intent = Intent(context, RuntimeService::class.java)
                .setAction(ACTION_CREATE_BUILD)
                .putExtra(EXTRA_PROJECT_ID, projectId)
                .putExtra(EXTRA_PROJECT_NAME, projectName)
                .putExtra(EXTRA_ANDROID_PACKAGE, androidPackage)
            ContextCompat.startForegroundService(context, intent)
        }

        fun cancel(context: Context) {
            context.startService(
                Intent(context, RuntimeService::class.java).setAction(ACTION_CANCEL),
            )
        }
    }
}
