package com.flutterware.app.projects

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.nio.charset.StandardCharsets

object ProjectFileStore {
    private val projectIdPattern = Regex("^[a-z][a-z0-9_]{2,30}$")
    private val textExtensions = setOf(
        "dart", "yaml", "yml", "json", "md", "txt", "xml", "gradle", "kts", "properties",
        "kt", "java", "sh", "bash", "html", "css", "js", "ts",
    )
    private val excludedDirectories = setOf("build", ".dart_tool", ".gradle")
    private val dartIdentifierPattern = Regex("^[A-Za-z_][A-Za-z0-9_]*$")
    private const val CUSTOM_WIDGETS_MANIFEST = ".fluttware/custom-widgets.json"
    private const val MAX_ASSET_BYTES = 40L * 1024 * 1024

    private val assetKinds = mapOf(
        "image" to AssetKind("images", setOf("png", "jpg", "jpeg", "webp", "gif")),
        "font" to AssetKind("fonts", setOf("ttf", "otf")),
        "sound" to AssetKind("sounds", setOf("mp3", "wav", "ogg", "m4a", "aac", "flac")),
        "file" to AssetKind("files", emptySet()),
    )

    private data class AssetKind(val directory: String, val extensions: Set<String>)

    fun list(context: Context, projectId: String): List<Map<String, Any>> {
        val root = projectRoot(context, projectId)
        return root.walkTopDown()
            .onEnter { it == root || it.name !in excludedDirectories }
            .drop(1)
            .take(500)
            .map { file ->
                val path = relativePath(root, file)
                mapOf(
                    "path" to path,
                    "name" to file.name,
                    "directory" to file.isDirectory,
                    "generated" to isGenerated(path),
                    "editable" to (!file.isDirectory && isEditable(path)),
                    "openable" to (!file.isDirectory && isTextFile(path)),
                    "size" to if (file.isFile) file.length() else 0L,
                )
            }
            .toList()
    }

    fun read(context: Context, projectId: String, path: String): Map<String, Any> {
        val root = projectRoot(context, projectId)
        val file = resolveFile(root, path)
        require(file.isFile) { "Project file does not exist: $path" }
        require(isTextFile(path)) { "This file type cannot be opened as text" }
        require(file.length() <= 1024L * 1024L) { "Files larger than 1 MB are not supported yet" }
        return mapOf(
            "path" to path,
            "content" to file.readText(StandardCharsets.UTF_8),
            "generated" to isGenerated(path),
            "editable" to isEditable(path),
        )
    }

    fun write(context: Context, projectId: String, path: String, content: String) {
        require(content.toByteArray(StandardCharsets.UTF_8).size <= 1024 * 1024) {
            "Files larger than 1 MB are not supported yet"
        }
        require(isEditable(path)) { "Generated or protected project files are read-only" }
        val root = projectRoot(context, projectId)
        val file = resolveFile(root, path)
        require(file.isFile) { "Project file does not exist: $path" }
        val temporary = File(file.parentFile, ".${file.name}.tmp")
        temporary.writeText(content, StandardCharsets.UTF_8)
        check(file.delete()) { "Could not replace $path" }
        check(temporary.renameTo(file)) { "Could not save $path" }
    }

