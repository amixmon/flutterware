package com.flutterware.app.projects

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.charset.StandardCharsets

/** Writes Flutterware-owned files while preserving files intended for user code. */
object FlutterProjectScaffold {
    private const val MODEL_DIRECTORY = ".fluttware"

    fun create(project: File, metadata: JSONObject) {
        writeInitialModels(project, metadata)
        writeProjectFiles(project, metadata)
    }

    fun ensure(project: File, metadata: JSONObject) {
        writeProjectFiles(project, metadata)
        if (!File(project, "$MODEL_DIRECTORY/design.json").isFile() ||
            !File(project, "$MODEL_DIRECTORY/logic.json").isFile()
        ) {
            writeInitialModels(project, metadata)
        }
    }

    fun regenerate(project: File, metadata: JSONObject) {
        writeGeneratedSources(project, metadata)
    }

    fun updateCounterStep(project: File, metadata: JSONObject, step: Int) {
        require(step in -100..100 && step != 0) { "Counter step must be between -100 and 100" }
        val file = File(project, "$MODEL_DIRECTORY/logic.json")
        val logic = JSONObject(file.readText())
        val value = logic
            .getJSONArray("events")
            .getJSONObject(0)
            .getJSONArray("blocks")
            .getJSONObject(0)
            .getJSONObject("value")
            .getJSONObject("right")
        value.put("value", step)
        writeAtomic(file, logic.toString(2) + "\n")
        writeGeneratedSources(project, metadata)
    }

    fun readDesign(project: File): String =
        File(project, "$MODEL_DIRECTORY/design.json").readText(StandardCharsets.UTF_8)

    fun updateDesign(project: File, metadata: JSONObject, source: String) {
        require(source.toByteArray(StandardCharsets.UTF_8).size <= 512 * 1024) {
            "The visual design is too large"
        }
        val design = JSONObject(source)
        require(design.optInt("schemaVersion") in 2..3) { "Unsupported design schema" }
        val hasBody = if (design.optInt("schemaVersion") == 3) {
            design.optJSONArray("pages")?.let { pages ->
                pages.length() > 0 && pages.optJSONObject(0)?.optJSONObject("body") != null
            } == true
        } else design.optJSONObject("screen")?.optJSONObject("body") != null
        require(hasBody) { "The design must contain at least one page body" }
        writeAtomic(
            File(project, "$MODEL_DIRECTORY/design.json"),
            design.toString(2) + "\n",
        )
        writeGeneratedSources(project, metadata)
    }

    fun readLogic(project: File): String =
        File(project, "$MODEL_DIRECTORY/logic.json").readText(StandardCharsets.UTF_8)

    fun updateLogic(project: File, metadata: JSONObject, source: String) {
        require(source.toByteArray(StandardCharsets.UTF_8).size <= 512 * 1024) {
            "The logic model is too large"
        }
        val logic = JSONObject(source)
        require(logic.optInt("schemaVersion") == 1) { "Unsupported logic schema" }
        require(logic.optJSONArray("events") != null) { "The logic model must contain events" }
        writeAtomic(File(project, "$MODEL_DIRECTORY/logic.json"), logic.toString(2) + "\n")
        writeGeneratedSources(project, metadata)
    }

    private fun writeProjectFiles(project: File, metadata: JSONObject) {
        project.mkdirs()
        writeIfMissing(File(project, ".gitignore"), gitignore())
        writeIfMissing(File(project, "pubspec.yaml"), pubspec(metadata.getString("id")))
        writeIfMissing(File(project, "README.md"), projectReadme(metadata.getString("name")))
        writeIfMissing(File(project, "lib/custom/actions.dart"), customActions())
        writeIfMissing(File(project, "lib/custom/action_handlers.dart"), actionHandlers())
        File(project, "assets").mkdirs()
        writeGeneratedSources(project, metadata)
    }

    private fun writeGeneratedSources(project: File, metadata: JSONObject) {
        val design = readDesignModel(project, metadata)
        val pages = design.getJSONArray("pages")
        val logic = runCatching {
            JSONObject(File(project, "$MODEL_DIRECTORY/logic.json").readText())
        }.getOrElse { JSONObject().put("events", JSONArray()) }
        writeAtomic(File(project, "lib/main.dart"), mainDart())
        writeAtomic(File(project, "lib/app/app.dart"), appDart(metadata))
        writeAtomic(File(project, "lib/app/router/app_router.dart"), routerDart(design))
        writeAtomic(
            File(project, "lib/core/theme/app_theme.dart"),
            themeDart(metadata),
        )
        val widgetTypes = mutableSetOf<String>()
        for (index in 0 until pages.length()) {
            val page = pages.getJSONObject(index)
            collectWidgetTypes(page.getJSONObject("body"), widgetTypes)
            val id = safeIdentifier(page.getString("id"))
            val feature = "lib/features/$id"
            writeAtomic(
                File(project, "$feature/presentation/pages/${id}_page.dart"),
                pageDart(page, logic, metadata.getString("id")),
            )
            writeAtomic(
                File(project, "$feature/logic/${id}_controller.dart"),
                pageControllerDart(id, logic),
            )
        }
        if ("button" in widgetTypes) writeAtomic(
            File(project, "lib/core/widgets/app_button.dart"), appButtonWidgetDart(),
        )
        if ("textField" in widgetTypes) writeAtomic(
            File(project, "lib/core/widgets/app_text_field.dart"), appTextFieldWidgetDart(),
        )
        if ("checkbox" in widgetTypes) writeAtomic(
            File(project, "lib/core/widgets/app_checkbox.dart"), appCheckboxWidgetDart(),
        )
        if ("switch" in widgetTypes) writeAtomic(
            File(project, "lib/core/widgets/app_switch.dart"), appSwitchWidgetDart(),
        )
        if ("slider" in widgetTypes) writeAtomic(
            File(project, "lib/core/widgets/app_slider.dart"), appSliderWidgetDart(),
        )
    }

