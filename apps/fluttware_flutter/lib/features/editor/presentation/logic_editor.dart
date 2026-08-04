import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/widgets/app_button.dart';
import '../../../ui/widgets/app_code_editor.dart';
import '../../../ui/widgets/app_text_field.dart';
import '../../../ui/theme/app_tokens.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_summary.dart';
import '../domain/editor_models.dart';
import '../domain/logic_models.dart';

class LogicEditor extends StatefulWidget {
  const LogicEditor({
    super.key,
    required this.project,
    required this.requestedTarget,
    this.designRevision,
  });

  final ProjectSummary project;
  final ValueNotifier<LogicEventRequest?> requestedTarget;
  final ValueListenable<int>? designRevision;

  @override
  State<LogicEditor> createState() => _LogicEditorState();
}

class _LogicEditorState extends State<LogicEditor> {
  final _repository = const ProjectRepository();
  ScreenDesign? _design;
  Map<String, Object?> _logic = _emptyLogic();
  List<_LogicTarget> _targets = const [];
  String? _pageId;
  String? _targetKey;
  bool _loading = true;
  bool _saving = false;

  static Map<String, Object?> _emptyLogic() => {
    'schemaVersion': 1,
    'variables': <Object?>[],
    'events': <Object?>[],
    'customBlocks': <Object?>[],
  };

  @override
  void initState() {
    super.initState();
    widget.requestedTarget.addListener(_useRequestedTarget);
    widget.designRevision?.addListener(_reloadAfterDesignChange);
    _load();
  }

