package com.flutterware.app.projects

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.media.ExifInterface
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File

object ProjectStore {
    private const val METADATA_FILE = "fluttware-project.json"
    private val idPattern = Regex("^[a-z][a-z0-9_]{2,30}$")
    private val packagePattern = Regex("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")

    fun list(context: Context): List<Map<String, Any?>> {
        val root = projectsRoot(context)
        return root.listFiles()
            ?.asSequence()
            ?.filter { it.isDirectory }
            ?.mapNotNull { directory ->
                runCatching { directory to readMetadata(directory) }.getOrNull()
            }
            ?.sortedByDescending { it.second.optLong("updatedAt") }
            ?.map { (directory, metadata) -> toMap(directory, metadata) }
            ?.toList()
            ?: emptyList()
    }

    fun create(context: Context, values: Map<*, *>): Map<String, Any?> {
        val id = values["id"] as? String ?: error("Project identifier is missing")
        val name = values["name"] as? String ?: error("Application name is missing")
        val packageName = values["packageName"] as? String ?: error("Package name is missing")
        val color = (values["color"] as? Number)?.toLong() ?: 0xFF168CF3L
        validate(id, name, packageName)
        val appIcon = (values["iconBytes"] as? ByteArray)?.let(::normalizeAppIcon)

        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        check(!File(directory, METADATA_FILE).exists()) { "A project named $id already exists" }
        check(directory.isDirectory || directory.mkdirs()) { "Could not create project directory" }

        val now = System.currentTimeMillis()
        val metadata = JSONObject()
            .put("schemaVersion", 2)
            .put("id", id)
            .put("name", name.trim())
            .put("packageName", packageName)
            .put("color", color)
            .put("pinned", false)
            .put("hasButton", false)
            .put("buttonText", "Button")
            .put("hasCustomIcon", appIcon != null)
            .put("createdAt", now)
            .put("updatedAt", now)
        FlutterProjectScaffold.create(directory, metadata)
        if (appIcon != null) {
            val iconFile = File(directory, ".fluttware/app-icon.png")
            iconFile.parentFile?.mkdirs()
            iconFile.writeBytes(appIcon)
        }
        writeMetadata(directory, metadata)
        return toMap(directory, metadata)
    }

    fun launcherIcon(context: Context, id: String): File? {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        return File(directory, ".fluttware/app-icon.png")
            .takeIf { it.isFile && it.length() > 0 }
    }