    private fun writeInitialModels(project: File, metadata: JSONObject) {
        val name = metadata.getString("name")
        val body = JSONObject()
            .put("id", "root_column")
            .put("type", "column")
            .put(
                "properties",
                JSONObject()
                    .put("mainAxisAlignment", "start")
                    .put("crossAxisAlignment", "start"),
            )
            .put(
                "children",
                JSONArray()
                    .put(
                        JSONObject()
                            .put("id", "counter_label")
                            .put("type", "text")
                            .put(
                                "properties",
                                JSONObject()
                                    .put("text", "You have pushed the button this many times:")
                                    .put("textAlign", "center"),
                            )
                            .put("children", JSONArray()),
                    )
                    .put(
                        JSONObject()
                            .put("id", "counter_value")
                            .put("type", "text")
                            .put(
                                "properties",
                                JSONObject()
                                    .put("binding", "counter")
                                    .put("style", "headlineMedium"),
                            )
                            .put("children", JSONArray()),
                    ),
            )
        val homePage = JSONObject()
                    .put("id", "home")
                    .put("name", "Home")
                    .put("route", "/")
                    .put(
                        "appBar",
                        JSONObject()
                            .put("enabled", true)
                            .put("properties", JSONObject().put("title", name)),
                    )
                    .put(
                        "floatingActionButton",
                        JSONObject()
                            .put("enabled", true)
                            .put(
                                "properties",
                                JSONObject()
                                    .put("id", "counter_fab")
                                    .put("icon", "add")
                                    .put("tooltip", "Increment"),
                            ),
                    )
                    .put("body", body)
        val design = JSONObject()
            .put("schemaVersion", 3)
            .put("initialPageId", "home")
            .put("pages", JSONArray().put(homePage))
        val increment = JSONObject()
            .put("type", "setVariable")
            .put("variableId", "counter")
            .put(
                "value",
                JSONObject()
                    .put("type", "binary")
                    .put("operator", "+")
                    .put("left", JSONObject().put("type", "variable").put("id", "counter"))
                    .put("right", JSONObject().put("type", "integer").put("value", 1)),
            )
        val logic = JSONObject()
            .put("schemaVersion", 1)
            .put(
                "variables",
                JSONArray().put(
                    JSONObject()
                        .put("id", "counter")
                        .put("name", "counter")
                        .put("type", "int")
                        .put("initialValue", 0),
                ),
            )
            .put(
                "events",
                JSONArray().put(
                    JSONObject()
                        .put("id", "counter_fab_pressed")
                        .put("widgetId", "counter_fab")
                        .put("event", "onPressed")
                        .put("blocks", JSONArray().put(increment)),
                ),
            )
        writeAtomic(File(project, "$MODEL_DIRECTORY/design.json"), design.toString(2) + "\n")
        writeAtomic(File(project, "$MODEL_DIRECTORY/logic.json"), logic.toString(2) + "\n")
    }

    private fun mainDart() = """
        // GENERATED BY FLUTTWARE. Edit lib/custom instead of this file.
        import 'package:flutter/material.dart';

        import 'app/app.dart';

        void main() => runApp(const GeneratedApp());
    """.trimIndent() + "\n"

    private fun appDart(metadata: JSONObject): String {
        val requestedMode = metadata.optJSONObject("theme")?.optString("mode", "system")
        val mode = requestedMode?.takeIf { it in setOf("system", "light", "dark") } ?: "system"
        return """
        // GENERATED BY FLUTTWARE. Changes are replaced by the visual editor.
        import 'package:flutter/material.dart';

        import '../core/theme/app_theme.dart';
        import 'router/app_router.dart';

        class GeneratedApp extends StatelessWidget {
          const GeneratedApp({super.key});

          @override
          Widget build(BuildContext context) {
            return MaterialApp(
              debugShowCheckedModeBanner: true,
              theme: buildAppTheme(Brightness.light),
              darkTheme: buildAppTheme(Brightness.dark),
              themeMode: ThemeMode.$mode,
              initialRoute: AppRouter.initialRoute,
              routes: AppRouter.routes,
            );
          }
        }
        """.trimIndent() + "\n"
    }

    private fun themeDart(metadata: JSONObject): String {
        val theme = metadata.optJSONObject("theme") ?: JSONObject()
        val value = theme.optLong("seedColor", metadata.optLong("color", 0xFF168CF3L)) and
            0xFFFFFFFFL
        val literal = "0x${value.toString(16).uppercase().padStart(8, '0')}"
        val fontFamily = theme.optString("fontFamily").trim().takeIf { it.isNotEmpty() }
        val fontLine = fontFamily?.let { "fontFamily: '${dartString(it)}'," }.orEmpty()
        val radius = theme.optDouble("cornerRadius", 16.0).coerceIn(0.0, 32.0)
        val elevation = theme.optDouble("cardElevation", 0.0).coerceIn(0.0, 8.0)
        val inputFilled = theme.optBoolean("inputFilled", true)
        return """
            // GENERATED BY FLUTTWARE. Theme settings are controlled by the project editor.
            import 'package:flutter/material.dart';

            ThemeData buildAppTheme(Brightness brightness) {
              const seedColor = Color($literal);
              const cornerRadius = $radius;
              final colorScheme = ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: brightness,
              );
              final componentShape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cornerRadius),
              );
              return ThemeData(
                useMaterial3: true,
                brightness: brightness,
                colorScheme: colorScheme,
                $fontLine
                appBarTheme: const AppBarTheme(centerTitle: false),
                cardTheme: CardThemeData(
                  elevation: $elevation,
                  shape: componentShape,
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: ButtonStyle(shape: WidgetStatePropertyAll(componentShape)),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ButtonStyle(shape: WidgetStatePropertyAll(componentShape)),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: ButtonStyle(shape: WidgetStatePropertyAll(componentShape)),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: $inputFilled,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                ),
                dialogTheme: DialogThemeData(shape: componentShape),
              );
            }
        """.trimIndent() + "\n"
    }

    private fun readDesignModel(project: File, metadata: JSONObject): JSONObject {
        val source = runCatching {
            JSONObject(File(project, "$MODEL_DIRECTORY/design.json").readText())
        }.getOrNull()
        if (source?.optInt("schemaVersion") == 3 &&
            (source.optJSONArray("pages")?.length() ?: 0) > 0
        ) return source
        val screen = source?.optJSONObject("screen") ?: JSONObject()
            .put("id", "home")
            .put("route", "/")
            .put("appBar", JSONObject().put("enabled", true).put("properties", JSONObject().put("title", metadata.getString("name"))))
            .put("floatingActionButton", JSONObject().put("enabled", false).put("properties", JSONObject().put("id", "counter_fab")))
            .put("body", JSONObject().put("id", "root_column").put("type", "column").put("properties", JSONObject()).put("children", JSONArray()))
        if (!screen.has("name")) screen.put("name", "Home")
        return JSONObject()
            .put("schemaVersion", 3)
            .put("initialPageId", screen.optString("id", "home"))
            .put("pages", JSONArray().put(screen))
    }

    private fun routerDart(design: JSONObject): String {
        val pages = design.getJSONArray("pages")
        val imports = StringBuilder()
        val routes = StringBuilder()
        for (index in 0 until pages.length()) {
            val page = pages.getJSONObject(index)
            val id = safeIdentifier(page.getString("id"))
            val className = "${pascalCase(id)}Page"
            imports.append("import '../../features/$id/presentation/pages/${id}_page.dart';\n")
            routes.append("    '${dartString(page.optString("route", "/$id"))}': (_) => const $className(),\n")
        }
        val initialId = design.optString("initialPageId", pages.getJSONObject(0).getString("id"))
        val initialPage = (0 until pages.length()).map { pages.getJSONObject(it) }
            .firstOrNull { it.optString("id") == initialId } ?: pages.getJSONObject(0)
        val initialRoute = dartString(initialPage.optString("route", "/"))
        return """
            // GENERATED BY FLUTTWARE. Routes are controlled by the page editor.
            import 'package:flutter/material.dart';

            ${imports.toString().trimEnd()}

            abstract final class AppRouter {
              static const initialRoute = '$initialRoute';
              static final routes = <String, WidgetBuilder>{
            ${routes.toString().trimEnd()}
              };
            }
        """.trimIndent() + "\n"
    }

