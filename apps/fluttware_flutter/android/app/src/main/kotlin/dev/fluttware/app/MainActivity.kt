package com.flutterware.app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.ContextCompat
import com.flutterware.app.runtime.ApkInstallCoordinator
import com.flutterware.app.projects.ProjectStore
import com.flutterware.app.projects.ProjectFileStore
import com.flutterware.app.runtime.RuntimeService
import com.flutterware.app.runtime.RuntimeStateStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val installWorker = Executors.newSingleThreadExecutor()
    private var pendingIconPickerResult: MethodChannel.Result? = null
    private var pendingAssetPicker: PendingAssetPicker? = null
    private var pendingInstallAfterPermission = false

    private data class PendingAssetPicker(
        val result: MethodChannel.Result,
        val projectId: String,
        val kind: String,
    )

    private val installReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val status = intent.getIntExtra(
                PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE,
            )
            when (status) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    val confirmation = if (Build.VERSION.SDK_INT >= 33) {
                        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_INTENT)
                    }
                    confirmation?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    confirmation?.let(::startActivity)
                }
                PackageInstaller.STATUS_SUCCESS -> {
                    RuntimeStateStore.installation("Application installed", installed = true)
                    RuntimeStateStore.currentPackage()?.let(::launchGeneratedApp)
                }
                else -> {
                    val detail = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                        ?: "Installer status $status"
                    RuntimeStateStore.installation("Installation failed: $detail")
                    RuntimeStateStore.log("Installer failure: $detail")
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(ApkInstallCoordinator.ACTION_INSTALL_STATUS)
        ContextCompat.registerReceiver(
            this,
            installReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onResume() {
        super.onResume()
        if (pendingInstallAfterPermission &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls())
        ) {
            pendingInstallAfterPermission = false
            stageCurrentApk()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRuntimeState" -> result.success(RuntimeStateStore.snapshot())
                "listProjects" -> runProjectOperation(result) {
                    ProjectStore.list(this)
                }
                "createProject" -> runProjectOperation(result) {
                    ProjectStore.create(this, call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                }
                "pickProjectIcon" -> pickProjectIcon(result)
                "importProjectAsset" -> pickProjectAsset(
                    call.argument<String>("id").orEmpty(),
                    call.argument<String>("kind").orEmpty(),
                    result,
                )
                "openExternalUrl" -> openExternalUrl(
                    call.argument<String>("url").orEmpty(),
                    result,
                )
                "updateProjectEditor" -> runProjectOperation(result) {
                    ProjectStore.updateEditor(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.argument<Boolean>("hasButton") ?: false,
                        call.argument<String>("buttonText").orEmpty(),
                    )
                }
                "listProjectFiles" -> runProjectOperation(result) {
                    ProjectFileStore.list(this, call.argument<String>("id").orEmpty())
                }
                "readProjectFile" -> runProjectOperation(result) {
                    ProjectFileStore.read(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.argument<String>("path").orEmpty(),
                    )
                }
                "writeProjectFile" -> runProjectOperation(result) {
                    ProjectFileStore.write(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.argument<String>("path").orEmpty(),
                        call.argument<String>("content").orEmpty(),
                    )
                    null
                }
                "listCustomWidgets" -> runProjectOperation(result) {
                    ProjectFileStore.listCustomWidgets(
                        this,
                        call.argument<String>("id").orEmpty(),
                    )
                }
                "createCustomWidget" -> runProjectOperation(result) {
                    ProjectFileStore.createCustomWidget(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any>(),
                        createFile = true,
                    )
                }
                "registerCustomWidget" -> runProjectOperation(result) {
                    ProjectFileStore.createCustomWidget(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any>(),
                        createFile = false,
                    )
                }
                "updateCounterStep" -> runProjectOperation(result) {
                    ProjectStore.updateCounterStep(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.argument<Int>("step") ?: 1,
                    )
                    null
                }
                "readProjectDesign" -> runProjectOperation(result) {
                    ProjectStore.readDesign(
                        this,
                        call.argument<String>("id").orEmpty(),
                    )
                }
                "writeProjectDesign" -> runProjectOperation(result) {
                    ProjectStore.updateDesign(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.argument<String>("content").orEmpty(),
                    )
                    null
                }
                "readProjectLogic" -> runProjectOperation(result) {
                    ProjectStore.readLogic(
                        this,
                        call.argument<String>("id").orEmpty(),
                    )
                }
                "writeProjectLogic" -> runProjectOperation(result) {
                    ProjectStore.updateLogic(
                        this,
                        call.argument<String>("id").orEmpty(),
                        call.argument<String>("content").orEmpty(),
                    )
                    null
                }
                "startCreateBuild" -> {
                    val projectId = call.argument<String>("projectId").orEmpty()
                    val projectName = call.argument<String>("projectName").orEmpty()
                    val androidPackage = call.argument<String>("packageName").orEmpty()
                    if (RuntimeStateStore.isBusy()) {
                        result.error("busy", "A local build is already running", null)
                    } else {
                        RuntimeService.start(
                            this,
                            projectId,
                            projectName,
                            androidPackage,
                        )
                        result.success(mapOf("accepted" to true))
                    }
                }
                "cancelBuild" -> {
                    RuntimeService.cancel(this)
                    result.success(null)
                }
                "installAndLaunch" -> installAndLaunch(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                RuntimeStateStore.setListener { event -> sink.success(event) }
            }

            override fun onCancel(arguments: Any?) {
                RuntimeStateStore.setListener(null)
            }
        })
    }

    private fun pickProjectIcon(result: MethodChannel.Result) {
        if (pendingIconPickerResult != null || pendingAssetPicker != null) {
            result.error("picker_busy", "A file picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/png", "image/jpeg", "image/webp"))
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("picker_missing", "No image picker is available", null)
            return
        }
        pendingIconPickerResult = result
        startActivityForResult(intent, ICON_PICKER_REQUEST)
    }

    private fun pickProjectAsset(
        projectId: String,
        kind: String,
        result: MethodChannel.Result,
    ) {
        if (pendingIconPickerResult != null || pendingAssetPicker != null) {
            result.error("picker_busy", "A file picker is already open", null)
            return
        }
        val mimeTypes = when (kind) {
            "image" -> arrayOf("image/png", "image/jpeg", "image/webp", "image/gif")
            "font" -> arrayOf("font/ttf", "font/otf", "application/x-font-ttf", "application/x-font-opentype")
            "sound" -> arrayOf("audio/*")
            "file" -> arrayOf("*/*")
            else -> {
                result.error("invalid_asset", "Unsupported asset type: $kind", null)
                return
            }
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeTypes.first()
            if (mimeTypes.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("picker_missing", "No file picker is available", null)
            return
        }
        pendingAssetPicker = PendingAssetPicker(result, projectId, kind)
        startActivityForResult(intent, ASSET_PICKER_REQUEST)
    }

    @Deprecated("Deprecated by Android; retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ASSET_PICKER_REQUEST) {
            finishAssetPicker(resultCode, data)
            return
        }
        if (requestCode != ICON_PICKER_REQUEST) return
        val result = pendingIconPickerResult ?: return
        pendingIconPickerResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        installWorker.execute {
            try {
                val bytes = readImage(uri)
                runOnUiThread { result.success(bytes) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("invalid_icon", error.message ?: "Could not read the image", null)
                }
            }
        }
    }

    private fun finishAssetPicker(resultCode: Int, data: Intent?) {
        val pending = pendingAssetPicker ?: return
        pendingAssetPicker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.result.success(null)
            return
        }
        installWorker.execute {
            try {
                val mimeType = contentResolver.getType(uri).orEmpty()
                val displayName = assetDisplayName(uri, mimeType, pending.kind)
                val imported = contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "Could not open the selected asset" }
                    ProjectFileStore.importAsset(
                        this,
                        pending.projectId,
                        pending.kind,
                        displayName,
                        input,
                    )
                }
                runOnUiThread { pending.result.success(imported) }
            } catch (error: Throwable) {
                runOnUiThread {
                    pending.result.error(
                        "asset_import_failed",
                        error.message ?: "Could not import the asset",
                        null,
                    )
                }
            }
        }
    }

    private fun assetDisplayName(uri: Uri, mimeType: String, kind: String): String {
        var name = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }.orEmpty()
        if (name.isBlank()) name = kind
        if (!name.contains('.')) {
            val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
            if (!extension.isNullOrBlank()) name += ".$extension"
        }
        return name
    }

    private fun readImage(uri: Uri): ByteArray {
        val mimeType = contentResolver.getType(uri).orEmpty()
        require(mimeType.isEmpty() || mimeType.startsWith("image/")) {
            "Select a PNG, JPEG or WebP image"
        }
        val output = ByteArrayOutputStream()
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Could not open the selected image" }
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                output.write(buffer, 0, count)
                require(output.size() <= MAX_ICON_BYTES) { "The image must be 8 MB or smaller" }
            }
        }
        return output.toByteArray().also { require(it.isNotEmpty()) { "The image is empty" } }
    }

    private fun openExternalUrl(url: String, result: MethodChannel.Result) {
        val uri = Uri.parse(url)
        if (uri.scheme != "https" && uri.scheme != "http") {
            result.error("invalid_url", "Only web links can be opened", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW, uri)
        if (intent.resolveActivity(packageManager) == null) {
            result.error("missing_browser", "No browser is available", null)
            return
        }
        startActivity(intent)
        result.success(null)
    }

    private fun installAndLaunch(result: MethodChannel.Result) {
        val apkPath = RuntimeStateStore.currentApk()
        if (apkPath == null) {
            result.error("missing_apk", "Build an APK first", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingInstallAfterPermission = true
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.success(mapOf("permissionRequired" to true))
            return
        }

        stageCurrentApk(result)
    }

    private fun stageCurrentApk(result: MethodChannel.Result? = null) {
        val apkPath = RuntimeStateStore.currentApk()
        if (apkPath == null) {
            result?.error("missing_apk", "Build an APK first", null)
            return
        }
        installWorker.execute {
            try {
                ApkInstallCoordinator.stage(this, File(apkPath))
                runOnUiThread {
                    RuntimeStateStore.installation("Waiting for Android confirmation")
                    result?.success(mapOf("staged" to true))
                }
            } catch (error: Throwable) {
                runOnUiThread {
                    if (result != null) {
                        result.error("install_failed", error.message, null)
                    } else {
                        RuntimeStateStore.installation(
                            "Installation failed: ${error.message ?: "unknown error"}",
                        )
                    }
                }
            }
        }
    }

    private fun runProjectOperation(
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        try {
            result.success(operation())
        } catch (error: Throwable) {
            result.error("project_error", error.message, null)
        }
    }

    private fun launchGeneratedApp(generatedPackage: String) {
        val launch = packageManager.getLaunchIntentForPackage(generatedPackage)
            ?: Intent(Intent.ACTION_MAIN).apply {
                setClassName(generatedPackage, GENERATED_MAIN_ACTIVITY)
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        try {
            startActivity(launch)
            RuntimeStateStore.log("Launched installed package: $generatedPackage")
        } catch (error: Throwable) {
            val detail = error.message ?: error.javaClass.simpleName
            RuntimeStateStore.installation("Installed, but launch failed: $detail")
            RuntimeStateStore.log("Could not launch installed package $generatedPackage: $detail")
        }
    }

    override fun onDestroy() {
        unregisterReceiver(installReceiver)
        installWorker.shutdownNow()
        RuntimeStateStore.setListener(null)
        super.onDestroy()
    }

    companion object {
        private const val METHOD_CHANNEL = "com.flutterware.app/runtime"
        private const val EVENT_CHANNEL = "com.flutterware.app/runtime_events"
        private const val GENERATED_MAIN_ACTIVITY =
            "com.example.fluttware_reference.MainActivity"
        private const val ICON_PICKER_REQUEST = 4801
        private const val ASSET_PICKER_REQUEST = 4802
        private const val MAX_ICON_BYTES = 8 * 1024 * 1024
    }
}