    fun importAsset(
        context: Context,
        projectId: String,
        kind: String,
        sourceName: String,
        input: InputStream,
    ): Map<String, Any> {
        val assetKind = assetKinds[kind] ?: error("Unsupported asset type: $kind")
        val extension = sourceName.substringAfterLast('.', "").lowercase()
        if (assetKind.extensions.isNotEmpty()) {
            require(extension in assetKind.extensions) {
                "Choose a ${assetKind.extensions.joinToString(", ").uppercase()} file"
            }
        }
        val root = projectRoot(context, projectId)
        val directory = File(root, "assets/${assetKind.directory}").apply {
            check(isDirectory || mkdirs()) { "Could not create the asset directory" }
        }
        val rawStem = sourceName.substringBeforeLast('.', sourceName)
            .lowercase()
            .replace(Regex("[^a-z0-9_-]+"), "_")
            .trim('_', '-')
            .ifBlank { kind }
            .take(64)
        val suffix = extension.takeIf { it.isNotBlank() }?.let { ".$it" }.orEmpty()
        var destination = File(directory, "$rawStem$suffix")
        var counter = 2
        while (destination.exists()) {
            destination = File(directory, "${rawStem}_${counter++}$suffix")
        }
        val temporary = File(directory, ".${destination.name}.importing")
        var activated = false
        try {
            temporary.outputStream().use { output ->
                val buffer = ByteArray(128 * 1024)
                var total = 0L
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    require(total <= MAX_ASSET_BYTES) { "Assets must be 40 MB or smaller" }
                    output.write(buffer, 0, count)
                }
                require(total > 0) { "The selected asset is empty" }
            }
            check(temporary.renameTo(destination)) { "Could not save the imported asset" }
            activated = true
            registerAssetDirectory(root, "assets/${assetKind.directory}")
        } catch (error: Throwable) {
            temporary.delete()
            if (activated) destination.delete()
            throw error
        }
        val path = relativePath(root, destination)
        return mapOf(
            "path" to path,
            "name" to destination.name,
            "kind" to kind,
            "size" to destination.length(),
        )
    }

    fun listCustomWidgets(context: Context, projectId: String): List<Map<String, Any>> {
        val root = projectRoot(context, projectId)
        val widgets = readCustomWidgetManifest(root).optJSONArray("widgets") ?: JSONArray()
        return buildList {
            for (index in 0 until widgets.length()) {
                val widget = widgets.optJSONObject(index) ?: continue
                val path = widget.optString("path")
                if (runCatching { resolveFile(root, path).isFile }.getOrDefault(false)) {
                    add(jsonObjectToMap(widget))
                }
            }
        }
    }

    fun createCustomWidget(
        context: Context,
        projectId: String,
        values: Map<*, *>,
        createFile: Boolean,
    ): Map<String, Any> {
        val root = projectRoot(context, projectId)
        val name = values["name"]?.toString()?.trim().orEmpty()
        val id = values["id"]?.toString()?.trim().orEmpty()
        val className = values["className"]?.toString()?.trim().orEmpty()
        val path = values["path"]?.toString()?.trim()?.replace('\\', '/').orEmpty()
        require(name.isNotBlank()) { "Widget name is required" }
        require(Regex("^[a-z][a-z0-9_]{2,48}$").matches(id)) { "Invalid widget identifier" }
        require(dartIdentifierPattern.matches(className)) { "Invalid Dart class name" }
        validateCustomWidgetPath(path)
        val file = resolveFile(root, path)
        val parameters = parseParameters(values["parameters"])
        if (createFile) {
            require(!file.exists()) { "A file already exists at $path" }
            check(file.parentFile?.mkdirs() == true || file.parentFile?.isDirectory == true) {
                "Could not create the widget directory"
            }
            file.writeText(customWidgetSource(name, className, parameters), StandardCharsets.UTF_8)
        } else {
            require(file.isFile) { "The selected Dart file does not exist" }
        }

        val widget = JSONObject()
            .put("id", id)
            .put("name", name)
            .put("className", className)
            .put("path", path)
            .put("parameters", parameters)
            .put("arguments", JSONObject())
        saveCustomWidget(root, widget)
        return jsonObjectToMap(widget)
    }

    private fun projectRoot(context: Context, projectId: String): File {
        require(projectIdPattern.matches(projectId)) { "Invalid project identifier" }
        val projects = File(context.filesDir, "projects").canonicalFile
        val root = ProjectStore.ensureScaffold(context, projectId).canonicalFile
        require(root.path.startsWith(projects.path + File.separator)) { "Project path escaped workspace" }
        return root
    }

    private fun resolveFile(root: File, path: String): File {
        require(path.isNotBlank() && !path.startsWith("/")) { "Invalid project path" }
        val file = File(root, path).canonicalFile
        require(file.path.startsWith(root.path + File.separator)) { "Project path escaped workspace" }
        require(!file.toPath().toFile().isDirectory || file.isDirectory) { "Invalid project file" }
        return file
    }

    private fun validateCustomWidgetPath(path: String) {
        require(path.startsWith("lib/") && path.endsWith(".dart")) {
            "Reusable widgets must be Dart files inside lib/"
        }
        require(!isGenerated(path)) {
            "Choose a user-owned folder; Flutterware-generated folders are protected"
        }
        require(!path.startsWith("lib/.")) { "Hidden lib folders are not supported" }
    }

    private fun readCustomWidgetManifest(root: File): JSONObject {
        val file = File(root, CUSTOM_WIDGETS_MANIFEST)
        return runCatching { JSONObject(file.readText(StandardCharsets.UTF_8)) }
            .getOrElse { JSONObject().put("schemaVersion", 1).put("widgets", JSONArray()) }
    }

    private fun saveCustomWidget(root: File, widget: JSONObject) {
        val manifest = readCustomWidgetManifest(root)
        val current = manifest.optJSONArray("widgets") ?: JSONArray()
        val next = JSONArray()
        for (index in 0 until current.length()) {
            val item = current.optJSONObject(index) ?: continue
            if (item.optString("id") != widget.getString("id")) next.put(item)
        }
        next.put(widget)
        manifest.put("schemaVersion", 1).put("widgets", next)
        val file = File(root, CUSTOM_WIDGETS_MANIFEST)
        file.parentFile?.mkdirs()
        val temporary = File(file.parentFile, ".${file.name}.tmp")
        temporary.writeText(manifest.toString(2), StandardCharsets.UTF_8)
        if (file.exists()) check(file.delete()) { "Could not replace custom widget registry" }
        check(temporary.renameTo(file)) { "Could not save custom widget registry" }
    }

    private fun registerAssetDirectory(root: File, directory: String) {
        val pubspec = File(root, "pubspec.yaml")
        require(pubspec.isFile) { "Project pubspec.yaml is missing" }
        val declaration = "    - $directory/"
        val lines = pubspec.readLines(StandardCharsets.UTF_8).toMutableList()
        if (lines.any { it.trim() == "- $directory/" }) return
        val assets = lines.indexOfFirst { it.trim() == "assets:" }
        if (assets >= 0) {
            var insertion = assets + 1
            while (insertion < lines.size &&
                (lines[insertion].isBlank() || lines[insertion].startsWith("    - "))
            ) {
                insertion++
            }
            lines.add(insertion, declaration)
        } else {
            val flutter = lines.indexOfFirst { it.trim() == "flutter:" }
            require(flutter >= 0) { "pubspec.yaml has no flutter section" }
            lines.add(flutter + 1, "  assets:")
            lines.add(flutter + 2, declaration)
        }
        val temporary = File(root, ".pubspec.yaml.assets.tmp")
        temporary.writeText(lines.joinToString("\n", postfix = "\n"), StandardCharsets.UTF_8)
        check(pubspec.delete()) { "Could not update pubspec.yaml" }
        check(temporary.renameTo(pubspec)) { "Could not activate pubspec.yaml" }
    }

    private fun parseParameters(value: Any?): JSONArray {
        val result = JSONArray()
        val seen = mutableSetOf<String>()
        for (item in value as? List<*> ?: emptyList<Any>()) {
            val map = item as? Map<*, *> ?: continue
            val name = map["name"]?.toString()?.trim().orEmpty()
            val requestedType = map["type"]?.toString()?.trim().orEmpty()
            val type = requestedType.takeIf { it in setOf("String", "int", "double", "bool", "dynamic") }
                ?: "String"
            require(dartIdentifierPattern.matches(name)) { "Invalid parameter name: $name" }
            require(seen.add(name)) { "Duplicate parameter: $name" }
            result.put(
                JSONObject()
                    .put("name", name)
                    .put("type", type)
                    .put("defaultValue", map["defaultValue"]?.toString().orEmpty()),
            )
        }
        return result
    }

    private fun customWidgetSource(name: String, className: String, parameters: JSONArray): String {
        val fields = StringBuilder()
        val constructor = StringBuilder()
        for (index in 0 until parameters.length()) {
            val parameter = parameters.getJSONObject(index)
            val parameterName = parameter.getString("name")
            val type = parameter.getString("type")
            val defaultValue = dartDefaultValue(type, parameter.optString("defaultValue"))
            constructor.append(", this.$parameterName = $defaultValue")
            fields.append("  final $type $parameterName;\n")
        }
        val content = if (parameters.length() > 0) {
            "Text(${parameters.getJSONObject(0).getString("name")}.toString())"
        } else {
            "const Text('${escapeDart(name)}')"
        }
        return """
            import 'package:flutter/material.dart';

            /// Reusable UI created by Flutterware. This file is yours to edit.
            class $className extends StatelessWidget {
              const $className({super.key$constructor});

            $fields
              @override
              Widget build(BuildContext context) => Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: $content,
                ),
              );
            }
        """.trimIndent() + "\n"
    }

    private fun dartDefaultValue(type: String, value: String): String = when (type) {
        "String" -> "'${escapeDart(value)}'"
        "int" -> value.toIntOrNull()?.toString() ?: "0"
        "double" -> value.toDoubleOrNull()?.toString() ?: "0.0"
        "bool" -> if (value.equals("true", ignoreCase = true)) "true" else "false"
        else -> value.ifBlank { "null" }
    }

    private fun escapeDart(value: String): String = value
        .replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")

    private fun jsonObjectToMap(value: JSONObject): Map<String, Any> = buildMap {
        for (key in value.keys()) {
            put(key, jsonValue(value.get(key)))
        }
    }

    private fun jsonValue(value: Any): Any = when (value) {
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> buildList {
            for (index in 0 until value.length()) add(jsonValue(value.get(index)))
        }
        JSONObject.NULL -> ""
        else -> value
    }

    private fun relativePath(root: File, file: File): String =
        file.relativeTo(root).invariantSeparatorsPath

    private fun isGenerated(path: String): Boolean =
        path == "lib/main.dart" ||
            path.startsWith("lib/generated/") ||
            path.startsWith("lib/app/") ||
            path.startsWith("lib/core/") ||
            (path.startsWith("lib/features/") &&
                (path.contains("/presentation/pages/") ||
                    path.contains("/logic/"))) ||
            path.startsWith(".fluttware/") ||
            path == "fluttware-project.json"

    private fun isEditable(path: String): Boolean =
        !isGenerated(path) &&
            !path.startsWith("android/") &&
            !path.startsWith("build/") &&
            !path.startsWith(".dart_tool/") &&
            isTextFile(path)

    private fun isTextFile(path: String): Boolean {
        if (path == ".gitignore") return true
        return path.substringAfterLast('.', "").lowercase() in textExtensions
    }
}