    private fun collectWidgetTypes(node: JSONObject, result: MutableSet<String>) {
        result.add(node.optString("type"))
        val children = node.optJSONArray("children") ?: return
        for (index in 0 until children.length()) {
            children.optJSONObject(index)?.let { collectWidgetTypes(it, result) }
        }
    }

    private fun safeIdentifier(value: String): String = value
        .lowercase()
        .replace(Regex("[^a-z0-9_]+"), "_")
        .trim('_')
        .ifBlank { "page" }
        .let { if (it.first().isDigit()) "page_$it" else it }

    private fun pascalCase(value: String): String = safeIdentifier(value)
        .split('_')
        .joinToString("") { it.replaceFirstChar(Char::uppercase) }

    private fun pageDart(page: JSONObject, logic: JSONObject, projectId: String): String {
        val id = safeIdentifier(page.getString("id"))
        val className = "${pascalCase(id)}Page"
        val controllerName = "${pascalCase(id)}Controller"
        val body = page.getJSONObject("body")
        val types = mutableSetOf<String>().also { collectWidgetTypes(body, it) }
        val commonImports = buildString {
            if ("button" in types) append("import '../../../../core/widgets/app_button.dart';\n")
            if ("textField" in types) append("import '../../../../core/widgets/app_text_field.dart';\n")
            if ("checkbox" in types) append("import '../../../../core/widgets/app_checkbox.dart';\n")
            if ("switch" in types) append("import '../../../../core/widgets/app_switch.dart';\n")
            if ("slider" in types) append("import '../../../../core/widgets/app_slider.dart';\n")
        }.trimEnd()
        val customUi = page.optJSONObject("customUi")
        val customImport = customUi?.optString("path")
            ?.takeIf { it.startsWith("lib/") && it.endsWith(".dart") }
            ?.removePrefix("lib/")
            ?.let { "import 'package:$projectId/$it';" }
            .orEmpty()
        val bodySource = customUi?.let(::renderCustomWidget) ?: renderNode(body, logic)
        val appBar = page.optJSONObject("appBar")
        val appBarSource = if (appBar?.optBoolean("enabled", false) == true) {
            val title = dartString(appBar.optJSONObject("properties")?.optString("title", page.optString("name")) ?: page.optString("name"))
            "AppBar(title: Text('$title'))"
        } else "null"
        val fab = page.optJSONObject("floatingActionButton")
        val fabProperties = fab?.optJSONObject("properties")
        val fabSource = if (fab?.optBoolean("enabled", false) == true) {
            val icon = iconSource(fabProperties?.optString("icon", "add") ?: "add")
            val tooltip = dartString(fabProperties?.optString("tooltip", "Action") ?: "Action")
            val widgetId = fabProperties?.optString("id", "${id}_fab") ?: "${id}_fab"
            val statements = eventStatements(logic, widgetId, "onPressed")
            "FloatingActionButton(onPressed: () async { $statements }, tooltip: '$tooltip', child: Icon($icon))"
        } else "null"
        val initStatements = eventStatements(logic, "${id}_page", "onInit")
        return """
            // GENERATED BY FLUTTWARE. This feature is rebuilt by the visual and logic editors.
            import 'package:flutter/material.dart';

            $customImport

            import '../../../../custom/actions.dart';
            import '../../../../custom/action_handlers.dart';
            $commonImports
            import '../../logic/${id}_controller.dart';

            class $className extends StatefulWidget {
              const $className({super.key});

              @override
              State<$className> createState() => _${className}State();
            }

            class _${className}State extends State<$className> {
              final _controller = $controllerName();

              @override
              void initState() {
                super.initState();
                _controller.addListener(_refresh);
                _runOnInit();
              }

              void _refresh() => setState(() {});

              Future<void> _runOnInit() async {
                $initStatements
              }

              @override
              void dispose() {
                _controller.removeListener(_refresh);
                _controller.dispose();
                super.dispose();
              }

              @override
              Widget build(BuildContext context) => Scaffold(
                appBar: $appBarSource,
                body: SizedBox.expand(child: $bodySource),
                floatingActionButton: $fabSource,
              );
            }
        """.trimIndent() + "\n"
    }

    private fun renderCustomWidget(widget: JSONObject): String {
        val className = widget.optString("className", "CustomWidget")
        val parameters = widget.optJSONArray("parameters") ?: JSONArray()
        val arguments = widget.optJSONObject("arguments") ?: JSONObject()
        val values = buildList {
            for (index in 0 until parameters.length()) {
                val parameter = parameters.optJSONObject(index) ?: continue
                val name = parameter.optString("name")
                if (name.isBlank()) continue
                val type = parameter.optString("type", "String")
                val value = arguments.optString(name, parameter.optString("defaultValue"))
                add("$name: ${customWidgetArgument(type, value)}")
            }
        }
        return if (values.isEmpty()) "$className()" else {
            "$className(${values.joinToString(", ")})"
        }
    }

    private fun customWidgetArgument(type: String, value: String): String = when (type) {
        "String" -> "'${dartString(value)}'"
        "int" -> value.toIntOrNull()?.toString() ?: "0"
        "double" -> value.toDoubleOrNull()?.toString() ?: "0.0"
        "bool" -> if (value.equals("true", ignoreCase = true)) "true" else "false"
        else -> value.ifBlank { "null" }
    }

    private fun pageControllerDart(id: String, logic: JSONObject): String {
        val className = "${pascalCase(id)}Controller"
        val variableSources = StringBuilder()
        val variables = logic.optJSONArray("variables") ?: JSONArray()
        for (index in 0 until variables.length()) {
            val variable = variables.optJSONObject(index) ?: continue
            val owner = variable.optString("pageId")
            if (owner.isNotBlank() && owner != id) continue
            val variableId = safeIdentifier(variable.optString("id", "value"))
            val type = variableType(variable.optString("type", "dynamic"))
            val initial = dartTypedValue(variable.opt("initialValue"), type)
            val title = pascalCase(variableId)
            variableSources.append("  $type _$variableId = $initial;\n")
            variableSources.append("  $type get $variableId => _$variableId;\n")
            variableSources.append("  void set$title($type value) { _$variableId = value; notifyListeners(); }\n")
            if (type == "int" || type == "double") {
                val conversion = if (type == "int") ".toInt()" else ".toDouble()"
                variableSources.append("  void change$title(num amount) { _$variableId = (_$variableId + amount)$conversion; notifyListeners(); }\n")
            }
            variableSources.append("\n")
        }
        if (variableSources.isEmpty()) {
            variableSources.append("  int _counter = 0;\n")
            variableSources.append("  int get counter => _counter;\n")
            variableSources.append("  void changeCounter(num amount) { _counter += amount.toInt(); notifyListeners(); }\n")
        }
        val customSources = StringBuilder()
        val customBlocks = logic.optJSONArray("customBlocks") ?: JSONArray()
        for (index in 0 until customBlocks.length()) {
            val block = customBlocks.optJSONObject(index) ?: continue
            val owner = block.optString("pageId")
            if (owner.isNotBlank() && owner != id) continue
            val method = safeIdentifier(block.optString("id", "customBlock"))
            val parameters = block.optJSONArray("parameters") ?: JSONArray()
            val signature = (0 until parameters.length()).mapNotNull { parameterIndex ->
                parameters.optJSONObject(parameterIndex)?.let { parameter ->
                    "${variableType(parameter.optString("type", "dynamic"))} ${safeIdentifier(parameter.optString("name", "value"))}"
                }
            }.joinToString(", ")
            val suffix = if (signature.isBlank()) "" else ", $signature"
            customSources.append("  Future<void> $method(BuildContext context$suffix) async {\n")
            customSources.append(block.optString("code", "// Custom block").prependIndent("    "))
            customSources.append("\n  }\n\n")
        }
        return """
            // GENERATED BY FLUTTERWARE. Page state and generated actions live here.
            import 'package:flutter/material.dart';

            class $className extends ChangeNotifier {
            ${variableSources.toString().trimEnd()}

            ${customSources.toString().trimEnd()}
            }
        """.trimIndent() + "\n"
    }