  @override
  void didUpdateWidget(covariant LogicEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestedTarget != widget.requestedTarget) {
      oldWidget.requestedTarget.removeListener(_useRequestedTarget);
      widget.requestedTarget.addListener(_useRequestedTarget);
    }
    if (oldWidget.designRevision != widget.designRevision) {
      oldWidget.designRevision?.removeListener(_reloadAfterDesignChange);
      widget.designRevision?.addListener(_reloadAfterDesignChange);
    }
  }

  @override
  void dispose() {
    widget.requestedTarget.removeListener(_useRequestedTarget);
    widget.designRevision?.removeListener(_reloadAfterDesignChange);
    super.dispose();
  }

  void _reloadAfterDesignChange() => _load();

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
      logic.putIfAbsent('variables', () => <Object?>[]);
      logic.putIfAbsent('events', () => <Object?>[]);
      logic.putIfAbsent('customBlocks', () => <Object?>[]);
      final targets = _collectTargets(design);
      final requested = widget.requestedTarget.value;
      final requestedTarget = requested == null
          ? null
          : targets.where((target) => target.key == requested.key).firstOrNull;
      if (!mounted) return;
      setState(() {
        _design = design;
        _logic = logic;
        _targets = targets;
        _pageId = requestedTarget?.pageId ?? _pageId ?? design.initialPageId;
        final pageTargets = targets.where((target) => target.pageId == _pageId);
        _targetKey =
            requestedTarget?.key ??
            (pageTargets.any((target) => target.key == _targetKey)
                ? _targetKey
                : pageTargets.firstOrNull?.key);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_LogicTarget> _collectTargets(ScreenDesign design) {
    final result = <_LogicTarget>[];
    for (final page in design.pages) {
      result.add(
        _LogicTarget(
          pageId: page.id,
          widgetId: '${page.id}_page',
          eventName: 'onInit',
          label: 'When ${page.name} starts',
          icon: Icons.rocket_launch_outlined,
        ),
      );
      if (page.floatingActionButton.enabled) {
        result.add(
          _LogicTarget(
            pageId: page.id,
            widgetId:
                '${page.floatingActionButton.properties['id'] ?? '${page.id}_fab'}',
            eventName: 'onPressed',
            label: 'Floating button · On tap',
            icon: Icons.touch_app_outlined,
          ),
        );
      }
      void collect(WidgetNode node) {
        final definition = WidgetCatalog.byType(node.type);
        for (final event in definition.events) {
          result.add(
            _LogicTarget(
              pageId: page.id,
              widgetId: node.id,
              eventName: event.name,
              label:
                  '${node.properties['text'] ?? node.properties['label'] ?? definition.label} · ${event.label}',
              icon: Icons.bolt_rounded,
            ),
          );
        }
        for (final child in node.children) {
          collect(child);
        }
      }

      collect(page.body);
    }
    return result;
  }

  void _useRequestedTarget() {
    final requested = widget.requestedTarget.value;
    if (requested == null || !mounted) return;
    final target = _targets
        .where((item) => item.key == requested.key)
        .firstOrNull;
    if (target == null) return;
    setState(() {
      _pageId = target.pageId;
      _targetKey = target.key;
    });
  }

  PageDesign? get _page =>
      _design?.pages.where((page) => page.id == _pageId).firstOrNull;

  _LogicTarget? get _target =>
      _targets.where((target) => target.key == _targetKey).firstOrNull;

  List<Map<String, Object?>> get _blocks {
    final target = _target;
    if (target == null) return const [];
    final event = (_logic['events'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .where(
          (item) =>
              item['widgetId'] == target.widgetId &&
              item['event'] == target.eventName,
        )
        .firstOrNull;
    return (event?['blocks'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final design = _design;
    if (design == null) {
      return const Center(child: Text('Could not load the logic model'));
    }
    final pageTargets = _targets
        .where((target) => target.pageId == _pageId)
        .toList();
    final blocks = _blocks;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          _ControllerHeader(
            design: design,
            pageId: _pageId ?? design.initialPageId,
            targetKey: _targetKey,
            targets: pageTargets,
            saving: _saving,
            onPageChanged: (id) {
              final targets = _targets
                  .where((target) => target.pageId == id)
                  .toList();
              setState(() {
                _pageId = id;
                _targetKey = targets.firstOrNull?.key;
              });
            },
            onTargetChanged: (key) => setState(() => _targetKey = key),
            onVariables: _showVariables,
            onCustomBlocks: _showCustomBlocks,
          ),
          Expanded(
            child: DragTarget<Map<String, Object?>>(
              onAcceptWithDetails: (details) => _appendBlock(details.data),
              builder: (context, candidates, rejected) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: candidates.isEmpty
                    ? Theme.of(context).colorScheme.surfaceContainerLowest
                    : Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: .35),
                child: blocks.isEmpty
                    ? _EmptyLogicCanvas(
                        target: _target,
                        onAdd: _showBlockPalette,
                      )
                    : _BlockWorkspace(
                        target: _target!,
                        blocks: blocks,
                        customBlocks: _customBlocks,
                        onReorder: _reorderBlocks,
                        onEdit: _editBlock,
                        onDelete: _deleteBlock,
                        onDuplicate: _duplicateBlock,
                      ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                label: 'Action blocks',
                leadingIcon: Icons.category_outlined,
                trailingIcon: Icons.keyboard_arrow_up_rounded,
                onPressed: _target == null ? null : _showBlockPalette,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, Object?>> get _customBlocks =>
      (_logic['customBlocks'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .toList(growable: false);

  Map<String, Object?> _editableLogic() =>
      jsonDecode(jsonEncode(_logic)) as Map<String, Object?>;

  Map<String, Object?> _eventFor(
    Map<String, Object?> logic,
    _LogicTarget target,
  ) {
    final events = logic['events']! as List<Object?>;
    var event = events
        .whereType<Map<String, Object?>>()
        .where(
          (item) =>
              item['widgetId'] == target.widgetId &&
              item['event'] == target.eventName,
        )
        .firstOrNull;
    if (event == null) {
      event = <String, Object?>{
        'id': '${target.widgetId}_${target.eventName.toLowerCase()}',
        'pageId': target.pageId,
        'widgetId': target.widgetId,
        'event': target.eventName,
        'blocks': <Object?>[],
      };
      events.add(event);
    }
    return event;
  }

  Future<void> _appendBlock(Map<String, Object?> block) async {
    final target = _target;
    if (target == null) return;
    final logic = _editableLogic();
    final event = _eventFor(logic, target);
    (event['blocks']! as List<Object?>).add(block);
    await _save(logic);
  }

  Future<void> _reorderBlocks(int oldIndex, int newIndex) async {
    final target = _target;
    if (target == null) return;
    final logic = _editableLogic();
    final blocks = _eventFor(logic, target)['blocks']! as List<Object?>;
    blocks.insert(newIndex, blocks.removeAt(oldIndex));
    await _save(logic);
  }

  Future<void> _deleteBlock(int index) async {
    final target = _target;
    if (target == null) return;
    final logic = _editableLogic();
    (_eventFor(logic, target)['blocks']! as List<Object?>).removeAt(index);
    await _save(logic);
  }

  Future<void> _duplicateBlock(int index) async {
    final target = _target;
    if (target == null) return;
    final logic = _editableLogic();
    final blocks = _eventFor(logic, target)['blocks']! as List<Object?>;
    final copy = jsonDecode(jsonEncode(blocks[index])) as Map<String, Object?>;
    copy['id'] = '${copy['type']}_${DateTime.now().microsecondsSinceEpoch}';
    blocks.insert(index + 1, copy);
    await _save(logic);
  }

  Future<void> _save(Map<String, Object?> logic) async {
    setState(() => _saving = true);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showBlockPalette() async {
    var category = LogicBlockCategory.variables;
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final definitions = LogicBlockCatalog.definitions.where((item) {
            final matchesCategory = item.category == category;
            final normalized = query.toLowerCase();
            return matchesCategory &&
                (normalized.isEmpty ||
                    item.label.toLowerCase().contains(normalized) ||
                    item.description.toLowerCase().contains(normalized));
          }).toList();
          final custom = category == LogicBlockCategory.custom
              ? _customBlocks
                    .where(
                      (item) => '${item['name']}'.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                    )
                    .toList()
              : const <Map<String, Object?>>[];
          void add(Map<String, Object?> block) {
            Navigator.pop(sheetContext);
            _appendBlock(block);
          }

          return FractionallySizedBox(
            heightFactor: .78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action blocks',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search blocks',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: LogicBlockCategory.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final value = LogicBlockCategory.values[index];
                        return ChoiceChip(
                          selected: value == category,
                          label: Text(_categoryLabel(value)),
                          onSelected: (_) =>
                              setSheetState(() => category = value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (category == LogicBlockCategory.variables ||
                      category == LogicBlockCategory.custom)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: category == LogicBlockCategory.variables
                                ? _showVariables
                                : _createCustomBlock,
                            icon: Icon(
                              category == LogicBlockCategory.variables
                                  ? Icons.add_rounded
                                  : Icons.extension_rounded,
                            ),
                            label: Text(
                              category == LogicBlockCategory.variables
                                  ? 'New variable'
                                  : 'Create custom block',
                            ),
                          ),
                        ),
                      ],
                    ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.9,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: definitions.length + custom.length,
                      itemBuilder: (context, index) {
                        final standard = index < definitions.length;
                        final definition = standard ? definitions[index] : null;
                        final customBlock = standard
                            ? null
                            : custom[index - definitions.length];
                        final block = standard
                            ? _createCatalogBlock(definition!)
                            : _createCustomCall(customBlock!);
                        final tile = _PaletteBlockTile(
                          label: standard
                              ? definition!.label
                              : '${customBlock!['name']}',
                          description: standard
                              ? definition!.description
                              : 'Custom block',
                          color: _categoryColor(
                            standard
                                ? definition!.category
                                : LogicBlockCategory.custom,
                            context,
                          ),
                          onTap: () => add(block),
                        );
                        return LongPressDraggable<Map<String, Object?>>(
                          data: block,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(width: 220, child: tile),
                          ),
                          childWhenDragging: Opacity(opacity: .35, child: tile),
                          child: tile,
                        );
                      },
                    ),
                  ),
                  DragTarget<Map<String, Object?>>(
                    onAcceptWithDetails: (details) => add(details.data),
                    builder: (context, candidates, rejected) =>
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height: 52,
                          decoration: ShapeDecoration(
                            color: candidates.isEmpty
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            shape: const StadiumBorder(),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            candidates.isEmpty
                                ? 'Long-press a block, then drop it here'
                                : 'Drop to add to ${_page?.name ?? 'page'}',
                          ),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, Object?> _createCatalogBlock(LogicBlockDefinition definition) {
    final block = definition.createBlock();
    if (definition.type == 'setVariable') {
      block['variableId'] = _pageVariables.firstOrNull?['id'] ?? 'counter';
    } else if (definition.type == 'navigate') {
      block['route'] = _design!.pages
          .firstWhere(
            (page) => page.id != _pageId,
            orElse: () => _design!.initialPage,
          )
          .route;
    }
    return block;
  }

  Map<String, Object?> _createCustomCall(Map<String, Object?> definition) => {
    'id': 'customBlock_${DateTime.now().microsecondsSinceEpoch}',
    'type': 'customBlock',
    'customBlockId': definition['id'],
    'arguments': <String, Object?>{
      for (final parameter
          in (definition['parameters'] as List<Object?>? ?? const [])
              .whereType<Map<String, Object?>>())
        '${parameter['name']}': parameter['defaultValue'] ?? '',
    },
  };

  List<Map<String, Object?>> get _pageVariables =>
      (_logic['variables'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .where(
            (variable) =>
                variable['pageId'] == null || variable['pageId'] == _pageId,
          )
          .toList(growable: false);

  Future<void> _editBlock(int index, Map<String, Object?> block) async {
    final type = '${block['type']}';
    if (type == 'customBlock') {
      await _editCustomCall(index, block);
      return;
    }
    final definition = LogicBlockCatalog.byType(type);
    final values = Map<String, Object?>.from(block);
    final controllers = <String, TextEditingController>{};
    for (final field in definition.fields) {
      if (field.kind != LogicFieldKind.choice) {
        controllers[field.key] = TextEditingController(
          text: '${values[field.key] ?? field.defaultValue ?? ''}',
        );
      }
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  definition.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (final field in definition.fields) ...[
                  if (field.kind == LogicFieldKind.choice)
                    DropdownButtonFormField<String>(
                      initialValue:
                          '${values[field.key] ?? field.defaultValue ?? ''}',
                      decoration: InputDecoration(labelText: field.label),
                      items: _choiceOptions(field).entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setSheetState(() => values[field.key] = value),
                    )
                  else if (field.kind == LogicFieldKind.code)
                    SizedBox(
                      height: 190,
                      child: AppCodeEditor(
                        controller: controllers[field.key]!,
                        readOnly: false,
                      ),
                    )
                  else
                    AppTextField(
                      controller: controllers[field.key]!,
                      label: field.label,
                      keyboardType:
                          field.kind == LogicFieldKind.integer ||
                              field.kind == LogicFieldKind.decimal
                          ? TextInputType.number
                          : null,
                    ),
                  const SizedBox(height: 12),
                ],
                AppButton(
                  label: 'Save block',
                  trailingIcon: Icons.check_rounded,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      for (final entry in controllers.entries) {
        values[entry.key] = entry.value.text;
      }
      await _replaceBlock(index, values);
    }
    for (final controller in controllers.values) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          controller.dispose,
        ),
      );
    }
  }

  Map<String, String> _choiceOptions(LogicFieldDefinition field) {
    if (field.key == 'variableId') {
      return {
        for (final variable in _pageVariables)
          '${variable['id']}': '${variable['name']} · ${variable['type']}',
      };
    }
    if (field.key == 'route') {
      return {for (final page in _design!.pages) page.route: page.name};
    }
    return field.options;
  }

  Future<void> _editCustomCall(int index, Map<String, Object?> block) async {
    final definition = _customBlocks
        .where((item) => item['id'] == block['customBlockId'])
        .firstOrNull;
    if (definition == null) return;
    final arguments = Map<String, Object?>.from(
      block['arguments'] as Map<String, Object?>? ?? const {},
    );
    final controllers = <String, TextEditingController>{
      for (final parameter
          in (definition['parameters'] as List<Object?>? ?? const [])
              .whereType<Map<String, Object?>>())
        '${parameter['name']}': TextEditingController(
          text:
              '${arguments['${parameter['name']}'] ?? parameter['defaultValue'] ?? ''}',
        ),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${definition['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppTextField(
                      controller: entry.value,
                      label: entry.key,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          AppButton(
            label: 'Save',
            expanded: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (saved == true) {
      final updated = Map<String, Object?>.from(block);
      updated['arguments'] = {
        for (final entry in controllers.entries) entry.key: entry.value.text,
      };
      await _replaceBlock(index, updated);
    }
    for (final controller in controllers.values) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          controller.dispose,
        ),
      );
    }
  }

  Future<void> _replaceBlock(int index, Map<String, Object?> block) async {
    final target = _target;
    if (target == null) return;
    final logic = _editableLogic();
    (_eventFor(logic, target)['blocks']! as List<Object?>)[index] = block;
    await _save(logic);
  }

  Future<void> _showVariables() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_page?.name ?? 'Page'} variables',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await _createVariable();
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_pageVariables.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('No variables yet')),
                )
              else
                ..._pageVariables.map(
                  (variable) => ListTile(
                    leading: const Icon(Icons.data_object_rounded),
                    title: Text('${variable['name']}'),
                    subtitle: Text(
                      '${variable['type']} = ${variable['initialValue']}',
                    ),
                  ),
                ),
              AppButton(
                label: 'New variable',
                trailingIcon: Icons.add_rounded,
                onPressed: () async {
                  await _createVariable();
                  setSheetState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createVariable() async {
    final name = TextEditingController();
    final initial = TextEditingController(text: '0');
    var type = 'int';
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create variable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: name, label: 'Name', autofocus: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'int', child: Text('Integer')),
                  DropdownMenuItem(value: 'double', child: Text('Decimal')),
                  DropdownMenuItem(value: 'String', child: Text('Text')),
                  DropdownMenuItem(value: 'bool', child: Text('Boolean')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => type = value);
                },
              ),
              const SizedBox(height: 12),
              AppTextField(controller: initial, label: 'Initial value'),
            ],
          ),
          actions: [
            AppButton(
              label: 'Create',
              expanded: false,
              onPressed: () =>
                  Navigator.pop(context, name.text.trim().isNotEmpty),
            ),
          ],
        ),
      ),
    );
    if (create == true) {
      final logic = _editableLogic();
      final id = name.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
      (logic['variables']! as List<Object?>).add({
        'id': id,
        'name': name.text.trim(),
        'type': type,
        'initialValue': initial.text,
        'pageId': _pageId,
      });
      await _save(logic);
    }
    name.dispose();
    initial.dispose();
  }

  Future<void> _showCustomBlocks() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom blocks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_customBlocks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Create reusable blocks with typed parameters'),
                ),
              ),
            ..._customBlocks.map(
              (block) => ListTile(
                leading: const Icon(Icons.extension_rounded),
                title: Text('${block['name']}'),
                subtitle: Text(
                  '${(block['parameters'] as List<Object?>? ?? const []).length} parameters',
                ),
              ),
            ),
            AppButton(
              label: 'Create custom block',
              trailingIcon: Icons.add_rounded,
              onPressed: () {
                Navigator.pop(context);
                _createCustomBlock();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCustomBlock() async {
    final name = TextEditingController();
    final parameters = TextEditingController();
    final code = TextEditingController(text: "debugPrint('Custom block');");
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create custom block',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: name,
                label: 'Block name',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: parameters,
                label: 'Parameters',
                helper: 'Example: message:String, count:int',
              ),
              const SizedBox(height: 12),
              Text('Dart body', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SizedBox(
                height: 180,
                child: AppCodeEditor(controller: code, readOnly: false),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Create block',
                trailingIcon: Icons.check_rounded,
                onPressed: () =>
                    Navigator.pop(context, name.text.trim().isNotEmpty),
              ),
            ],
          ),
        ),
      ),
    );
    if (created == true) {
      final id = name.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final params = parameters.text
          .split(',')
          .map((item) {
            final parts = item.trim().split(':');
            if (parts.first.trim().isEmpty) return null;
            return <String, Object?>{
              'name': parts.first.trim().replaceAll(
                RegExp(r'[^A-Za-z0-9_]'),
                '_',
              ),
              'type': parts.length > 1 ? parts[1].trim() : 'dynamic',
              'defaultValue': '',
            };
          })
          .whereType<Map<String, Object?>>()
          .toList();
      final logic = _editableLogic();
      (logic['customBlocks']! as List<Object?>).add({
        'id': id.isEmpty
            ? 'custom_${DateTime.now().millisecondsSinceEpoch}'
            : id,
        'name': name.text.trim(),
        'pageId': _pageId,
        'parameters': params,
        'code': code.text,
      });
      await _save(logic);
    }
    name.dispose();
    parameters.dispose();
    code.dispose();
  }
}