    fun updateEditor(
        context: Context,
        id: String,
        hasButton: Boolean,
        buttonText: String,
    ): Map<String, Any?> {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        require(buttonText.length <= 40) { "Button text is too long" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        val metadata = readMetadata(directory)
            .put("hasButton", hasButton)
            .put("buttonText", buttonText.ifBlank { "Button" })
            .put("updatedAt", System.currentTimeMillis())
        FlutterProjectScaffold.regenerate(directory, metadata)
        writeMetadata(directory, metadata)
        return toMap(directory, metadata)
    }

    fun ensureScaffold(context: Context, id: String): File {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        val metadata = readMetadata(directory)
        FlutterProjectScaffold.ensure(directory, metadata)
        return directory
    }

    fun updateCounterStep(context: Context, id: String, step: Int) {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        val metadata = readMetadata(directory)
        FlutterProjectScaffold.ensure(directory, metadata)
        FlutterProjectScaffold.updateCounterStep(directory, metadata, step)
        metadata.put("updatedAt", System.currentTimeMillis())
        writeMetadata(directory, metadata)
    }

    fun readDesign(context: Context, id: String): String {
        val directory = ensureScaffold(context, id)
        return FlutterProjectScaffold.readDesign(directory)
    }

    fun updateDesign(context: Context, id: String, source: String) {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        val metadata = readMetadata(directory)
        FlutterProjectScaffold.ensure(directory, metadata)
        FlutterProjectScaffold.updateDesign(directory, metadata, source)
        metadata.put("updatedAt", System.currentTimeMillis())
        writeMetadata(directory, metadata)
    }

    fun readLogic(context: Context, id: String): String {
        val directory = ensureScaffold(context, id)
        return FlutterProjectScaffold.readLogic(directory)
    }

    fun updateLogic(context: Context, id: String, source: String) {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        val metadata = readMetadata(directory)
        FlutterProjectScaffold.ensure(directory, metadata)
        FlutterProjectScaffold.updateLogic(directory, metadata, source)
        metadata.put("updatedAt", System.currentTimeMillis())
        writeMetadata(directory, metadata)
    }

    private fun projectsRoot(context: Context): File =
        File(context.filesDir, "projects").apply {
            check(isDirectory || mkdirs()) { "Could not create projects directory" }
        }

    private fun readMetadata(directory: File): JSONObject {
        val file = File(directory, METADATA_FILE)
        check(file.isFile) { "Project metadata is missing: ${directory.name}" }
        return JSONObject(file.readText())
    }

    private fun writeMetadata(directory: File, metadata: JSONObject) {
        val destination = File(directory, METADATA_FILE)
        val temporary = File(directory, "$METADATA_FILE.tmp")
        temporary.writeText(metadata.toString(2) + "\n")
        check(!destination.exists() || destination.delete()) { "Could not replace project metadata" }
        check(temporary.renameTo(destination)) { "Could not activate project metadata" }
    }

    private fun validate(id: String, name: String, packageName: String) {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        require(name.isNotBlank() && name.length <= 40) { "Application name must contain 1 to 40 characters" }
        require(packagePattern.matches(packageName)) { "Invalid Android package name" }
    }

    private fun normalizeAppIcon(source: ByteArray): ByteArray {
        require(source.isNotEmpty() && source.size <= 8 * 1024 * 1024) {
            "The app icon must be 8 MB or smaller"
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(source, 0, source.size, bounds)
        require(bounds.outWidth >= 64 && bounds.outHeight >= 64) {
            "The app icon must be at least 64 × 64 pixels"
        }
        require(bounds.outWidth <= 12_000 && bounds.outHeight <= 12_000) {
            "The selected image is too large"
        }
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > 2048 || bounds.outHeight / sampleSize > 2048) {
            sampleSize *= 2
        }
        val decoded = BitmapFactory.decodeByteArray(
            source,
            0,
            source.size,
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        ) ?: error("The selected file is not a supported image")
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(source)).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val rotation = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val bitmap = if (rotation == 0f) {
            decoded
        } else {
            Bitmap.createBitmap(
                decoded,
                0,
                0,
                decoded.width,
                decoded.height,
                Matrix().apply { postRotate(rotation) },
                true,
            ).also { decoded.recycle() }
        }
        val visible = visibleBounds(bitmap)
        val iconSize = 192f
        val maxContent = 128f
        val scale = minOf(maxContent / visible.width(), maxContent / visible.height())
        val width = visible.width() * scale
        val height = visible.height() * scale
        val target = Bitmap.createBitmap(iconSize.toInt(), iconSize.toInt(), Bitmap.Config.ARGB_8888)
        target.eraseColor(Color.TRANSPARENT)
        Canvas(target).drawBitmap(
            bitmap,
            visible,
            RectF(
                (iconSize - width) / 2f,
                (iconSize - height) / 2f,
                (iconSize + width) / 2f,
                (iconSize + height) / 2f,
            ),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
        )
        bitmap.recycle()
        return ByteArrayOutputStream().use { output ->
            check(target.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                "Could not prepare the app icon"
            }
            target.recycle()
            output.toByteArray()
        }
    }

    private fun visibleBounds(bitmap: Bitmap): Rect {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        var left = bitmap.width
        var top = bitmap.height
        var right = -1
        var bottom = -1
        for (y in 0 until bitmap.height) {
            val offset = y * bitmap.width
            for (x in 0 until bitmap.width) {
                if (Color.alpha(pixels[offset + x]) <= 8) continue
                if (x < left) left = x
                if (x > right) right = x
                if (y < top) top = y
                if (y > bottom) bottom = y
            }
        }
        require(right >= left && bottom >= top) { "The app icon cannot be fully transparent" }
        return Rect(left, top, right + 1, bottom + 1)
    }

    private fun requireInside(parent: File, child: File) {
        val parentPath = parent.canonicalPath + File.separator
        require(child.canonicalPath.startsWith(parentPath)) { "Project path escaped workspace" }
    }

    private fun toMap(directory: File, json: JSONObject): Map<String, Any?> = mapOf(
        "id" to json.getString("id"),
        "name" to json.getString("name"),
        "packageName" to json.getString("packageName"),
        "color" to json.optLong("color", 0xFF168CF3L),
        "pinned" to json.optBoolean("pinned", false),
        "hasButton" to json.optBoolean("hasButton", false),
        "buttonText" to json.optString("buttonText", "Button"),
        "hasCustomIcon" to json.optBoolean("hasCustomIcon", false),
        "iconBytes" to File(directory, ".fluttware/app-icon.png")
            .takeIf { it.isFile && it.length() > 0 }
            ?.readBytes(),
        "createdAt" to json.optLong("createdAt"),
        "updatedAt" to json.optLong("updatedAt"),
    )
}