    private fun variableType(value: String): String = when (value.lowercase()) {
        "int", "integer", "number" -> "int"
        "double", "decimal" -> "double"
        "string", "text" -> "String"
        "bool", "boolean" -> "bool"
        else -> "dynamic"
    }

    private fun dartTypedValue(value: Any?, type: String): String = when (type) {
        "int" -> value?.toString()?.toIntOrNull()?.toString() ?: "0"
        "double" -> value?.toString()?.toDoubleOrNull()?.toString() ?: "0.0"
        "bool" -> if (value?.toString()?.equals("true", true) == true) "true" else "false"
        "String" -> "'" + dartString(value?.toString().orEmpty()) + "'"
        else -> {
            val raw = value?.toString().orEmpty()
            raw.toIntOrNull()?.toString()
                ?: raw.toDoubleOrNull()?.toString()
                ?: if (raw.equals("true", true) || raw.equals("false", true)) raw.lowercase()
                else "'${dartString(raw)}'"
        }
    }

    private fun homePageDart(project: File, metadata: JSONObject): String {
        val counterStep = counterStep(project)
        val design = runCatching {
            JSONObject(File(project, "$MODEL_DIRECTORY/design.json").readText())
                .takeIf { it.optInt("schemaVersion") == 2 }
        }.getOrNull()
        val screen = design?.optJSONObject("screen")
        val body = screen?.optJSONObject("body")
        val logic = runCatching {
            JSONObject(File(project, "$MODEL_DIRECTORY/logic.json").readText())
        }.getOrElse { JSONObject().put("events", JSONArray()) }
        val bodySource = body?.let { renderNode(it, logic) }
            ?: "Center(child: Text('Open this project in the Flutterware editor'))"
        val appBar = screen?.optJSONObject("appBar")
        val appBarSource = if (appBar?.optBoolean("enabled", false) == true) {
            val title = dartString(
                appBar.optJSONObject("properties")
                    ?.optString("title", metadata.getString("name"))
                    ?: metadata.getString("name"),
            )
            "AppBar(title: Text('$title'))"
        } else {
            "null"
        }
        val fab = screen?.optJSONObject("floatingActionButton")
        val fabProperties = fab?.optJSONObject("properties")
        val fabSource = if (fab?.optBoolean("enabled", false) == true) {
            val icon = iconSource(fabProperties?.optString("icon", "add") ?: "add")
            val tooltip = dartString(fabProperties?.optString("tooltip", "Action") ?: "Action")
            val widgetId = fabProperties?.optString("id", "floating_action_button")
                ?: "floating_action_button"
            val statements = eventStatements(logic, widgetId)
            "FloatingActionButton(onPressed: () async { $statements }, tooltip: '$tooltip', child: Icon($icon))"
        } else {
            "null"
        }
        return """
            // GENERATED BY FLUTTWARE. Changes are replaced by the visual and logic editors.
            import 'package:flutter/material.dart';

            import '../custom/actions.dart';

            class HomePage extends StatefulWidget {
              const HomePage({super.key});

              @override
              State<HomePage> createState() => _HomePageState();
            }

            class _HomePageState extends State<HomePage> {
              int _counter = 0;

              void _incrementCounter() {
                setState(() => _counter += $counterStep);
                CustomActions.counterChanged(context, _counter);
              }

              @override
              Widget build(BuildContext context) {
                return Scaffold(
                  appBar: $appBarSource,
                  body: SizedBox.expand(child: $bodySource),
                  floatingActionButton: $fabSource,
                );
              }
            }
        """.trimIndent() + "\n"
    }

