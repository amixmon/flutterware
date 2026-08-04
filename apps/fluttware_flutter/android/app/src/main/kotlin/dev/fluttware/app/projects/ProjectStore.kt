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
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.charset.StandardCharsets

object ProjectStore {
    private const val CURRENT_SCHEMA_VERSION = 4
    private const val METADATA_FILE = "fluttware-project.json"
    private val idPattern = Regex("^[a-z][a-z0-9_]{2,30}$")
    private val packagePattern = Regex("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
    private val dependencyNamePattern = Regex("^[a-z][a-z0-9_]{1,63}$")
    private val dependencyConstraintPattern = Regex("^[0-9A-Za-z.^<>=*+_ \\-]{1,100}$")
    private val dependencyDeclarationPattern = Regex("^  ([a-z][a-z0-9_]*):(?:\\s.*)?$")
    private val compatibilityValues = setOf(
        "pureDart",
        "flutter",
        "androidPlugin",
        "unsupported",
        "unknown",
    )
    private val themeModes = setOf("system", "light", "dark")
    private val fontFamilyPattern = Regex("^[A-Za-z0-9 _-]{1,60}$")
    private const val MANAGED_DEPENDENCIES_START = "  # Flutterware-managed dependencies."
    private const val MANAGED_DEPENDENCIES_END = "  # End Flutterware-managed dependencies."

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
            .put("schemaVersion", CURRENT_SCHEMA_VERSION)
            .put("id", id)
            .put("name", name.trim())
            .put("packageName", packageName)
            .put("color", color)
            .put(
                "theme",
                JSONObject()
                    .put("mode", "system")
                    .put("seedColor", color)
                    .put("fontFamily", JSONObject.NULL)
                    .put("cornerRadius", 16.0)
                    .put("cardElevation", 0.0)
                    .put("inputFilled", true),
            )
            .put("dependencies", JSONArray())
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

    fun updateTheme(
        context: Context,
        id: String,
        values: Map<*, *>,
    ): Map<String, Any?> {
        val mode = values["mode"]?.toString().orEmpty()
        val seedColor = (values["seedColor"] as? Number)?.toLong()
            ?: error("Theme seed color is missing")
        val fontFamily = values["fontFamily"]?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        val cornerRadius = (values["cornerRadius"] as? Number)?.toDouble() ?: 16.0
        val cardElevation = (values["cardElevation"] as? Number)?.toDouble() ?: 0.0
        val inputFilled = values["inputFilled"] as? Boolean ?: true
        require(mode in themeModes) { "Invalid project theme mode: $mode" }
        require(seedColor in 0..0xFFFFFFFFL) { "Invalid theme seed color" }
        require(fontFamily == null || fontFamilyPattern.matches(fontFamily)) {
            "Font family must use letters, numbers, spaces, underscores, or hyphens"
        }
        require(cornerRadius.isFinite() && cornerRadius in 0.0..32.0) {
            "Theme corner radius must be between 0 and 32"
        }
        require(cardElevation.isFinite() && cardElevation in 0.0..8.0) {
            "Card elevation must be between 0 and 8"
        }

        val directory = projectDirectory(context, id)
        val metadata = readMetadata(directory)
        metadata
            .put("schemaVersion", CURRENT_SCHEMA_VERSION)
            .put("color", seedColor)
            .put(
                "theme",
                JSONObject()
                    .put("mode", mode)
                    .put("seedColor", seedColor)
                    .put("fontFamily", fontFamily ?: JSONObject.NULL)
                    .put("cornerRadius", cornerRadius)
                    .put("cardElevation", cardElevation)
                    .put("inputFilled", inputFilled),
            )
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

    fun dependencies(context: Context, id: String): List<Map<String, Any?>> {
        val directory = projectDirectory(context, id)
        return dependencyMaps(readMetadata(directory).optJSONArray("dependencies"))
    }

    fun upsertDependency(
        context: Context,
        id: String,
        values: Map<*, *>,
    ): List<Map<String, Any?>> {
        val name = values["name"]?.toString()?.trim().orEmpty()
        val constraint = values["constraint"]?.toString()?.trim().orEmpty().ifBlank { "any" }
        val compatibility = values["compatibility"]?.toString()?.trim().orEmpty()
            .ifBlank { "unknown" }
        require(dependencyNamePattern.matches(name)) { "Invalid package name: $name" }
        require(dependencyConstraintPattern.matches(constraint)) {
            "Invalid hosted version constraint: $constraint"
        }
        require(compatibility in compatibilityValues) {
            "Invalid package compatibility: $compatibility"
        }
        require(name != "flutter") { "The Flutter SDK dependency cannot be replaced" }

        val directory = projectDirectory(context, id)
        val metadata = readMetadata(directory)
        val current = metadata.optJSONArray("dependencies") ?: JSONArray()
        val nextItems = mutableListOf<JSONObject>()
        for (index in 0 until current.length()) {
            val dependency = current.optJSONObject(index) ?: continue
            if (dependency.optString("name") != name) nextItems.add(dependency)
        }
        nextItems.add(
            JSONObject()
                .put("name", name)
                .put("constraint", constraint)
                .put("compatibility", compatibility)
                .put("direct", true),
        )
        nextItems.sortBy { it.getString("name") }
        val next = JSONArray().apply { nextItems.forEach(::put) }
        syncPubspecDependencies(directory, next)
        metadata
            .put("dependencies", next)
            .put("updatedAt", System.currentTimeMillis())
        writeMetadata(directory, metadata)
        return dependencyMaps(next)
    }

    fun removeDependency(context: Context, id: String, name: String): List<Map<String, Any?>> {
        require(dependencyNamePattern.matches(name)) { "Invalid package name: $name" }
        val directory = projectDirectory(context, id)
        val metadata = readMetadata(directory)
        val current = metadata.optJSONArray("dependencies") ?: JSONArray()
        val next = JSONArray()
        for (index in 0 until current.length()) {
            val dependency = current.optJSONObject(index) ?: continue
            if (dependency.optString("name") != name) next.put(dependency)
        }
        syncPubspecDependencies(directory, next)
        metadata
            .put("dependencies", next)
            .put("updatedAt", System.currentTimeMillis())
        writeMetadata(directory, metadata)
        return dependencyMaps(next)
    }

    private fun projectsRoot(context: Context): File =
        File(context.filesDir, "projects").apply {
            check(isDirectory || mkdirs()) { "Could not create projects directory" }
        }

    private fun projectDirectory(context: Context, id: String): File {
        require(idPattern.matches(id)) { "Invalid project identifier" }
        val root = projectsRoot(context)
        val directory = File(root, id)
        requireInside(root, directory)
        check(directory.isDirectory) { "Project does not exist: $id" }
        return directory
    }

    private fun readMetadata(directory: File): JSONObject {
        val file = File(directory, METADATA_FILE)
        check(file.isFile) { "Project metadata is missing: ${directory.name}" }
        val metadata = JSONObject(file.readText())
        val version = metadata.optInt("schemaVersion", 1)
        require(version <= CURRENT_SCHEMA_VERSION) {
            "Project ${directory.name} uses unsupported schema version $version"
        }
        var migrated = false
        if (!metadata.has("theme")) {
            metadata.put(
                "theme",
                JSONObject()
                    .put("mode", "system")
                    .put("seedColor", metadata.optLong("color", 0xFF168CF3L))
                    .put("fontFamily", JSONObject.NULL)
                    .put("cornerRadius", 16.0)
                    .put("cardElevation", 0.0)
                    .put("inputFilled", true),
            )
            migrated = true
        }
        val theme = metadata.getJSONObject("theme")
        if (!theme.has("cornerRadius")) {
            theme.put("cornerRadius", 16.0)
            migrated = true
        }
        if (!theme.has("cardElevation")) {
            theme.put("cardElevation", 0.0)
            migrated = true
        }
        if (!theme.has("inputFilled")) {
            theme.put("inputFilled", true)
            migrated = true
        }
        if (!metadata.has("dependencies")) {
            metadata.put("dependencies", JSONArray())
            migrated = true
        }
        if (version != CURRENT_SCHEMA_VERSION) {
            metadata.put("schemaVersion", CURRENT_SCHEMA_VERSION)
            migrated = true
        }
        if (migrated) writeMetadata(directory, metadata)
        return metadata
    }

    private fun writeMetadata(directory: File, metadata: JSONObject) {
        val destination = File(directory, METADATA_FILE)
        val temporary = File(directory, "$METADATA_FILE.tmp")
        temporary.writeText(metadata.toString(2) + "\n")
        check(!destination.exists() || destination.delete()) { "Could not replace project metadata" }
        check(temporary.renameTo(destination)) { "Could not activate project metadata" }
    }

    private fun syncPubspecDependencies(directory: File, dependencies: JSONArray) {
        val pubspec = File(directory, "pubspec.yaml")
        check(pubspec.isFile) { "Project pubspec.yaml is missing" }
        val lines = pubspec.readLines(StandardCharsets.UTF_8).toMutableList()
        val oldStart = lines.indexOf(MANAGED_DEPENDENCIES_START)
        val oldEnd = lines.indexOf(MANAGED_DEPENDENCIES_END)
        check((oldStart < 0) == (oldEnd < 0) && (oldStart < 0 || oldEnd >= oldStart)) {
            "Managed dependency markers in pubspec.yaml are invalid"
        }
        if (oldStart >= 0) {
            lines.subList(oldStart, oldEnd + 1).clear()
        }

        val sectionStart = lines.indexOfFirst { it == "dependencies:" }
        check(sectionStart >= 0) { "pubspec.yaml has no dependencies section" }
        var sectionEnd = sectionStart + 1
        while (sectionEnd < lines.size) {
            val line = lines[sectionEnd]
            if (line.isNotBlank() && !line.first().isWhitespace() && !line.startsWith("#")) break
            sectionEnd++
        }
        val requestedNames = buildSet {
            for (index in 0 until dependencies.length()) {
                add(dependencies.getJSONObject(index).getString("name"))
            }
        }
        val manualNames = lines.subList(sectionStart + 1, sectionEnd)
            .mapNotNull { dependencyDeclarationPattern.matchEntire(it)?.groupValues?.get(1) }
            .filterNot { it == "flutter" }
            .toSet()
        val conflicts = requestedNames.intersect(manualNames)
        check(conflicts.isEmpty()) {
            "Package is already declared manually in pubspec.yaml: ${conflicts.sorted().joinToString()}"
        }

        if (dependencies.length() > 0) {
            val managed = mutableListOf(MANAGED_DEPENDENCIES_START)
            for (index in 0 until dependencies.length()) {
                val dependency = dependencies.getJSONObject(index)
                managed.add(
                    "  ${dependency.getString("name")}: ${dependency.getString("constraint")}",
                )
            }
            managed.add(MANAGED_DEPENDENCIES_END)
            lines.addAll(sectionEnd, managed)
        }
        val temporary = File(directory, ".pubspec.yaml.dependencies.tmp")
        temporary.writeText(lines.joinToString("\n", postfix = "\n"), StandardCharsets.UTF_8)
        check(pubspec.delete()) { "Could not replace pubspec.yaml" }
        check(temporary.renameTo(pubspec)) { "Could not activate pubspec.yaml" }
    }

    private fun dependencyMaps(value: JSONArray?): List<Map<String, Any?>> = buildList {
        val dependencies = value ?: JSONArray()
        for (index in 0 until dependencies.length()) {
            val dependency = dependencies.optJSONObject(index) ?: continue
            add(
                mapOf(
                    "name" to dependency.optString("name"),
                    "constraint" to dependency.optString("constraint", "any"),
                    "compatibility" to dependency.optString("compatibility", "unknown"),
                    "direct" to dependency.optBoolean("direct", true),
                ),
            )
        }
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
        "schemaVersion" to json.optInt("schemaVersion", CURRENT_SCHEMA_VERSION),
        "id" to json.getString("id"),
        "name" to json.getString("name"),
        "packageName" to json.getString("packageName"),
        "color" to json.optLong("color", 0xFF168CF3L),
        "theme" to json.optJSONObject("theme")?.let { theme ->
            mapOf(
                "mode" to theme.optString("mode", "system"),
                "seedColor" to theme.optLong("seedColor", json.optLong("color", 0xFF168CF3L)),
                "fontFamily" to theme.optString("fontFamily").takeIf { it.isNotBlank() },
                "cornerRadius" to theme.optDouble("cornerRadius", 16.0),
                "cardElevation" to theme.optDouble("cardElevation", 0.0),
                "inputFilled" to theme.optBoolean("inputFilled", true),
            )
        },
        "dependencies" to dependencyMaps(json.optJSONArray("dependencies")),
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
