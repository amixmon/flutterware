import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterware/app/fluttware_app.dart';
import 'package:flutterware/features/about/presentation/about_page.dart';
import 'package:flutterware/features/projects/presentation/new_project_page.dart';
import 'package:flutterware/features/projects/domain/demo_project_template.dart';
import 'package:flutterware/features/projects/domain/project_summary.dart';
import 'package:flutterware/features/editor/presentation/visual_editor.dart';
import 'package:flutterware/features/editor/presentation/logic_editor.dart';
import 'package:flutterware/features/editor/presentation/editor_page.dart';
import 'package:flutterware/features/editor/domain/editor_models.dart';
import 'package:flutterware/features/editor/domain/logic_models.dart';
import 'package:flutterware/features/projects/domain/project_file.dart';
import 'package:flutterware/ui/theme/app_theme.dart';
import 'package:flutterware/ui/widgets/app_code_editor.dart';
import 'package:flutterware/ui/widgets/app_text_field.dart';

void main() {
  test('new layouts default to start alignment in preview and generation', () {
    final column = WidgetCatalog.byType('column');
    final row = WidgetCatalog.byType('row');
    expect(column.defaultProperties['mainAxisAlignment'], 'start');
    expect(column.defaultProperties['crossAxisAlignment'], 'start');
    expect(row.defaultProperties['mainAxisAlignment'], 'start');
    expect(row.defaultProperties['crossAxisAlignment'], 'start');

    final fallback = ScreenDesign.fallback('Sample App');
    expect(fallback.body.properties['mainAxisAlignment'], 'start');
    expect(fallback.body.properties['crossAxisAlignment'], 'start');
  });

  test('demo templates contain editable UI and valid logic targets', () {
    expect(DemoProjectTemplates.all, hasLength(5));
    expect(
      DemoProjectTemplates.all.map((template) => template.id).toSet(),
      hasLength(5),
    );
    expect(
      DemoProjectTemplates.all.where(
        (template) => template.complexity == DemoComplexity.advanced,
      ),
      hasLength(3),
    );

    for (final template in DemoProjectTemplates.all) {
      final roundTrip = ScreenDesign.fromJsonString(
        template.design.toJsonString(),
      );
      expect(roundTrip.pages, hasLength(template.design.pages.length));
      expect(template.logic['events'], isNotEmpty, reason: template.name);

      final widgetIds = <String>{};
      void collect(WidgetNode node) {
        widgetIds.add(node.id);
        for (final child in node.children) {
          collect(child);
        }
      }

      for (final page in template.design.pages) {
        collect(page.body);
      }
      for (final event
          in (template.logic['events']! as List<Map<String, Object?>>)) {
        expect(
          widgetIds,
          contains(event['widgetId']),
          reason: '${template.name}: ${event['id']}',
        );
      }
    }
  });

  test('system bars are transparent with dynamic light and dark icons', () {
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;
    final lightOverlay = AppTheme.systemOverlay(light);
    final darkOverlay = AppTheme.systemOverlay(dark);

    expect(light.surface, const Color(0xFFF8FAFF));
    expect(dark.surface, const Color(0xFF181818));
    expect(dark.surfaceContainerLowest, const Color(0xFF111111));
    expect(dark.surfaceContainerHighest, const Color(0xFF313131));
    expect(dark.onSurface, const Color(0xFFD4D4D4));
    expect(lightOverlay.statusBarColor, Colors.transparent);
    expect(darkOverlay.statusBarColor, Colors.transparent);
    expect(lightOverlay.statusBarIconBrightness, Brightness.dark);
    expect(darkOverlay.statusBarIconBrightness, Brightness.light);
    expect(lightOverlay.systemNavigationBarColor, Colors.transparent);
    expect(darkOverlay.systemNavigationBarColor, Colors.transparent);
    expect(lightOverlay.systemNavigationBarIconBrightness, Brightness.dark);
    expect(darkOverlay.systemNavigationBarIconBrightness, Brightness.light);
    expect(lightOverlay.systemNavigationBarContrastEnforced, isFalse);
    expect(darkOverlay.systemNavigationBarContrastEnforced, isFalse);
  });

  test('every design widget exposes a complete property sheet', () {
    for (final definition in WidgetCatalog.definitions) {
      final properties = WidgetCatalog.propertiesFor(definition);
      expect(properties, isNotEmpty, reason: definition.type);
      expect(
        properties.map((property) => property.key).toSet(),
        hasLength(properties.length),
        reason: '${definition.type} contains duplicate property keys',
      );
    }
    final button = WidgetCatalog.propertiesFor(WidgetCatalog.byType('button'));
    expect(
      button.map((property) => property.key),
      containsAll([
        'variant',
        'widthMode',
        'height',
        'icon',
        'tooltip',
        'borderRadius',
      ]),
    );
    final text = WidgetCatalog.propertiesFor(WidgetCatalog.byType('text'));
    expect(
      text.map((property) => property.key),
      containsAll(['fontSize', 'fontWeight', 'color', 'maxLines', 'overflow']),
    );
  });

  test('page custom UI and typed variables survive project serialization', () {
    final original = ScreenDesign.fallback('Sample App');
    final customUi = CustomWidgetDefinition(
      id: 'story_widget',
      name: 'Story widget',
      className: 'StoryWidget',
      path: 'lib/custom/widgets/story_widget.dart',
      parameters: const [
        CustomWidgetParameter(
          name: 'title',
          type: 'String',
          defaultValue: 'Story',
        ),
        CustomWidgetParameter(name: 'count', type: 'int', defaultValue: '0'),
      ],
      arguments: const {'title': 'Latest stories', 'count': '4'},
    );
    final updated = original.updatePage(
      original.initialPage.copyWith(customUi: customUi),
    );

    final decoded = ScreenDesign.fromJsonString(updated.toJsonString());

    expect(decoded.initialPage.customUi?.className, 'StoryWidget');
    expect(decoded.initialPage.customUi?.path, customUi.path);
    expect(decoded.initialPage.customUi?.parameters, hasLength(2));
    expect(decoded.initialPage.customUi?.arguments['title'], 'Latest stories');
    expect(decoded.initialPage.customUi?.arguments['count'], '4');
  });

  test('renaming a widget ID migrates logic references without mutation', () {
    final original = <String, Object?>{
      'schemaVersion': 1,
      'events': <Object?>[
        <String, Object?>{
          'id': 'counter_value_onchanged',
          'widgetId': 'counter_value',
          'event': 'onChanged',
          'blocks': <Object?>[
            <String, Object?>{
              'type': 'customAction',
              'target': <String, Object?>{'widgetId': 'counter_value'},
            },
          ],
        },
        <String, Object?>{
          'id': 'other_onpressed',
          'widgetId': 'other',
          'event': 'onPressed',
        },
      ],
    };

    final renamed = renameLogicWidgetId(
      original,
      from: 'counter_value',
      to: 'total_value',
    );
    final events = renamed['events']! as List<Object?>;
    final renamedEvent = events.first! as Map<String, Object?>;
    final nestedTarget =
        ((renamedEvent['blocks']! as List<Object?>).first!
                as Map<String, Object?>)['target']
            as Map<String, Object?>;

    expect(renamedEvent['id'], 'total_value_onchanged');
    expect(renamedEvent['widgetId'], 'total_value');
    expect(nestedTarget['widgetId'], 'total_value');
    expect((events.last! as Map<String, Object?>)['widgetId'], 'other');
    expect(
      ((original['events']! as List<Object?>).first!
          as Map<String, Object?>)['widgetId'],
      'counter_value',
    );
  });

  test('project paths and source languages are detected correctly', () {
    final file = ProjectFile.fromMap({
      'path': 'lib/custom/actions.dart',
      'name': 'actions.dart',
      'directory': false,
      'generated': false,
      'editable': true,
      'openable': true,
      'size': 120,
    });
    expect(file.parentPath, 'lib/custom');
    expect(CodeLanguage.fromPath(file.path), CodeLanguage.dart);
    expect(
      CodeLanguage.fromPath('android/app/MainActivity.kt'),
      CodeLanguage.kotlin,
    );
    expect(CodeLanguage.fromPath('pubspec.yaml'), CodeLanguage.yaml);
  });

  testWidgets('syntax controller emits styled source tokens', (tester) async {
    final key = GlobalKey();
    final controller = SyntaxTextEditingController(
      language: CodeLanguage.dart,
      text: "class Example { final value = 'blue'; } // comment",
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SizedBox(key: key),
      ),
    );
    final span = controller.buildTextSpan(
      context: key.currentContext!,
      withComposing: false,
    );
    final children = span.children!.whereType<TextSpan>().toList();
    expect(
      children.any((child) => child.text == 'class' && child.style != null),
      isTrue,
    );
    expect(
      children.any((child) => child.text == "'blue'" && child.style != null),
      isTrue,
    );
    expect(
      children.any(
        (child) => child.text == '// comment' && child.style != null,
      ),
      isTrue,
    );
  });

  testWidgets('files view opens folders and shows direct children', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterware.app/runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'listProjectFiles') return null;
          return <Map<String, Object?>>[
            {
              'path': 'lib',
              'name': 'lib',
              'directory': true,
              'generated': false,
              'editable': false,
              'openable': false,
              'size': 0,
            },
            {
              'path': 'pubspec.yaml',
              'name': 'pubspec.yaml',
              'directory': false,
              'generated': false,
              'editable': true,
              'openable': true,
              'size': 300,
            },
            {
              'path': 'lib/custom',
              'name': 'custom',
              'directory': true,
              'generated': false,
              'editable': false,
              'openable': false,
              'size': 0,
            },
            {
              'path': 'lib/main.dart',
              'name': 'main.dart',
              'directory': false,
              'generated': true,
              'editable': false,
              'openable': true,
              'size': 80,
            },
            {
              'path': 'lib/custom/actions.dart',
              'name': 'actions.dart',
              'directory': false,
              'generated': false,
              'editable': true,
              'openable': true,
              'size': 140,
            },
          ];
        });
    const project = ProjectSummary(
      id: 'sample_app',
      name: 'Sample App',
      packageName: 'com.example.sample',
      modifiedLabel: 'Now',
      color: Color(0xFF168CF3),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ProjectFilesView(project: project)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('pubspec.yaml'), findsOneWidget);
    expect(find.text('custom'), findsNothing);

    await tester.tap(find.text('lib'));
    await tester.pump();
    expect(find.text('custom'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('pubspec.yaml'), findsNothing);

    await tester.tap(find.text('custom'));
    await tester.pump();
    expect(find.text('actions.dart'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('custom widgets tab lists reusable Dart UI and variables', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterware.app/runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'listCustomWidgets') return null;
          return <Map<String, Object?>>[
            {
              'id': 'story_widget',
              'name': 'Story widget',
              'className': 'StoryWidget',
              'path': 'lib/custom/widgets/story_widget.dart',
              'parameters': <Map<String, Object?>>[
                {'name': 'title', 'type': 'String', 'defaultValue': 'Story'},
              ],
              'arguments': <String, String>{},
            },
          ];
        });
    const project = ProjectSummary(
      id: 'sample_app',
      name: 'Sample App',
      packageName: 'com.example.sample',
      modifiedLabel: 'Now',
      color: Color(0xFF168CF3),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CustomWidgetsEditor(project: project)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reusable custom UI'), findsOneWidget);
    expect(find.text('Story widget'), findsOneWidget);
    expect(find.textContaining('StoryWidget • 1 variable'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows the Flutterware projects dashboard', (tester) async {
    await tester.pumpWidget(const FlutterwareApp());

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('On-device runtime'), findsOneWidget);
    final search = tester.widget<TextField>(find.byType(TextField).first);
    expect(search.decoration!.hintText, 'Search projects');
    expect(search.decoration!.labelText, isNull);
    expect(search.decoration!.enabledBorder, isNull);
    expect(search.decoration!.prefixIcon, isA<Icon>());
    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Sort projects'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TextField).first,
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
    expect(find.byType(SearchBar), findsNothing);
  });

  testWidgets('templates page presents runnable editable demo apps', (
    tester,
  ) async {
    await tester.pumpWidget(const FlutterwareApp());
    await tester.tap(find.byIcon(Icons.auto_awesome_mosaic_outlined));
    await tester.pump();

    expect(find.text('Demo apps'), findsOneWidget);
    expect(find.text('Building blocks'), findsOneWidget);
    expect(find.text('Counter Lab'), findsOneWidget);
    expect(find.text('Learn by taking things apart'), findsOneWidget);
    expect(find.text('Open & edit'), findsWidgets);
    expect(find.text('Run demo'), findsWidgets);
  });

  testWidgets('drawer opens the complete About page', (tester) async {
    await tester.pumpWidget(const FlutterwareApp());
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('About Flutterware'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pump();
    expect(find.text('Collaborate on GitHub'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
    expect(find.text(AboutPage.repositoryUrl), findsOneWidget);
  });

  testWidgets('create project uses shared themed controls', (tester) async {
    await tester.pumpWidget(const FlutterwareApp());
    await tester.tap(find.text('New project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NewProjectPage), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.text('Choose app icon'), findsOneWidget);
    expect(find.text('Create project'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    expect(find.text('Hex color'), findsOneWidget);
    expect(find.text('Open color wheel'), findsOneWidget);

    final context = tester.element(find.byType(NewProjectPage));
    final decoration = Theme.of(context).inputDecorationTheme;
    expect(Theme.of(context).appBarTheme.backgroundColor, Colors.transparent);
    final enabled = decoration.enabledBorder! as OutlineInputBorder;
    final focused = decoration.focusedBorder! as OutlineInputBorder;
    expect(enabled.borderSide.width, 1);
    expect(
      enabled.borderSide.color,
      Theme.of(context).colorScheme.outlineVariant,
    );
    expect(focused.borderSide.width, 2);
    expect(focused.borderSide.color, Theme.of(context).colorScheme.primary);

    final filledShape = Theme.of(context).filledButtonTheme.style?.shape;
    expect(filledShape?.resolve(<WidgetState>{}), isA<StadiumBorder>());
    expect(Theme.of(context).splashFactory, InkRipple.splashFactory);

    await tester.tap(find.text('Open color wheel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Preview  #'), findsOneWidget);
  });

  testWidgets('visual editor renders palette and responsive phone', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterware.app/runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readProjectDesign') {
            final design = ScreenDesign.fallback('Sample App');
            return design
                .updatePage(
                  design.initialPage.copyWith(
                    body: design.initialPage.body.copyWith(
                      children: [
                        ...design.initialPage.body.children,
                        const WidgetNode(
                          id: 'preview_button',
                          type: 'button',
                          properties: {
                            'text': 'Preview button',
                            'variant': 'filled',
                            'widthMode': 'auto',
                            'height': 48.0,
                            'enabled': true,
                          },
                        ),
                      ],
                    ),
                  ),
                )
                .toJsonString();
          }
          if (call.method == 'writeProjectDesign') return null;
          return null;
        });
    const project = ProjectSummary(
      id: 'sample_app',
      name: 'Sample App',
      packageName: 'com.example.sample',
      modifiedLabel: 'Edited just now',
      color: Color(0xFF168CF3),
    );
    final controller = VisualEditorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VisualEditor(project: project, controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Column'), findsOneWidget);
    expect(find.text('Sample App'), findsOneWidget);
    expect(find.text('9:41'), findsOneWidget);
    expect(
      find.text('You have pushed the button this many times:'),
      findsOneWidget,
    );

    final previewButtonBefore = tester.getTopLeft(find.text('Preview button'));
    final drag = await tester.startGesture(
      tester.getCenter(find.text('Column')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    expect(find.text('＋'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Preview button')),
      previewButtonBefore,
      reason: 'Drop targets must overlay the preview without reflowing it',
    );
    final previewButton = find.ancestor(
      of: find.text('Preview button'),
      matching: find.byType(FilledButton),
    );
    final previewButtonRect = tester.getRect(previewButton);
    await drag.moveTo(
      Offset(previewButtonRect.center.dx, previewButtonRect.top + 2),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('active-insertion-line')), findsWidgets);
    expect(tester.getTopLeft(find.text('Preview button')), previewButtonBefore);
    await drag.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Select widget from tree'));
    await tester.pumpAndSettle();
    expect(find.text('AppBar'), findsWidgets);
    expect(find.text('Floating button'), findsOneWidget);
    await tester.tap(find.text('AppBar'));
    await tester.pumpAndSettle();
    expect(find.text('AppBar properties'), findsNothing);

    final appBarCenter = tester.getCenter(find.text('Sample App'));
    await tester.tapAt(appBarCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(appBarCenter);
    await tester.pumpAndSettle();
    expect(find.text('AppBar properties'), findsOneWidget);
    Navigator.of(tester.element(find.text('AppBar properties'))).pop();
    await tester.pumpAndSettle();

    final buttonCenter = tester.getCenter(find.text('Preview button'));
    await tester.tapAt(buttonCenter);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Button properties'), findsNothing);
    await tester.tapAt(buttonCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(buttonCenter);
    await tester.pumpAndSettle();
    expect(find.text('Button properties'), findsOneWidget);
    expect(find.text('Button type'), findsOneWidget);
    expect(find.text('Icon'), findsOneWidget);
    Navigator.of(tester.element(find.text('Button properties'))).pop();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Wrap selected widget'), findsOneWidget);
    await tester.tap(find.byTooltip('Wrap selected widget'));
    await tester.pumpAndSettle();
    expect(find.text('Wrap widget'), findsOneWidget);
    expect(find.text('Choose a parent for Button'), findsOneWidget);
    await tester.tap(find.text('Padding').last);
    await tester.pumpAndSettle();
    WidgetNode? paddingAroundButton(WidgetNode node) {
      if (node.type == 'padding' &&
          node.children.any((child) => child.id == 'preview_button')) {
        return node;
      }
      for (final child in node.children) {
        final result = paddingAroundButton(child);
        if (result != null) return result;
      }
      return null;
    }

    expect(paddingAroundButton(controller.activePage!.body), isNotNull);

    await tester.tap(find.byTooltip('Screen settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Screen settings'), findsOneWidget);
    expect(find.text('AppBar'), findsWidgets);
    expect(find.text('Floating action button'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('project tools open from the right drawer', (tester) async {
    const channel = MethodChannel('com.flutterware.app/runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readProjectDesign') {
            return ScreenDesign.fallback('Sample App').toJsonString();
          }
          if (call.method == 'readProjectLogic') {
            return '{"schemaVersion":1,"variables":[],"events":[],"customBlocks":[]}';
          }
          if (call.method == 'listCustomWidgets' ||
              call.method == 'listProjectFiles') {
            return <Object?>[];
          }
          return null;
        });
    const project = ProjectSummary(
      id: 'sample_app',
      name: 'Sample App',
      packageName: 'com.example.sample',
      modifiedLabel: 'Edited just now',
      color: Color(0xFF168CF3),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const EditorPage(project: project),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Project tools'));
    await tester.pumpAndSettle();

    expect(find.text('Project tools'), findsOneWidget);
    expect(find.text('Package manager'), findsOneWidget);
    expect(find.text('Image manager'), findsOneWidget);
    expect(find.text('Font manager'), findsOneWidget);
    expect(find.text('Sound manager'), findsOneWidget);
    expect(find.text('Planned'), findsWidgets);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Permission manager'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('Debugger'), findsOneWidget);

    await tester.tap(find.text('Debugger'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Debugger is added'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('adding an Image imports and stores its project asset path', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterware.app/runtime');
    String? savedDesign;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readProjectDesign') {
            final design = ScreenDesign.fallback('Sample App');
            return design
                .updatePage(
                  design.initialPage.copyWith(
                    body: design.initialPage.body.copyWith(children: const []),
                  ),
                )
                .toJsonString();
          }
          if (call.method == 'importProjectAsset') {
            expect(call.arguments, {'id': 'sample_app', 'kind': 'image'});
            return <String, Object?>{
              'path': 'assets/images/photo.png',
              'name': 'photo.png',
              'kind': 'image',
              'size': 1200,
            };
          }
          if (call.method == 'writeProjectDesign') {
            savedDesign =
                (call.arguments as Map<Object?, Object?>)['content'] as String;
          }
          return null;
        });
    const project = ProjectSummary(
      id: 'sample_app',
      name: 'Sample App',
      packageName: 'com.example.sample',
      modifiedLabel: 'Edited just now',
      color: Color(0xFF168CF3),
    );
    final controller = VisualEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VisualEditor(project: project, controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Image');
    await tester.pump();
    await tester.tap(find.text('Image').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('photo.png'), findsOneWidget);
    expect(savedDesign, contains('assets/images/photo.png'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('logic editor is page scoped and opens block palette', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterware.app/runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readProjectDesign') {
            return ScreenDesign.fallback('Sample App').toJsonString();
          }
          if (call.method == 'readProjectLogic') {
            return '{"schemaVersion":1,"variables":[],"events":[],"customBlocks":[]}';
          }
          if (call.method == 'writeProjectLogic') return null;
          return null;
        });
    const project = ProjectSummary(
      id: 'sample_app',
      name: 'Sample App',
      packageName: 'com.example.sample',
      modifiedLabel: 'Edited just now',
      color: Color(0xFF168CF3),
    );
    final request = ValueNotifier<LogicEventRequest?>(null);
    addTearDown(request.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LogicEditor(project: project, requestedTarget: request),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HomeController'), findsOneWidget);
    expect(find.text('When Home starts'), findsWidgets);
    expect(find.text('Action blocks'), findsOneWidget);

    await tester.tap(find.text('Action blocks'));
    await tester.pumpAndSettle();
    expect(find.text('Variables'), findsOneWidget);
    expect(find.text('Set variable'), findsOneWidget);
    expect(find.text('Long-press a block, then drop it here'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