    private fun renderNode(node: JSONObject, logic: JSONObject): String {
        val type = node.optString("type", "text")
        val properties = node.optJSONObject("properties") ?: JSONObject()
        val children = node.optJSONArray("children") ?: JSONArray()
        fun child(index: Int = 0): String =
            children.optJSONObject(index)?.let { renderNode(it, logic) } ?: "SizedBox.shrink()"
        fun childList(): String = (0 until children.length())
            .mapNotNull { children.optJSONObject(it) }
            .joinToString(", ") { renderNode(it, logic) }
        fun number(name: String, fallback: Double): Double =
            properties.optDouble(name, fallback).takeIf { it.isFinite() } ?: fallback
        fun color(name: String): String = colorSource(properties.optString(name))

        return when (type) {
            "column" -> {
                val main = axisAlignment(properties.optString("mainAxisAlignment"), true)
                val cross = axisAlignment(properties.optString("crossAxisAlignment"), false)
                val mainSize = if (properties.optString("mainAxisSize") == "min") "min" else "max"
                val vertical = if (properties.optString("verticalDirection") == "up") "up" else "down"
                val direction = if (properties.optString("textDirection") == "rtl") "rtl" else "ltr"
                "Column(mainAxisAlignment: MainAxisAlignment.$main, crossAxisAlignment: CrossAxisAlignment.$cross, mainAxisSize: MainAxisSize.$mainSize, verticalDirection: VerticalDirection.$vertical, textDirection: TextDirection.$direction, children: [${childList()}])"
            }
            "row" -> {
                val main = axisAlignment(properties.optString("mainAxisAlignment"), true)
                val cross = axisAlignment(properties.optString("crossAxisAlignment"), false)
                val mainSize = if (properties.optString("mainAxisSize") == "min") "min" else "max"
                val vertical = if (properties.optString("verticalDirection") == "up") "up" else "down"
                val direction = if (properties.optString("textDirection") == "rtl") "rtl" else "ltr"
                "Row(mainAxisAlignment: MainAxisAlignment.$main, crossAxisAlignment: CrossAxisAlignment.$cross, mainAxisSize: MainAxisSize.$mainSize, verticalDirection: VerticalDirection.$vertical, textDirection: TextDirection.$direction, children: [${childList()}])"
            }
            "stack" -> {
                val fit = when (properties.optString("fit")) {
                    "expand", "passthrough" -> properties.optString("fit")
                    else -> "loose"
                }
                "Stack(alignment: ${alignmentSource(properties.optString("alignment", "topLeft"))}, fit: StackFit.$fit, clipBehavior: ${clipSource(properties.optString("clipBehavior", "hardEdge"))}, children: [${childList()}])"
            }
            "container" -> {
                val padding = number("padding", 12.0)
                val margin = number("margin", 0.0)
                val width = number("width", 0.0)
                val height = number("height", 0.0)
                val radius = number("borderRadius", 0.0)
                val borderWidth = number("borderWidth", 0.0)
                val borderColor = color("borderColor").takeUnless { it == "null" } ?: "Colors.transparent"
                val border = if (borderWidth > 0) "Border.all(color: $borderColor, width: $borderWidth)" else "null"
                "Container(width: ${if (width > 0) width else "null"}, height: ${if (height > 0) height else "null"}, padding: EdgeInsets.all($padding), margin: EdgeInsets.all($margin), alignment: ${alignmentSource(properties.optString("alignment", "topLeft"))}, decoration: BoxDecoration(color: ${color("backgroundColor")}, border: $border, borderRadius: BorderRadius.circular($radius)), child: ${child()})"
            }
            "center" -> {
                val width = number("widthFactor", 0.0)
                val height = number("heightFactor", 0.0)
                "Center(widthFactor: ${if (width > 0) width else "null"}, heightFactor: ${if (height > 0) height else "null"}, child: ${child()})"
            }
            "padding" -> {
                val padding = number("padding", 16.0)
                val edgeInsets = if (properties.optBoolean("individual", false)) {
                    "EdgeInsets.fromLTRB(${number("left", 16.0)}, ${number("top", 16.0)}, ${number("right", 16.0)}, ${number("bottom", 16.0)})"
                } else "EdgeInsets.all($padding)"
                "Padding(padding: $edgeInsets, child: ${child()})"
            }
            "card" -> "Card(elevation: ${number("elevation", 1.0)}, margin: EdgeInsets.all(${number("margin", 4.0)}), color: ${color("color")}, clipBehavior: ${clipSource(properties.optString("clipBehavior", "none"))}, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(${number("borderRadius", 12.0)})), child: Padding(padding: EdgeInsets.all(${number("padding", 12.0)}), child: ${child()}))"
            "expanded" -> {
                val flex = properties.optInt("flex", 1).coerceIn(1, 12)
                "Expanded(flex: $flex, child: ${child()})"
            }
            "sizedBox" -> {
                val width = number("width", 16.0)
                val height = number("height", 16.0)
                "SizedBox(width: $width, height: $height)"
            }
            "spacer" -> "Spacer(flex: ${properties.optInt("flex", 1).coerceIn(1, 12)})"
            "text" -> {
                val value = if (properties.optString("binding") == "counter") {
                    "'${'$'}{_controller.counter}'"
                } else {
                    "'${dartString(properties.optString("text", "Text"))}'"
                }
                val align = when (properties.optString("textAlign")) {
                    "center", "right", "justify" -> properties.optString("textAlign")
                    else -> "left"
                }
                val style = when (properties.optString("style")) {
                    "headlineLarge", "headlineMedium", "headlineSmall", "titleLarge", "titleMedium", "bodyLarge", "bodyMedium", "bodySmall" ->
                        ", style: Theme.of(context).textTheme.${properties.optString("style")}"
                    else -> ""
                }
                val maxLines = properties.optInt("maxLines", 0)
                val overflow = when (properties.optString("overflow")) {
                    "ellipsis", "fade", "visible" -> properties.optString("overflow")
                    else -> "clip"
                }
                val weight = when (properties.optString("fontWeight")) {
                    "w300", "w500", "w600", "bold" -> properties.optString("fontWeight")
                    else -> "normal"
                }
                val fontSize = number("fontSize", 0.0)
                val baseStyle = if (style.isBlank()) "Theme.of(context).textTheme.bodyLarge" else style.removePrefix(", style: ")
                val styled = "$baseStyle?.copyWith(fontSize: ${if (fontSize > 0) fontSize else "null"}, fontWeight: FontWeight.$weight, color: ${color("color")}, letterSpacing: ${number("letterSpacing", 0.0)}, height: ${number("lineHeight", 1.0)})"
                "Text($value, textAlign: TextAlign.$align, maxLines: ${if (maxLines > 0) maxLines else "null"}, overflow: TextOverflow.$overflow, softWrap: ${properties.optBoolean("softWrap", true)}, style: $styled)"
            }
            "icon" -> {
                val icon = iconSource(properties.optString("icon", "star"))
                val semantic = properties.optString("semanticLabel")
                "Icon($icon, size: ${number("size", 32.0)}, color: ${color("color")}, semanticLabel: ${if (semantic.isBlank()) "null" else "'${dartString(semantic)}'"})"
            }
            "image" -> {
                val asset = properties.optString("asset")
                if (asset.isBlank()) {
                    "Opacity(opacity: ${number("opacity", 1.0).coerceIn(0.0, 1.0)}, child: ClipRRect(borderRadius: BorderRadius.circular(${number("borderRadius", 0.0)}), child: Container(width: ${number("width", 120.0)}, height: ${number("height", 120.0)}, alignment: ${alignmentSource(properties.optString("alignment", "center"))}, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Icon(Icons.image_outlined))))"
                } else {
                    val fit = when (properties.optString("fit", "cover")) {
                        "contain", "fill", "fitWidth", "fitHeight" -> properties.optString("fit")
                        else -> "cover"
                    }
                    "Opacity(opacity: ${number("opacity", 1.0).coerceIn(0.0, 1.0)}, child: ClipRRect(borderRadius: BorderRadius.circular(${number("borderRadius", 0.0)}), child: Image.asset('${dartString(asset)}', width: ${number("width", 120.0)}, height: ${number("height", 120.0)}, fit: BoxFit.$fit, alignment: ${alignmentSource(properties.optString("alignment", "center"))})))"
                }
            }
            "divider" -> "Divider(height: ${number("height", 16.0)}, thickness: ${number("thickness", 1.0)}, indent: ${number("indent", 0.0)}, endIndent: ${number("endIndent", 0.0)}, color: ${color("color")})"
            "button" -> {
                val pressed = eventStatements(logic, node.optString("id"), "onPressed")
                val longPressed = eventStatements(logic, node.optString("id"), "onLongPress")
                val enabled = properties.optBoolean("enabled", true)
                val variant = properties.optString("variant", "filled")
                val widthMode = properties.optString("widthMode", "auto")
                val width = number("width", 160.0)
                val height = number("height", 48.0)
                "AppButton(label: '${dartString(properties.optString("text", "Button"))}', variant: AppButtonVariant.$variant, widthMode: AppButtonWidth.$widthMode, width: $width, height: $height, icon: ${iconSourceOrNull(properties.optString("icon", "none"))}, iconOnRight: ${properties.optString("iconPosition") == "right"}, tooltip: '${dartString(properties.optString("tooltip"))}', borderRadius: ${number("borderRadius", 99.0)}, textSize: ${number("textSize", 0.0)}, onPressed: ${if (enabled) "() async { $pressed }" else "null"}, onLongPress: ${if (enabled && longPressed.isNotBlank()) "() async { $longPressed }" else "null"})"
            }
            "textField" -> {
                val changed = eventStatements(logic, node.optString("id"), "onChanged")
                val submitted = eventStatements(logic, node.optString("id"), "onSubmitted")
                "AppTextField(label: '${dartString(properties.optString("label", "Input"))}', hint: '${dartString(properties.optString("hint", ""))}', keyboardType: AppKeyboardType.${properties.optString("keyboardType", "text")}, obscureText: ${properties.optBoolean("obscureText", false)}, enabled: ${properties.optBoolean("enabled", true)}, readOnly: ${properties.optBoolean("readOnly", false)}, maxLines: ${properties.optInt("maxLines", 1).coerceIn(1, 20)}, prefixIcon: ${iconSourceOrNull(properties.optString("prefixIcon", "none"))}, onChanged: (value) async { $changed }, onSubmitted: (value) async { $submitted })"
            }
            "checkbox" -> {
                val checked = properties.optBoolean("value", false)
                val changed = eventStatements(logic, node.optString("id"), "onChanged")
                "AppCheckbox(label: '${dartString(properties.optString("label", "Checkbox"))}', initialValue: $checked, enabled: ${properties.optBoolean("enabled", true)}, controlAffinity: ListTileControlAffinity.${if (properties.optString("controlAffinity") == "trailing") "trailing" else "leading"}, onChanged: (value) async { $changed })"
            }
            "switch" -> {
                val checked = properties.optBoolean("value", false)
                val changed = eventStatements(logic, node.optString("id"), "onChanged")
                "AppSwitch(label: '${dartString(properties.optString("label", "Switch"))}', initialValue: $checked, enabled: ${properties.optBoolean("enabled", true)}, controlAffinity: ListTileControlAffinity.${if (properties.optString("controlAffinity") == "trailing") "trailing" else "leading"}, onChanged: (value) async { $changed })"
            }
            "slider" -> {
                val changed = eventStatements(logic, node.optString("id"), "onChanged")
                val min = number("min", 0.0)
                val max = number("max", 1.0).takeIf { it > min } ?: min + 1.0
                val value = number("value", 0.5).coerceIn(min, max)
                val divisions = properties.optInt("divisions", 0).coerceAtLeast(0)
                "AppSlider(initialValue: $value, min: $min, max: $max, divisions: ${if (divisions > 0) divisions else "null"}, label: '${dartString(properties.optString("label"))}', enabled: ${properties.optBoolean("enabled", true)}, onChanged: (value) async { $changed })"
            }
            "listView" -> {
                val axis = if (properties.optString("scrollDirection") == "horizontal") "horizontal" else "vertical"
                "ListView(scrollDirection: Axis.$axis, reverse: ${properties.optBoolean("reverse", false)}, shrinkWrap: ${properties.optBoolean("shrinkWrap", true)}, padding: EdgeInsets.all(${number("padding", 0.0)}), children: [${childList()}])"
            }
            "gridView" -> {
                val columns = properties.optInt("columns", 2).coerceIn(1, 6)
                val axis = if (properties.optString("scrollDirection") == "horizontal") "horizontal" else "vertical"
                "GridView.count(shrinkWrap: true, scrollDirection: Axis.$axis, reverse: ${properties.optBoolean("reverse", false)}, padding: EdgeInsets.all(${number("padding", 0.0)}), crossAxisCount: $columns, mainAxisSpacing: ${number("mainAxisSpacing", 0.0)}, crossAxisSpacing: ${number("crossAxisSpacing", 0.0)}, childAspectRatio: ${number("childAspectRatio", 1.0)}, children: [${childList()}])"
            }
            "scrollView" -> {
                val axis = if (properties.optString("scrollDirection") == "horizontal") "horizontal" else "vertical"
                "SingleChildScrollView(scrollDirection: Axis.$axis, reverse: ${properties.optBoolean("reverse", false)}, padding: EdgeInsets.all(${number("padding", 0.0)}), child: ${child()})"
            }
            "progress" -> {
                val value = if (properties.optBoolean("indeterminate", false)) "null" else number("value", 0.65).coerceIn(0.0, 1.0).toString()
                if (properties.optString("type") == "linear") {
                    "LinearProgressIndicator(value: $value, color: ${color("color")}, backgroundColor: ${color("backgroundColor")}, minHeight: ${number("strokeWidth", 4.0)})"
                } else {
                    "CircularProgressIndicator(value: $value, color: ${color("color")}, backgroundColor: ${color("backgroundColor")}, strokeWidth: ${number("strokeWidth", 4.0)})"
                }
            }
            else -> "Text('Unsupported widget: ${dartString(type)}')"
        }
    }