class _LogicTarget {
  const _LogicTarget({
    required this.pageId,
    required this.widgetId,
    required this.eventName,
    required this.label,
    required this.icon,
  });
  final String pageId;
  final String widgetId;
  final String eventName;
  final String label;
  final IconData icon;
  String get key => '$widgetId::$eventName';
}

class _ControllerHeader extends StatelessWidget {
  const _ControllerHeader({
    required this.design,
    required this.pageId,
    required this.targetKey,
    required this.targets,
    required this.saving,
    required this.onPageChanged,
    required this.onTargetChanged,
    required this.onVariables,
    required this.onCustomBlocks,
  });
  final ScreenDesign design;
  final String pageId;
  final String? targetKey;
  final List<_LogicTarget> targets;
  final bool saving;
  final ValueChanged<String> onPageChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onVariables;
  final VoidCallback onCustomBlocks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: AppRadii.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: pageId,
                    decoration: const InputDecoration(
                      labelText: 'Controller',
                      isDense: true,
                    ),
                    items: design.pages
                        .map(
                          (page) => DropdownMenuItem(
                            value: page.id,
                            child: Text('${_pascal(page.id)}Controller'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onPageChanged(value);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Variables',
                  onPressed: onVariables,
                  icon: const Icon(Icons.data_object_rounded),
                ),
                IconButton(
                  tooltip: 'Custom blocks',
                  onPressed: onCustomBlocks,
                  icon: const Icon(Icons.extension_rounded),
                ),
                if (saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(targetKey),
              initialValue: targetKey,
              decoration: const InputDecoration(
                labelText: 'Event',
                prefixIcon: Icon(Icons.bolt_rounded),
                isDense: true,
              ),
              items: targets
                  .map(
                    (target) => DropdownMenuItem(
                      value: target.key,
                      child: Text(
                        target.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onTargetChanged(value);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyLogicCanvas extends StatelessWidget {
  const _EmptyLogicCanvas({required this.target, required this.onAdd});
  final _LogicTarget? target;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 100),
    children: [
      if (target != null) _EventHat(target: target!),
      const SizedBox(height: 8),
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onAdd,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 34),
              SizedBox(height: 8),
              Text('Drop an action block here'),
            ],
          ),
        ),
      ),
    ],
  );
}

