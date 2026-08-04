import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../build/presentation/runtime_build_sheet.dart';
import '../../packages/presentation/package_manager_page.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_file.dart';
import '../../projects/domain/project_summary.dart';
import '../../themes/presentation/theme_studio_page.dart';
import '../domain/editor_models.dart';
import '../domain/logic_models.dart';
import '../../../ui/widgets/app_button.dart';
import '../../../ui/widgets/app_code_editor.dart';
import '../../../ui/widgets/app_text_field.dart';
import '../../../ui/theme/app_tokens.dart';
import '../../../runtime/runtime_controller.dart';
import 'visual_editor.dart';
import 'logic_editor.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.project});

  final ProjectSummary project;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late ProjectSummary _project;
  final _eventTarget = ValueNotifier<LogicEventRequest?>(null);
  final _designRevision = ValueNotifier<int>(0);
  final _visualController = VisualEditorController();

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  @override
  void dispose() {
    _eventTarget.dispose();
    _designRevision.dispose();
    _visualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.surfaceContainerLow,
          toolbarHeight: 62,
          titleSpacing: 2,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _project.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _project.packageName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            Builder(
              builder: (context) => IconButton.filledTonal(
                tooltip: 'Project tools',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Material(
                color: colors.surfaceContainer,
                borderRadius: AppRadii.inputBorder,
                clipBehavior: Clip.antiAlias,
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  indicator: ShapeDecoration(
                    color: colors.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  labelColor: colors.onSecondaryContainer,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  labelStyle: Theme.of(context).textTheme.labelLarge,
                  tabs: const [
                    Tab(text: 'Design', height: 44),
                    Tab(text: 'Logic', height: 44),
                    Tab(text: 'Widgets', height: 44),
                    Tab(text: 'Files', height: 44),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Builder(
          builder: (tabContext) => TabBarView(
            children: [
              VisualEditor(
                project: _project,
                controller: _visualController,
                onEditEvent: (widgetId, eventName, label) {
                  _eventTarget.value = LogicEventRequest(
                    widgetId,
                    eventName,
                    label,
                  );
                  DefaultTabController.of(tabContext).animateTo(1);
                },
                onWidgetRenamed: () {
                  _eventTarget.value = null;
                  _designRevision.value++;
                },
              ),
              LogicEditor(
                project: _project,
                requestedTarget: _eventTarget,
                designRevision: _designRevision,
              ),
              CustomWidgetsEditor(project: _project),
              ProjectFilesView(project: _project),
            ],
          ),
        ),
        bottomNavigationBar: _EditorBottomBar(
          project: _project,
          visualController: _visualController,
        ),
        endDrawer: _ProjectToolsDrawer(
          project: _project,
          onSelected: _showPlannedTool,
        ),
      ),
    );
  }

  Future<void> _showPlannedTool(String name) async {
    if (name == 'Theme Studio') {
      final updated = await Navigator.of(context).push<ProjectSummary>(
        MaterialPageRoute<ProjectSummary>(
          builder: (context) => ThemeStudioPage(project: _project),
        ),
      );
      if (updated != null && mounted) setState(() => _project = updated);
      return;
    }
    if (name == 'Package manager') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PackageManagerPage(project: _project),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$name is added and will be connected next.')),
      );
  }
}

class _ProjectToolsDrawer extends StatelessWidget {
  const _ProjectToolsDrawer({required this.project, required this.onSelected});

  final ProjectSummary project;
  final ValueChanged<String> onSelected;

  static const _managers = <_ProjectToolItem>[
    _ProjectToolItem(
      title: 'Theme Studio',
      description: 'Colors, type, shapes, and component styles',
      icon: Icons.palette_outlined,
      available: true,
    ),
    _ProjectToolItem(
      title: 'Package manager',
      description: 'Add and configure packages for this project',
      icon: Icons.inventory_2_outlined,
      available: true,
    ),
    _ProjectToolItem(
      title: 'Image manager',
      description: 'Import and organize assets/images',
      icon: Icons.image_outlined,
    ),
    _ProjectToolItem(
      title: 'Font manager',
      description: 'Import and configure project fonts',
      icon: Icons.font_download_outlined,
    ),
    _ProjectToolItem(
      title: 'Sound manager',
      description: 'Import and organize audio assets',
      icon: Icons.audio_file_outlined,
    ),
    _ProjectToolItem(
      title: 'Permission manager',
      description: 'Configure Android and runtime permissions',
      icon: Icons.shield_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(292, 336).toDouble(),
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(AppRadii.sheet),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
              child: Material(
                color: colors.surfaceContainer,
                borderRadius: AppRadii.cardBorder,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.construction_rounded,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project tools',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close tools',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Project capabilities',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: ShapeDecoration(
                      color: colors.secondaryContainer,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      '${_managers.where((item) => item.available).length} ready',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                children: [
                  _ProjectToolGroup(
                    label: 'Managers',
                    items: _managers,
                    onSelected: onSelected,
                  ),
                  const SizedBox(height: 12),
                  _ProjectToolGroup(
                    label: 'Developer tools',
                    items: [
                      _ProjectToolItem(
                        title: 'Debugger',
                        description: 'Logs, breakpoints, and debug sessions',
                        icon: Icons.bug_report_outlined,
                      ),
                    ],
                    onSelected: onSelected,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectToolGroup extends StatelessWidget {
  const _ProjectToolGroup({
    required this.label,
    required this.items,
    required this.onSelected,
  });
  final String label;
  final List<_ProjectToolItem> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: AppRadii.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _ProjectToolTile(item: items[index], onSelected: onSelected),
                if (index != items.length - 1) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _ProjectToolTile extends StatelessWidget {
  const _ProjectToolTile({required this.item, required this.onSelected});

  final _ProjectToolItem item;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.inputBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onSelected(item.title);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: ShapeDecoration(
                  color: item.available
                      ? colors.tertiaryContainer
                      : colors.surfaceContainerHighest,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  item.available ? 'Ready' : 'Planned',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: item.available
                        ? colors.onTertiaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectToolItem {
  const _ProjectToolItem({
    required this.title,
    required this.description,
    required this.icon,
    this.available = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool available;
}

class _EditorEventTarget {
  const _EditorEventTarget(this.widgetId, this.eventName, this.label);
  final String widgetId;
  final String eventName;
  final String label;
  String get key => '$widgetId::$eventName';
}

class _LogicPrototype extends StatefulWidget {
  const _LogicPrototype({required this.project, required this.requestedTarget});

  final ProjectSummary project;
  final ValueNotifier<_EditorEventTarget?> requestedTarget;

  @override
  State<_LogicPrototype> createState() => _LogicPrototypeState();
}

class _LogicPrototypeState extends State<_LogicPrototype> {
  final _repository = const ProjectRepository();
  int _step = 1;
  bool _loading = true;
  Map<String, Object?> _logic = const {
    'schemaVersion': 1,
    'variables': <Object?>[],
    'events': <Object?>[],
  };
  List<_EditorEventTarget> _targets = const [];
  List<PageDesign> _pages = const [];
  String _targetWidgetId = 'counter_fab';
  String _targetEvent = 'onPressed';

  @override
  void initState() {
    super.initState();
    widget.requestedTarget.addListener(_useRequestedTarget);
    _load();
  }

  @override
  void dispose() {
    widget.requestedTarget.removeListener(_useRequestedTarget);
    super.dispose();
  }

  void _useRequestedTarget() {
    final target = widget.requestedTarget.value;
    if (target == null || !mounted) return;
    setState(() {
      _targetWidgetId = target.widgetId;
      _targetEvent = target.eventName;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        _repository.readDesign(
          id: widget.project.id,
          projectName: widget.project.name,
        ),
        _repository.readLogic(widget.project.id),
      ]);
      final design = results[0] as ScreenDesign;
      final logic = jsonDecode(results[1] as String) as Map<String, Object?>;
      final targets = <_EditorEventTarget>[];
      void collect(WidgetNode node, String pageName) {
        final definition = WidgetCatalog.byType(node.type);
        for (final event in definition.events) {
          targets.add(
            _EditorEventTarget(
              node.id,
              event.name,
              '$pageName · ${node.properties['text'] ?? node.properties['label'] ?? definition.label} · ${event.label}',
            ),
          );
        }
        for (final child in node.children) {
          collect(child, pageName);
        }
      }

      for (final page in design.pages) {
        if (page.floatingActionButton.enabled) {
          targets.add(
            _EditorEventTarget(
              '${page.floatingActionButton.properties['id'] ?? '${page.id}_fab'}',
              'onPressed',
              '${page.name} · Floating button · On tap',
            ),
          );
        }
        collect(page.body, page.name);
      }
      final events = logic['events']! as List<Object?>;
      final counterEvent = events
          .whereType<Map<String, Object?>>()
          .where((event) => event['widgetId'] == 'counter_fab')
          .firstOrNull;
      final counterBlocks = counterEvent?['blocks'] as List<Object?>?;
      final counterBlock = counterBlocks
          ?.whereType<Map<String, Object?>>()
          .firstOrNull;
      final expression = counterBlock?['value'] as Map<String, Object?>?;
      final right = expression?['right'] as Map<String, Object?>?;
      if (mounted) {
        setState(() {
          _logic = logic;
          _targets = targets;
          _pages = design.pages;
          final requested = widget.requestedTarget.value;
          if (requested != null &&
              targets.any((target) => target.key == requested.key)) {
            _targetWidgetId = requested.widgetId;
            _targetEvent = requested.eventName;
          } else if (!targets.any(
            (target) => target.key == '$_targetWidgetId::$_targetEvent',
          )) {
            _targetWidgetId = targets.firstOrNull?.widgetId ?? 'counter_fab';
            _targetEvent = targets.firstOrNull?.eventName ?? 'onPressed';
          }
          _step = (right?['value'] as num?)?.toInt() ?? 1;
        });
      }
    } catch (_) {
      // The native bridge is unavailable in widget tests and old projects
      // are repaired by the build service before compilation.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final blocks = _blocksForTarget();
    final targetLabel = _targets
        .where((target) => target.key == '$_targetWidgetId::$_targetEvent')
        .firstOrNull
        ?.label;

    return Stack(
      children: [
        InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(500),
          minScale: 0.4,
          maxScale: 2.4,
          child: SizedBox(
            width: 900,
            height: 1000,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(42, 48, 0, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_targets.isNotEmpty)
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('$_targetWidgetId::$_targetEvent'),
                          initialValue: '$_targetWidgetId::$_targetEvent',
                          decoration: const InputDecoration(
                            labelText: 'Widget event',
                          ),
                          items: _targets
                              .map(
                                (target) => DropdownMenuItem(
                                  value: target.key,
                                  child: Text(target.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              final target = _targets.firstWhere(
                                (item) => item.key == value,
                              );
                              setState(() {
                                _targetWidgetId = target.widgetId;
                                _targetEvent = target.eventName;
                              });
                            }
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    _LogicBlock(
                      color: colors.primary,
                      label: 'When ${targetLabel ?? 'widget event'}',
                    ),
                    if (blocks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 4),
                        child: Text(
                          'Drop or add a block here',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    else
                      ...blocks.map(
                        (block) => Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _LogicBlock(
                            color: colors.tertiary,
                            label: _blockLabel(block),
                            onTap: () => _editBlock(block),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'block_palette',
            onPressed: _showBlockPalette,
            child: const Icon(Icons.category_rounded),
          ),
        ),
        if (_loading)
          const Positioned(
            top: 16,
            right: 16,
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  List<Map<String, Object?>> _blocksForTarget() {
    final events = _logic['events'] as List<Object?>? ?? const [];
    final event = events
        .whereType<Map<String, Object?>>()
        .where(
          (item) =>
              item['widgetId'] == _targetWidgetId &&
              item['event'] == _targetEvent,
        )
        .firstOrNull;
    return (event?['blocks'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  String _blockLabel(Map<String, Object?> block) => switch (block['type']) {
    'setVariable' => 'Change counter by $_step',
    'showSnackBar' => 'Show SnackBar “${block['message']}”',
    'delay' => 'Wait ${block['milliseconds']} ms',
    'customAction' => 'Call custom action “${block['name']}”',
    'navigate' => 'Open page ${block['route']}',
    _ => '${block['type']}',
  };

  Future<void> _showBlockPalette() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Change counter'),
                onTap: () => Navigator.pop(context, 'setVariable'),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Show SnackBar'),
                onTap: () => Navigator.pop(context, 'showSnackBar'),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Wait'),
                onTap: () => Navigator.pop(context, 'delay'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open another page'),
                onTap: () => Navigator.pop(context, 'navigate'),
              ),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('Call custom action'),
                onTap: () => Navigator.pop(context, 'customAction'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || type == null) return;
    final block = <String, Object?>{'type': type};
    if (type == 'setVariable') {
      block.addAll({
        'variableId': 'counter',
        'value': {
          'type': 'binary',
          'operator': '+',
          'left': {'type': 'variable', 'id': 'counter'},
          'right': {'type': 'integer', 'value': 1},
        },
      });
    } else if (type == 'showSnackBar') {
      block['message'] = 'Hello from Flutterware';
    } else if (type == 'delay') {
      block['milliseconds'] = 500;
    } else if (type == 'navigate') {
      if (_pages.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create another page in Design first')),
        );
        return;
      }
      final route = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: _pages
                .map(
                  (page) => ListTile(
                    leading: const Icon(Icons.web_asset_outlined),
                    title: Text(page.name),
                    subtitle: Text(page.route),
                    onTap: () => Navigator.pop(context, page.route),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
      if (!mounted || route == null) return;
      block['route'] = route;
    } else {
      block['name'] = 'action';
    }
    await _appendBlock(block);
  }

  Future<void> _appendBlock(Map<String, Object?> block) async {
    final logic = jsonDecode(jsonEncode(_logic)) as Map<String, Object?>;
    final events = logic['events']! as List<Object?>;
    var event = events
        .whereType<Map<String, Object?>>()
        .where(
          (item) =>
              item['widgetId'] == _targetWidgetId &&
              item['event'] == _targetEvent,
        )
        .firstOrNull;
    if (event == null) {
      event = <String, Object?>{
        'id': '${_targetWidgetId}_${_targetEvent.toLowerCase()}',
        'widgetId': _targetWidgetId,
        'event': _targetEvent,
        'blocks': <Object?>[],
      };
      events.add(event);
    }
    (event['blocks']! as List<Object?>).add(block);
    await _saveLogic(logic);
  }

  Future<void> _editBlock(Map<String, Object?> block) async {
    if (block['type'] == 'setVariable') {
      await _editCounterStep();
      await _load();
      return;
    }
    final key = block['type'] == 'showSnackBar'
        ? 'message'
        : block['type'] == 'delay'
        ? 'milliseconds'
        : block['type'] == 'navigate'
        ? 'route'
        : 'name';
    final controller = TextEditingController(text: '${block[key] ?? ''}');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_blockLabel(block)),
        content: AppTextField(
          controller: controller,
          label: key,
          autofocus: true,
          keyboardType: key == 'milliseconds' ? TextInputType.number : null,
        ),
        actions: [
          AppButton(
            label: 'Delete',
            expanded: false,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, '__delete__'),
          ),
          AppButton(
            label: 'Save',
            expanded: false,
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      ),
    );
    if (!mounted || value == null) return;
    final logic = jsonDecode(jsonEncode(_logic)) as Map<String, Object?>;
    final events = logic['events']! as List<Object?>;
    final event = events.whereType<Map<String, Object?>>().firstWhere(
      (item) =>
          item['widgetId'] == _targetWidgetId && item['event'] == _targetEvent,
    );
    final blocks = event['blocks']! as List<Object?>;
    final index = _blocksForTarget().indexOf(block);
    if (value == '__delete__') {
      blocks.removeAt(index);
    } else {
      final updated = Map<String, Object?>.from(block);
      updated[key] = key == 'milliseconds' ? int.tryParse(value) ?? 500 : value;
      blocks[index] = updated;
    }
    await _saveLogic(logic);
  }

  Future<void> _saveLogic(Map<String, Object?> logic) async {
    setState(() => _loading = true);
    try {
      await _repository.writeLogic(
        id: widget.project.id,
        content: const JsonEncoder.withIndent('  ').convert(logic),
      );
      if (mounted) setState(() => _logic = logic);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not save logic')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCounterStep() async {
    final controller = TextEditingController(text: '$_step');
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Counter logic block',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: controller,
                label: 'Change counter by',
                helper: 'Use a value from -100 to 100, except zero',
                prefixIcon: Icons.calculate_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}')),
                ],
                autofocus: true,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Save block',
                trailingIcon: Icons.check_rounded,
                onPressed: () {
                  final step = int.tryParse(controller.text);
                  if (step == null || step == 0 || step < -100 || step > 100) {
                    return;
                  }
                  Navigator.pop(context, step);
                },
              ),
            ],
          ),
        ),
      ),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      ),
    );
    if (!mounted || value == null || value == _step) return;
    try {
      await _repository.updateCounterStep(id: widget.project.id, step: value);
      if (!mounted) return;
      setState(() => _step = value);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Counter logic updated')));
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save logic block')),
      );
    }
  }
}

class _LogicBlock extends StatelessWidget {
  const _LogicBlock({required this.color, required this.label, this.onTap});

  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class CustomWidgetsEditor extends StatefulWidget {
  const CustomWidgetsEditor({super.key, required this.project});

  final ProjectSummary project;

  @override
  State<CustomWidgetsEditor> createState() => _CustomWidgetsEditorState();
}

class _CustomWidgetsEditorState extends State<CustomWidgetsEditor> {
  final _repository = const ProjectRepository();
  List<CustomWidgetDefinition> _widgets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final widgets = await _repository.listCustomWidgets(widget.project.id);
      if (!mounted) return;
      setState(() {
        _widgets = widgets;
        _loading = false;
        _error = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message ?? error.code;
      });
    }
  }

  Future<void> _create() async {
    final created = await showCustomWidgetCreator(
      context,
      project: widget.project,
    );
    if (created != null) await _load();
  }

  Future<void> _register() async {
    final files = await _repository.listFiles(widget.project.id);
    if (!mounted) return;
    final choices = files
        .where(
          (file) =>
              !file.directory &&
              file.editable &&
              file.path.startsWith('lib/') &&
              file.path.endsWith('.dart'),
        )
        .toList(growable: false);
    final selected = await showModalBottomSheet<ProjectFile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_link_rounded),
              title: const Text('Register an existing Dart widget'),
              subtitle: const Text('Choose a user-owned file inside lib/'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: choices.isEmpty
                  ? const Center(child: Text('No editable Dart files found'))
                  : ListView.builder(
                      itemCount: choices.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(Icons.flutter_dash_rounded),
                        title: Text(choices[index].name),
                        subtitle: Text(choices[index].path),
                        onTap: () => Navigator.pop(context, choices[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final registered = await showCustomWidgetCreator(
      context,
      project: widget.project,
      existingPath: selected.path,
    );
    if (registered != null) await _load();
  }

  Future<void> _edit(CustomWidgetDefinition widget) async {
    final file = ProjectFile(
      path: widget.path,
      name: widget.path.split('/').last,
      directory: false,
      generated: false,
      editable: true,
      openable: true,
      size: 0,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _CodeEditorPage(project: this.widget.project, file: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: AppButton(
          label: 'Try loading widgets again',
          expanded: false,
          leadingIcon: Icons.refresh_rounded,
          onPressed: _load,
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.widgets_outlined, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    'Reusable custom UI',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Create a real StatelessWidget, define its variables, edit its Dart code, then assign it to any app page.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Create',
                          leadingIcon: Icons.add_rounded,
                          onPressed: _create,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Register',
                          variant: AppButtonVariant.secondary,
                          leadingIcon: Icons.add_link_rounded,
                          onPressed: _register,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_widgets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.dashboard_customize_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('No reusable widgets yet'),
                  ],
                ),
              )
            else
              for (final item in _widgets)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(item.className[0])),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.className} • ${item.parameters.length} variable${item.parameters.length == 1 ? '' : 's'}\n${item.path}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.code_rounded),
                    onTap: () => _edit(item),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CustomWidgetDraft {
  const _CustomWidgetDraft({
    required this.name,
    required this.className,
    required this.directory,
    required this.parameters,
  });

  final String name;
  final String className;
  final String directory;
  final List<CustomWidgetParameter> parameters;
}

Future<CustomWidgetDefinition?> showCustomWidgetCreator(
  BuildContext context, {
  required ProjectSummary project,
  String? existingPath,
}) async {
  final basename = existingPath?.split('/').last.replaceAll('.dart', '') ?? '';
  final suggestedClass = _pascalClassName(basename);
  var lastClassSuggestion = suggestedClass;
  final nameController = TextEditingController(text: suggestedClass);
  final classController = TextEditingController(text: suggestedClass);
  final directoryController = TextEditingController(
    text: existingPath?.contains('/') == true
        ? existingPath!.substring(0, existingPath.lastIndexOf('/'))
        : 'lib/custom/widgets',
  );
  final parametersController = TextEditingController();
  String? formError;
  final draft = await showModalBottomSheet<_CustomWidgetDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existingPath == null
                  ? 'Create reusable widget'
                  : 'Register widget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              existingPath ??
                  'The Dart file can live in any user-owned directory under lib/.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: nameController,
              label: 'Display name',
              prefixIcon: Icons.label_outline_rounded,
              autofocus: true,
              onChanged: (value) {
                final next = _pascalClassName(value);
                if (classController.text.isEmpty ||
                    classController.text == lastClassSuggestion) {
                  classController.text = next;
                }
                lastClassSuggestion = next;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: classController,
              label: 'Dart class name',
              helper: 'Example: StoryWidget',
              prefixIcon: Icons.data_object_rounded,
            ),
            if (existingPath == null) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: directoryController,
                label: 'Directory',
                helper: 'Example: lib/features/stories/widgets',
                prefixIcon: Icons.folder_outlined,
              ),
            ],
            const SizedBox(height: 12),
            AppTextField(
              controller: parametersController,
              label: 'Variables',
              helper: 'title:String=Story, count:int=0, featured:bool=false',
              prefixIcon: Icons.tune_rounded,
              autocorrect: false,
            ),
            if (formError != null) ...[
              const SizedBox(height: 10),
              Text(
                formError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              label: existingPath == null
                  ? 'Create and open'
                  : 'Register widget',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () {
                try {
                  final name = nameController.text.trim();
                  final className = classController.text.trim();
                  final directory = directoryController.text.trim().replaceAll(
                    RegExp(r'/+$'),
                    '',
                  );
                  if (name.isEmpty) {
                    throw const FormatException('Enter a display name');
                  }
                  if (!RegExp(
                    r'^[A-Za-z_][A-Za-z0-9_]*$',
                  ).hasMatch(className)) {
                    throw const FormatException(
                      'Enter a valid Dart class name',
                    );
                  }
                  Navigator.pop(
                    context,
                    _CustomWidgetDraft(
                      name: name,
                      className: className,
                      directory: directory,
                      parameters: _parseCustomWidgetParameters(
                        parametersController.text,
                      ),
                    ),
                  );
                } on FormatException catch (error) {
                  setSheetState(() => formError = error.message);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
  for (final controller in [
    nameController,
    classController,
    directoryController,
    parametersController,
  ]) {
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      ),
    );
  }
  if (draft == null || !context.mounted) return null;
  var id = draft.className
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9_]+'), '_');
  if (id.length < 3) id = '${id}_widget';
  final path = existingPath ?? '${draft.directory}/$id.dart';
  final definition = CustomWidgetDefinition(
    id: id,
    name: draft.name,
    className: draft.className,
    path: path,
    parameters: draft.parameters,
    arguments: {
      for (final parameter in draft.parameters)
        parameter.name: parameter.defaultValue,
    },
  );
  try {
    return await const ProjectRepository().createCustomWidget(
      projectId: project.id,
      widget: definition,
      createFile: existingPath == null,
    );
  } on PlatformException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not save custom widget'),
        ),
      );
    }
    return null;
  }
}

List<CustomWidgetParameter> _parseCustomWidgetParameters(String source) {
  if (source.trim().isEmpty) return const [];
  final result = <CustomWidgetParameter>[];
  final names = <String>{};
  for (final raw in source.split(',')) {
    final parts = raw.trim().split('=');
    final declaration = parts.first.trim().split(':');
    final name = declaration.first.trim();
    final type = declaration.length > 1 ? declaration[1].trim() : 'String';
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
      throw FormatException('Invalid variable name: $name');
    }
    if (!{'String', 'int', 'double', 'bool', 'dynamic'}.contains(type)) {
      throw FormatException('Unsupported type for $name');
    }
    if (!names.add(name)) throw FormatException('Duplicate variable: $name');
    result.add(
      CustomWidgetParameter(
        name: name,
        type: type,
        defaultValue: parts.length > 1 ? parts.sublist(1).join('=').trim() : '',
      ),
    );
  }
  return result;
}

String _pascalClassName(String value) => value
    .split(RegExp('[^A-Za-z0-9]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join();

class ProjectFilesView extends StatefulWidget {
  const ProjectFilesView({super.key, required this.project});

  final ProjectSummary project;

  @override
  State<ProjectFilesView> createState() => _ProjectFilesViewState();
}

class _ProjectFilesViewState extends State<ProjectFilesView> {
  final _repository = const ProjectRepository();
  List<ProjectFile> _files = const [];
  String _directory = '';
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files = await _repository.listFiles(widget.project.id);
      if (!mounted) return;
      setState(() {
        _files = files;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 42),
              const SizedBox(height: 12),
              const Text('Could not load project files'),
              const SizedBox(height: 12),
              AppButton(
                label: 'Try again',
                expanded: false,
                variant: AppButtonVariant.outlined,
                leadingIcon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    final entries =
        _files
            .where((file) => file.parentPath == _directory)
            .toList(growable: false)
          ..sort((a, b) {
            if (a.directory != b.directory) return a.directory ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          _FileBreadcrumbs(
            path: _directory,
            onNavigate: (path) => setState(() => _directory = path),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: entries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.folder_open_rounded, size: 48),
                        SizedBox(height: 12),
                        Center(child: Text('This folder is empty')),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final file = entries[index];
                        return _FileRow(
                          file: file,
                          childCount: file.directory
                              ? _files
                                    .where(
                                      (child) => child.parentPath == file.path,
                                    )
                                    .length
                              : 0,
                          onTap: file.directory
                              ? () => setState(() => _directory = file.path)
                              : file.openable
                              ? () => _open(file)
                              : () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Binary files cannot be opened in the code editor yet',
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(ProjectFile file) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CodeEditorPage(project: widget.project, file: file),
      ),
    );
    await _load();
  }
}

class _FileBreadcrumbs extends StatelessWidget {
  const _FileBreadcrumbs({required this.path, required this.onNavigate});

  final String path;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final parts = path.isEmpty ? const <String>[] : path.split('/');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: AppRadii.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Parent folder',
                onPressed: path.isEmpty
                    ? null
                    : () => onNavigate(
                        path.contains('/')
                            ? path.substring(0, path.lastIndexOf('/'))
                            : '',
                      ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => onNavigate(''),
                        icon: const Icon(
                          Icons.folder_special_outlined,
                          size: 19,
                        ),
                        label: const Text('Project'),
                      ),
                      for (var index = 0; index < parts.length; index++) ...[
                        const Icon(Icons.chevron_right_rounded, size: 18),
                        TextButton(
                          onPressed: () =>
                              onNavigate(parts.take(index + 1).join('/')),
                          child: Text(parts[index]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.childCount,
    required this.onTap,
  });

  final ProjectFile file;
  final int childCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(
        file.directory ? Icons.folder_rounded : _iconFor(file.name),
        color: file.directory
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(file.name),
      subtitle: file.directory
          ? Text('$childCount item${childCount == 1 ? '' : 's'}')
          : file.generated
          ? const Text('Generated • read-only')
          : file.editable
          ? const Text('Editable')
          : Text(
              file.openable
                  ? _fileSize(file.size)
                  : 'Binary • ${_fileSize(file.size)}',
            ),
      trailing: file.directory
          ? const Icon(Icons.chevron_right_rounded)
          : Icon(
              file.editable ? Icons.edit_outlined : Icons.visibility_outlined,
            ),
      onTap: onTap,
    );
  }

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.dart')) return Icons.flutter_dash_rounded;
    if (lower.endsWith('.kt') || lower.endsWith('.java')) {
      return Icons.android_rounded;
    }
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
      return Icons.data_object_rounded;
    }
    if (lower.endsWith('.json')) return Icons.account_tree_outlined;
    if (lower.endsWith('.xml')) return Icons.code_rounded;
    if (lower.endsWith('.md')) return Icons.description_outlined;
    if (lower.endsWith('.png') || lower.endsWith('.jpg')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _CodeEditorPage extends StatefulWidget {
  const _CodeEditorPage({required this.project, required this.file});

  final ProjectSummary project;
  final ProjectFile file;

  @override
  State<_CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends State<_CodeEditorPage> {
  final _repository = const ProjectRepository();
  late final CodeLanguage _language = CodeLanguage.fromPath(widget.file.path);
  late final SyntaxTextEditingController _controller =
      SyntaxTextEditingController(language: _language);
  bool _loading = true;
  bool _saving = false;
  bool _editable = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _load();
  }

  void _changed() {
    if (!_loading && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    try {
      final result = await _repository.readFile(
        id: widget.project.id,
        path: widget.file.path,
      );
      if (!mounted) return;
      _controller.text = result.content;
      setState(() {
        _editable = result.editable;
        _loading = false;
        _dirty = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message ?? error.code;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.file.name),
            Text(
              _editable
                  ? '${_language.label} • Editable'
                  : '${_language.label} • Generated preview • read-only',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : AppCodeEditor(controller: _controller, readOnly: !_editable),
      bottomNavigationBar: !_editable || _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AppButton(
                  label: _saving
                      ? 'Saving…'
                      : _dirty
                      ? 'Save changes'
                      : 'Saved',
                  busy: _saving,
                  trailingIcon: Icons.save_outlined,
                  onPressed: _dirty && !_saving ? _save : null,
                ),
              ),
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.writeFile(
        id: widget.project.id,
        path: widget.file.path,
        content: _controller.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File saved')));
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save file')),
      );
    }
  }
}

class _EditorBottomBar extends StatefulWidget {
  const _EditorBottomBar({
    required this.project,
    required this.visualController,
  });

  final ProjectSummary project;
  final VisualEditorController visualController;

  @override
  State<_EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<_EditorBottomBar> {
  final _runtime = RuntimeController.instance;
  final _repository = const ProjectRepository();
  bool _sheetOpen = false;
  bool _pagesSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _runtime.addListener(_changed);
    widget.visualController.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _runtime.removeListener(_changed);
    widget.visualController.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final runtime = _runtime.snapshot;
    final belongsToProject = runtime.projectId == widget.project.id;
    final showProgress = belongsToProject && runtime.phase != 'idle';
    final activePage = widget.visualController.activePage;

    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Material(
            color: colors.surfaceContainerLow,
            borderRadius: AppRadii.cardBorder,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showProgress)
                  InkWell(
                    onTap: () => _openBuildSheet(startBuild: false),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                runtime.phase == 'failed'
                                    ? Icons.error_outline_rounded
                                    : runtime.completed
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.build_circle_outlined,
                                size: 20,
                                color: runtime.phase == 'failed'
                                    ? colors.error
                                    : colors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  runtime.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              Text(
                                '${(runtime.progress * 100).round()}%',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_less_rounded, size: 20),
                            ],
                          ),
                          const SizedBox(height: 7),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: runtime.progress),
                            duration: const Duration(milliseconds: 480),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  value: runtime.progress == 0 && runtime.busy
                                      ? null
                                      : value,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _openPagesSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.layers_outlined, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activePage?.name ?? 'Pages',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                      Text(
                                        'main.dart • ${widget.visualController.pages.length} page${widget.visualController.pages.length == 1 ? '' : 's'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.expand_more_rounded,
                                  color: colors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        label: runtime.busy ? 'Stop' : 'Run',
                        expanded: false,
                        variant: runtime.busy
                            ? AppButtonVariant.danger
                            : AppButtonVariant.primary,
                        leadingIcon: runtime.busy
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        onPressed: runtime.busy
                            ? _runtime.cancelBuild
                            : () => _openBuildSheet(startBuild: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBuildSheet({required bool startBuild}) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    if (startBuild) await widget.visualController.flush();
    if (!mounted) {
      _sheetOpen = false;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          RuntimeBuildSheet(project: widget.project, startBuild: startBuild),
    );
    _sheetOpen = false;
  }

  Future<void> _openPagesSheet() async {
    if (_pagesSheetOpen) return;
    _pagesSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.visualController,
        builder: (context, _) {
          final pages = widget.visualController.pages;
          final activeId = widget.visualController.activePageId;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App pages',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Select a page to edit or create a new one',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Create page',
                      onPressed: widget.visualController.createPage,
                      icon: const Icon(Icons.add_box_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 230,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return _PagePreviewCard(
                        page: page,
                        selected: page.id == activeId,
                        onCustomUi: () => _configurePageUi(page),
                        onTap: () {
                          widget.visualController.selectPage(page.id);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Create new page',
                  trailingIcon: Icons.add_rounded,
                  onPressed: widget.visualController.createPage,
                ),
              ],
            ),
          );
        },
      ),
    );
    _pagesSheetOpen = false;
  }

  Future<void> _configurePageUi(PageDesign page) async {
    final widgets = await _repository.listCustomWidgets(widget.project.id);
    if (!mounted) return;
    final choice = await showModalBottomSheet<_PageUiChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UI for ${page.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Use the visual canvas or render one reusable custom widget as this page body.',
            ),
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(Icons.phone_android_rounded),
              title: const Text('Visual editor layout'),
              subtitle: const Text(
                'Use the widgets arranged in the Design tab',
              ),
              trailing: page.customUi == null
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => Navigator.pop(context, const _PageUiChoice.visual()),
            ),
            for (final item in widgets)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.widgets_outlined),
                title: Text(item.name),
                subtitle: Text('${item.className} • ${item.path}'),
                trailing: page.customUi?.id == item.id
                    ? const Icon(Icons.check_circle_rounded)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, _PageUiChoice.widget(item)),
              ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Create a new custom widget',
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.add_rounded,
              onPressed: () =>
                  Navigator.pop(context, const _PageUiChoice.create()),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.visual) {
      widget.visualController.assignCustomUi(page.id, null);
      return;
    }
    var selected = choice.widget;
    if (choice.create) {
      selected = await showCustomWidgetCreator(
        context,
        project: widget.project,
      );
    }
    if (!mounted || selected == null) return;
    final configured = await _configureArguments(selected);
    if (configured != null) {
      widget.visualController.assignCustomUi(page.id, configured);
    }
  }

  Future<CustomWidgetDefinition?> _configureArguments(
    CustomWidgetDefinition widget,
  ) async {
    if (widget.parameters.isEmpty) return widget;
    final controllers = {
      for (final parameter in widget.parameters)
        parameter.name: TextEditingController(
          text: widget.arguments[parameter.name] ?? parameter.defaultValue,
        ),
    };
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.name} variables',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.className,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final parameter in widget.parameters) ...[
              AppTextField(
                controller: controllers[parameter.name]!,
                label: '${parameter.name} (${parameter.type})',
                prefixIcon: Icons.input_rounded,
                autocorrect: parameter.type == 'String',
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: 'Assign to page',
              trailingIcon: Icons.check_rounded,
              onPressed: () => Navigator.pop(
                context,
                controllers.map((key, value) => MapEntry(key, value.text)),
              ),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controllers.values) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          controller.dispose,
        ),
      );
    }
    return result == null ? null : widget.copyWith(arguments: result);
  }
}

class _PageUiChoice {
  const _PageUiChoice.visual() : visual = true, create = false, widget = null;
  const _PageUiChoice.create() : visual = false, create = true, widget = null;
  const _PageUiChoice.widget(this.widget) : visual = false, create = false;

  final bool visual;
  final bool create;
  final CustomWidgetDefinition? widget;
}

class _PagePreviewCard extends StatelessWidget {
  const _PagePreviewCard({
    required this.page,
    required this.selected,
    required this.onTap,
    required this.onCustomUi,
  });

  final PageDesign page;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCustomUi;

  int get _widgetCount {
    var count = 0;
    void visit(WidgetNode node) {
      count++;
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(page.body);
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 146,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          height: 8,
                          color: colors.surfaceContainerHighest,
                        ),
                        if (page.appBar.enabled)
                          Container(
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            alignment: Alignment.centerLeft,
                            color: colors.surfaceContainer,
                            child: Container(
                              width: 54,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: .45,
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        Expanded(
                          child: page.customUi != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.widgets_outlined,
                                          size: 25,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          page.customUi!.className,
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: List.generate(
                                      _widgetCount.clamp(1, 4),
                                      (index) => Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: index == 0
                                                ? colors.primaryContainer
                                                : colors.surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        page.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    InkResponse(
                      onTap: onCustomUi,
                      radius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          page.customUi == null
                              ? Icons.dashboard_customize_outlined
                              : Icons.widgets_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                  ],
                ),
                Text(
                  page.route,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