    private fun axisAlignment(value: String, main: Boolean): String = if (main) {
        when (value) {
            "center", "end", "spaceAround", "spaceBetween", "spaceEvenly" -> value
            else -> "start"
        }
    } else {
        when (value) {
            "center", "end", "stretch", "baseline" -> value
            else -> "start"
        }
    }

    private fun alignmentSource(value: String): String = when (value) {
        "topCenter", "topRight", "centerLeft", "center", "centerRight",
        "bottomLeft", "bottomCenter", "bottomRight" -> "Alignment.$value"
        else -> "Alignment.topLeft"
    }

    private fun clipSource(value: String): String = when (value) {
        "hardEdge" -> "Clip.hardEdge"
        "antiAlias" -> "Clip.antiAlias"
        else -> "Clip.none"
    }

    private fun colorSource(value: String): String {
        val source = value.trim().removePrefix("#")
        if (source.isBlank() || source == "00000000") return "null"
        val normalized = if (source.length == 6) "FF$source" else source
        return if (normalized.length == 8 && normalized.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) {
            "const Color(0x$normalized)"
        } else "null"
    }

    private fun iconSourceOrNull(value: String): String =
        if (value.isBlank() || value == "none") "null" else iconSource(value)

    private fun iconSource(value: String): String = when (value) {
        "add" -> "Icons.add"
        "star" -> "Icons.star"
        "home" -> "Icons.home"
        "menu" -> "Icons.menu"
        "favorite" -> "Icons.favorite"
        "settings" -> "Icons.settings"
        "person" -> "Icons.person"
        "search" -> "Icons.search"
        "close" -> "Icons.close"
        "check" -> "Icons.check"
        "delete" -> "Icons.delete"
        "edit" -> "Icons.edit"
        "arrowBack" -> "Icons.arrow_back"
        "arrowForward" -> "Icons.arrow_forward"
        "play" -> "Icons.play_arrow"
        "pause" -> "Icons.pause"
        "info" -> "Icons.info"
        "warning" -> "Icons.warning"
        "email" -> "Icons.email"
        "phone" -> "Icons.phone"
        "location" -> "Icons.location_on"
        "lock" -> "Icons.lock"
        else -> "Icons.circle_outlined"
    }