class _BlockWorkspace extends StatelessWidget {
  const _BlockWorkspace({
    required this.target,
    required this.blocks,
    required this.customBlocks,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });
  final _LogicTarget target;
  final List<Map<String, Object?>> blocks;
  final List<Map<String, Object?>> customBlocks;
  final void Function(int, int) onReorder;
  final void Function(int, Map<String, Object?>) onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onDuplicate;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        sliver: SliverToBoxAdapter(child: _EventHat(target: target)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        sliver: SliverReorderableList(
          itemCount: blocks.length,
          onReorderItem: onReorder,
          itemBuilder: (context, index) => _ActionBlockCard(
            key: ValueKey(
              blocks[index]['id'] ?? '${blocks[index]['type']}_$index',
            ),
            index: index,
            block: blocks[index],
            customBlocks: customBlocks,
            onTap: () => onEdit(index, blocks[index]),
            onDelete: () => onDelete(index),
            onDuplicate: () => onDuplicate(index),
          ),
        ),
      ),
    ],
  );
}

class _EventHat extends StatelessWidget {
  const _EventHat({required this.target});
  final _LogicTarget target;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(18),
          bottom: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          Icon(target.icon, color: colors.onPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              target.label,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBlockCard extends StatelessWidget {
  const _ActionBlockCard({
    super.key,
    required this.index,
    required this.block,
    required this.customBlocks,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
  });
  final int index;
  final Map<String, Object?> block;
  final List<Map<String, Object?>> customBlocks;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final type = '${block['type']}';
    final definition = type == 'customBlock'
        ? null
        : LogicBlockCatalog.byType(type);
    final custom = customBlocks
        .where((item) => item['id'] == block['customBlockId'])
        .firstOrNull;
    final category = definition?.category ?? LogicBlockCategory.custom;
    final color = _categoryColor(category, context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: color,
            borderRadius: BorderRadius.circular(7),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 4, 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            definition?.label ??
                                '${custom?['name'] ?? 'Missing custom block'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _blockSummary(block),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .82),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      iconColor: Colors.white,
                      onSelected: (value) =>
                          value == 'duplicate' ? onDuplicate() : onDelete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Duplicate'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: -1,
            child: Container(
              width: 28,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4),
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: -5,
            child: Container(
              width: 28,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteBlockTile extends StatelessWidget {
  const _PaletteBlockTile({
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(8),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _blockSummary(Map<String, Object?> block) => switch (block['type']) {
  'setVariable' =>
    '${block['variableId']} ${block['operation'] ?? 'set'} ${block['value'] ?? ''}',
  'delay' => '${block['milliseconds']} milliseconds',
  'showSnackBar' || 'log' => '${block['message']}',
  'showDialog' => '${block['title']} · ${block['message']}',
  'navigate' => '${block['route']}',
  'customAction' => '${block['name']}',
  'customCode' => '${block['code']}'.replaceAll('\n', ' '),
  'customBlock' => 'Reusable custom action',
  'pop' => 'Navigator.pop',
  'stopEvent' => 'Return',
  _ => '${block['type']}',
};

String _categoryLabel(LogicBlockCategory category) => switch (category) {
  LogicBlockCategory.variables => 'Variables',
  LogicBlockCategory.control => 'Control',
  LogicBlockCategory.interface => 'Interface',
  LogicBlockCategory.navigation => 'Navigation',
  LogicBlockCategory.data => 'Data',
  LogicBlockCategory.custom => 'Custom',
};

Color _categoryColor(LogicBlockCategory category, BuildContext context) =>
    switch (category) {
      LogicBlockCategory.variables => const Color(0xFFEF7D18),
      LogicBlockCategory.control => const Color(0xFFE1A92A),
      LogicBlockCategory.interface => const Color(0xFF4A6CD4),
      LogicBlockCategory.navigation => const Color(0xFF2CA5E2),
      LogicBlockCategory.data => const Color(0xFF23A99A),
      LogicBlockCategory.custom => const Color(0xFF8A55D7),
    };

String _pascal(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join();