    private fun eventStatements(
        logic: JSONObject,
        widgetId: String,
        eventName: String = "onPressed",
    ): String {
        val events = logic.optJSONArray("events") ?: return ""
        val event = (0 until events.length())
            .mapNotNull { events.optJSONObject(it) }
            .firstOrNull {
                it.optString("widgetId") == widgetId &&
                    it.optString("event", "onPressed") == eventName
            }
            ?: return ""
        val blocks = event.optJSONArray("blocks") ?: return ""
        return (0 until blocks.length())
            .mapNotNull { blocks.optJSONObject(it) }
            .joinToString(" ") { block ->
                when (block.optString("type")) {
                    "setVariable" -> {
                        val legacyValue = block.optJSONObject("value")
                        if (legacyValue != null) {
                            val step = legacyValue.optJSONObject("right")?.optInt("value", 1) ?: 1
                            "_controller.changeCounter($step); CustomActions.counterChanged(context, _controller.counter);"
                        } else {
                            val variableId = safeIdentifier(block.optString("variableId", "counter"))
                            val variable = findVariable(logic, variableId)
                            val type = variableType(variable?.optString("type", "int") ?: "int")
                            val title = pascalCase(variableId)
                            val rawValue = block.opt("value")
                            when (block.optString("operation", "set")) {
                                "add" -> "_controller.change$title(${dartTypedValue(rawValue, if (type == "double") "double" else "int")});"
                                "subtract" -> "_controller.change$title(-(${dartTypedValue(rawValue, if (type == "double") "double" else "int")}));"
                                else -> "_controller.set$title(${dartTypedValue(rawValue, type)});"
                            }
                        }
                    }
                    "showSnackBar" -> {
                        val message = dartString(block.optString("message", "Hello from Flutterware"))
                        "ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$message')));"
                    }
                    "customAction" -> {
                        val name = dartString(block.optString("name", "action"))
                        "ActionHandlers.run(context, '$name');"
                    }
                    "delay" -> {
                        val milliseconds = block.optInt("milliseconds", 500).coerceIn(0, 60000)
                        "await Future<void>.delayed(Duration(milliseconds: $milliseconds));"
                    }
                    "navigate" -> {
                        val route = dartString(block.optString("route", "/"))
                        "if (context.mounted) await Navigator.of(context).pushNamed('$route');"
                    }
                    "pop" -> "if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();"
                    "showDialog" -> {
                        val title = dartString(block.optString("title", "Notice"))
                        val message = dartString(block.optString("message", "Dialog message"))
                        "if (context.mounted) await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text('$title'), content: Text('$message'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))]));"
                    }
                    "log" -> {
                        val message = dartString(block.optString("message", "Flutterware log"))
                        "debugPrint('$message');"
                    }
                    "stopEvent" -> "return;"
                    "customCode" -> block.optString("code", "// Custom Dart code")
                    "customBlock" -> customBlockStatement(logic, block)
                    else -> ""
                }
            }
    }

    private fun findVariable(logic: JSONObject, id: String): JSONObject? {
        val variables = logic.optJSONArray("variables") ?: return null
        return (0 until variables.length())
            .mapNotNull { variables.optJSONObject(it) }
            .firstOrNull { safeIdentifier(it.optString("id")) == id }
    }

    private fun customBlockStatement(logic: JSONObject, call: JSONObject): String {
        val customBlocks = logic.optJSONArray("customBlocks") ?: return ""
        val definition = (0 until customBlocks.length())
            .mapNotNull { customBlocks.optJSONObject(it) }
            .firstOrNull { it.optString("id") == call.optString("customBlockId") }
            ?: return ""
        val method = safeIdentifier(definition.optString("id", "customBlock"))
        val parameters = definition.optJSONArray("parameters") ?: JSONArray()
        val arguments = call.optJSONObject("arguments") ?: JSONObject()
        val values = (0 until parameters.length()).mapNotNull { index ->
            parameters.optJSONObject(index)?.let { parameter ->
                val name = parameter.optString("name", "value")
                dartTypedValue(arguments.opt(name), variableType(parameter.optString("type", "dynamic")))
            }
        }
        val suffix = if (values.isEmpty()) "" else ", ${values.joinToString(", ")}"
        return "await _controller.$method(context$suffix);"
    }

    private fun appButtonWidgetDart() = """
        import 'package:flutter/material.dart';

        enum AppButtonVariant { filled, tonal, elevated, outlined, text }
        enum AppButtonWidth { auto, full, fixed }

        class AppButton extends StatelessWidget {
          const AppButton({
            super.key,
            required this.label,
            required this.onPressed,
            this.onLongPress,
            this.variant = AppButtonVariant.filled,
            this.widthMode = AppButtonWidth.auto,
            this.width = 160,
            this.height = 48,
            this.icon,
            this.iconOnRight = false,
            this.tooltip = '',
            this.borderRadius = 99,
            this.textSize = 0,
          });

          final String label;
          final VoidCallback? onPressed;
          final VoidCallback? onLongPress;
          final AppButtonVariant variant;
          final AppButtonWidth widthMode;
          final double width;
          final double height;
          final IconData? icon;
          final bool iconOnRight;
          final String tooltip;
          final double borderRadius;
          final double textSize;

          @override
          Widget build(BuildContext context) {
            final style = ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, height)),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius))),
            );
            final text = Text(label, style: TextStyle(fontSize: textSize > 0 ? textSize : null));
            final child = icon == null ? text : Row(
              mainAxisSize: MainAxisSize.min,
              children: iconOnRight
                  ? [text, const SizedBox(width: 8), Icon(icon!)]
                  : [Icon(icon!), const SizedBox(width: 8), text],
            );
            final button = switch (variant) {
              AppButtonVariant.tonal => FilledButton.tonal(onPressed: onPressed, onLongPress: onLongPress, style: style, child: child),
              AppButtonVariant.elevated => ElevatedButton(onPressed: onPressed, onLongPress: onLongPress, style: style, child: child),
              AppButtonVariant.outlined => OutlinedButton(onPressed: onPressed, onLongPress: onLongPress, style: style, child: child),
              AppButtonVariant.text => TextButton(onPressed: onPressed, onLongPress: onLongPress, style: style, child: child),
              AppButtonVariant.filled => FilledButton(onPressed: onPressed, onLongPress: onLongPress, style: style, child: child),
            };
            final sized = switch (widthMode) {
              AppButtonWidth.full => SizedBox(width: double.infinity, child: button),
              AppButtonWidth.fixed => SizedBox(width: width, child: button),
              AppButtonWidth.auto => button,
            };
            return tooltip.isEmpty ? sized : Tooltip(message: tooltip, child: sized);
          }
        }
    """.trimIndent() + "\n"

    private fun appTextFieldWidgetDart() = """
        import 'package:flutter/material.dart';

        enum AppKeyboardType { text, number, email, phone }

        class AppTextField extends StatelessWidget {
          const AppTextField({super.key, required this.label, this.hint = '', this.keyboardType = AppKeyboardType.text, this.obscureText = false, this.enabled = true, this.readOnly = false, this.maxLines = 1, this.prefixIcon, this.onChanged, this.onSubmitted});
          final String label;
          final String hint;
          final AppKeyboardType keyboardType;
          final bool obscureText;
          final bool enabled;
          final bool readOnly;
          final int maxLines;
          final IconData? prefixIcon;
          final ValueChanged<String>? onChanged;
          final ValueChanged<String>? onSubmitted;

          @override
          Widget build(BuildContext context) => TextField(
            obscureText: obscureText,
            enabled: enabled,
            readOnly: readOnly,
            maxLines: obscureText ? 1 : maxLines,
            keyboardType: switch (keyboardType) {
              AppKeyboardType.number => TextInputType.number,
              AppKeyboardType.email => TextInputType.emailAddress,
              AppKeyboardType.phone => TextInputType.phone,
              AppKeyboardType.text => TextInputType.text,
            },
            decoration: InputDecoration(labelText: label, hintText: hint.isEmpty ? null : hint, prefixIcon: prefixIcon == null ? null : Icon(prefixIcon!)),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          );
        }
    """.trimIndent() + "\n"

    private fun appCheckboxWidgetDart() = """
        import 'package:flutter/material.dart';
        class AppCheckbox extends StatefulWidget {
          const AppCheckbox({super.key, required this.label, required this.initialValue, this.enabled = true, this.controlAffinity = ListTileControlAffinity.leading, this.onChanged});
          final String label; final bool initialValue; final bool enabled; final ListTileControlAffinity controlAffinity; final ValueChanged<bool>? onChanged;
          @override State<AppCheckbox> createState() => _AppCheckboxState();
        }
        class _AppCheckboxState extends State<AppCheckbox> {
          late bool value = widget.initialValue;
          @override Widget build(BuildContext context) => CheckboxListTile(
            contentPadding: EdgeInsets.zero, title: Text(widget.label), value: value, controlAffinity: widget.controlAffinity,
            onChanged: !widget.enabled ? null : (next) { if (next == null) return; setState(() => value = next); widget.onChanged?.call(next); },
          );
        }
    """.trimIndent() + "\n"

    private fun appSwitchWidgetDart() = """
        import 'package:flutter/material.dart';
        class AppSwitch extends StatefulWidget {
          const AppSwitch({super.key, required this.label, required this.initialValue, this.enabled = true, this.controlAffinity = ListTileControlAffinity.leading, this.onChanged});
          final String label; final bool initialValue; final bool enabled; final ListTileControlAffinity controlAffinity; final ValueChanged<bool>? onChanged;
          @override State<AppSwitch> createState() => _AppSwitchState();
        }
        class _AppSwitchState extends State<AppSwitch> {
          late bool value = widget.initialValue;
          @override Widget build(BuildContext context) => SwitchListTile(
            contentPadding: EdgeInsets.zero, title: Text(widget.label), value: value, controlAffinity: widget.controlAffinity,
            onChanged: !widget.enabled ? null : (next) { setState(() => value = next); widget.onChanged?.call(next); },
          );
        }
    """.trimIndent() + "\n"

    private fun appSliderWidgetDart() = """
        import 'package:flutter/material.dart';
        class AppSlider extends StatefulWidget {
          const AppSlider({super.key, required this.initialValue, this.min = 0, this.max = 1, this.divisions, this.label = '', this.enabled = true, this.onChanged});
          final double initialValue; final double min; final double max; final int? divisions; final String label; final bool enabled; final ValueChanged<double>? onChanged;
          @override State<AppSlider> createState() => _AppSliderState();
        }
        class _AppSliderState extends State<AppSlider> {
          late double value = widget.initialValue;
          @override Widget build(BuildContext context) => Slider(
            value: value, min: widget.min, max: widget.max, divisions: widget.divisions, label: widget.label.isEmpty ? null : widget.label,
            onChanged: !widget.enabled ? null : (next) { setState(() => value = next); widget.onChanged?.call(next); },
          );
        }
    """.trimIndent() + "\n"

    private fun customActions() = """
        import 'package:flutter/widgets.dart';

        /// User-owned Dart code. Flutterware never regenerates this file.
        abstract final class CustomActions {
          static void counterChanged(BuildContext context, int value) {
            // Add custom behavior here, then call it from a Custom Action block.
          }

          static void run(BuildContext context, String actionName) {
            // Handle named Custom Action blocks here.
          }
        }
    """.trimIndent() + "\n"

    private fun actionHandlers() = """
        import 'package:flutter/widgets.dart';

        /// User-owned named actions called by Custom Action logic blocks.
        abstract final class ActionHandlers {
          static void run(BuildContext context, String actionName) {
            // Add named actions here. Example: if (actionName == 'save') { ... }
          }
        }
    """.trimIndent() + "\n"

    private fun counterStep(project: File): Int = runCatching {
        JSONObject(File(project, "$MODEL_DIRECTORY/logic.json").readText())
            .getJSONArray("events")
            .getJSONObject(0)
            .getJSONArray("blocks")
            .getJSONObject(0)
            .getJSONObject("value")
            .getJSONObject("right")
            .getInt("value")
    }.getOrDefault(1)

    private fun pubspec(projectId: String) = """
        name: $projectId
        description: A Flutter application created with Flutterware.
        publish_to: none
        version: 1.0.0+1

        environment:
          sdk: '>=3.9.0 <4.0.0'

        dependencies:
          flutter:
            sdk: flutter

        flutter:
          uses-material-design: true
          assets:
            - assets/
    """.trimIndent() + "\n"

    private fun gitignore() = """
        .dart_tool/
        .flutter-plugins
        .flutter-plugins-dependencies
        .packages
        build/
        android/.gradle/
        android/local.properties
    """.trimIndent() + "\n"

    private fun projectReadme(name: String) = """
        # $name

        This Flutter project was created on-device with Flutterware.

        Flutterware generates a feature-first structure under `lib/app/`, `lib/core/`, and
        `lib/features/`. Put hand-written Dart code in `lib/custom/` so regeneration never
        overwrites it.
    """.trimIndent() + "\n"

    private fun dartString(value: String): String = value
        .replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "")

    private fun writeIfMissing(file: File, content: String) {
        if (!file.exists()) writeAtomic(file, content)
    }

    private fun writeAtomic(file: File, content: String) {
        file.parentFile?.mkdirs()
        val temporary = File(file.parentFile, ".${file.name}.tmp")
        temporary.writeText(content, StandardCharsets.UTF_8)
        check(!file.exists() || file.delete()) { "Could not replace ${file.path}" }
        check(temporary.renameTo(file)) { "Could not activate ${file.path}" }
    }
}
