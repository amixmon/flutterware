import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/widgets/app_button.dart';
import '../../../ui/widgets/app_text_field.dart';
import '../../../ui/theme/app_tokens.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_file.dart';
import '../../projects/domain/project_summary.dart';
import '../domain/editor_models.dart';
import '../domain/logic_models.dart';

const _appBarSelection = r'$appBar';
const _fabSelection = r'$fab';

class VisualEditorController extends ChangeNotifier {
  ScreenDesign? _design;
  String? _activePageId;
  void Function(String)? _selectPage;
  Future<void> Function()? _createPage;
  Future<void> Function()? _flush;
  void Function(String, CustomWidgetDefinition?)? _assignCustomUi;

  List<PageDesign> get pages => _design?.pages ?? const [];
  String? get activePageId => _activePageId;
  PageDesign? get activePage {
    final design = _design;
    if (design == null || design.pages.isEmpty) return null;
    return design.pages.firstWhere(
      (page) => page.id == _activePageId,
      orElse: () => design.initialPage,
    );
  }

  void selectPage(String id) => _selectPage?.call(id);
  Future<void> createPage() async => _createPage?.call();
  Future<void> flush() async => _flush?.call();
  void assignCustomUi(String pageId, CustomWidgetDefinition? widget) =>
      _assignCustomUi?.call(pageId, widget);

  void bind({
    required void Function(String) selectPage,
    required Future<void> Function() createPage,
    required Future<void> Function() flush,
    required void Function(String, CustomWidgetDefinition?) assignCustomUi,
  }) {
    _selectPage = selectPage;
    _createPage = createPage;
    _flush = flush;
    _assignCustomUi = assignCustomUi;
  }

  void unbind() {
    _selectPage = null;
    _createPage = null;
    _flush = null;
    _assignCustomUi = null;
  }

  void update(ScreenDesign design, String activePageId) {
    _design = design;
    _activePageId = activePageId;
    notifyListeners();
  }
}

class VisualEditor extends StatefulWidget {
  const VisualEditor({
    super.key,
    required this.project,
    required this.controller,
    this.onEditEvent,
    this.onWidgetRenamed,
  });

  final ProjectSummary project;
  final VisualEditorController controller;
  final void Function(String widgetId, String eventName, String label)?
  onEditEvent;
  final VoidCallback? onWidgetRenamed;

  @override
  State<VisualEditor> createState() => _VisualEditorState();
}

class _VisualEditorState extends State<VisualEditor> {
  final _repository = const ProjectRepository();
  final _history = <ScreenDesign>[];
  final _future = <ScreenDesign>[];
  ScreenDesign? _design;
  String? _activePageId;
  String? _selectedId;
  WidgetCategory? _category;
  bool _paletteOpen = true;
  bool _dragging = false;
  bool _saving = false;
  String _query = '';
  int _nextId = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.bind(
      selectPage: _activatePage,
      createPage: _createPage,
      flush: _flushDesign,
      assignCustomUi: _assignCustomUi,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final design = await _repository.readDesign(
        id: widget.project.id,
        projectName: widget.project.name,
      );
      if (mounted) {
        setState(() {
          _design = design;
          _activePageId = design.initialPageId;
        });
        widget.controller.update(design, design.initialPageId);
      }
    } catch (_) {
      if (mounted) {
        final fallback = ScreenDesign.fallback(widget.project.name);
        setState(() {
          _design = fallback;
          _activePageId = fallback.initialPageId;
        });
        widget.controller.update(fallback, fallback.initialPageId);
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    widget.controller.unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;
    if (design == null) return const Center(child: CircularProgressIndicator());
    final page = design.pages.firstWhere(
      (item) => item.id == _activePageId,
      orElse: () => design.initialPage,
    );
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          _EditorToolbar(
            page: page,
            selectedId: _selectedId,
            canWrap:
                _selectedId != null &&
                _selectedId != _appBarSelection &&
                _selectedId != _fabSelection &&
                page.body.find(_selectedId!)?.type != 'spacer',
            paletteOpen: _paletteOpen,
            canUndo: _history.isNotEmpty,
            canRedo: _future.isNotEmpty,
            saving: _saving,
            onTogglePalette: () => setState(() => _paletteOpen = !_paletteOpen),
            onUndo: _undo,
            onRedo: _redo,
            onWrap: _showWrapWidget,
            onSettings: _showScreenSettings,
            onSelectWidget: _select,
          ),
          Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _paletteOpen ? 152 : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: _paletteOpen
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 0, 8),
                          child: Material(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            borderRadius: AppRadii.cardBorder,
                            clipBehavior: Clip.antiAlias,
                            child: _WidgetPalette(
                              category: _category,
                              query: _query,
                              onCategoryChanged: (value) =>
                                  setState(() => _category = value),
                              onQueryChanged: (value) =>
                                  setState(() => _query = value),
                              onAdd: _addDefinition,
                              onDragStarted: () =>
                                  setState(() => _dragging = true),
                              onDragEnded: () =>
                                  setState(() => _dragging = false),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _PhoneCanvas(
                          project: widget.project,
                          page: page,
                          selectedId: _selectedId,
                          showDropZones: _dragging,
                          onSelect: _select,
                          onOpenProperties: _openProperties,
                          onDrop: _drop,
                          canDrop: _canDrop,
                          onDragStarted: () => setState(() => _dragging = true),
                          onDragEnded: () => setState(() => _dragging = false),
                        ),
                      ),
                      if (_dragging)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: DragTarget<_EditorDragData>(
                            onWillAcceptWithDetails: (details) =>
                                details.data.nodeId != null &&
                                details.data.nodeId != page.body.id,
                            onAcceptWithDetails: (details) {
                              final id = details.data.nodeId;
                              if (id != null) _removeNode(id);
                            },
                            builder: (context, candidates, rejected) =>
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  height: 58,
                                  decoration: ShapeDecoration(
                                    color: candidates.isEmpty
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.errorContainer
                                        : Theme.of(context).colorScheme.error,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        color: candidates.isEmpty
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onError,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Drop here to delete'),
                                    ],
                                  ),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _select(String id) {
    setState(() => _selectedId = id);
  }

  void _openProperties(String id) {
    setState(() => _selectedId = id);
    if (id == _appBarSelection || id == _fabSelection) {
      _showScaffoldProperties(id);
      return;
    }
    final node = _activePage.body.find(id);
    if (node != null) _showWidgetProperties(node);
  }

  Future<void> _showWrapWidget() async {
    final selectedId = _selectedId;
    if (selectedId == null ||
        selectedId == _appBarSelection ||
        selectedId == _fabSelection) {
      _showMessage('Select a canvas widget to wrap');
      return;
    }
    final page = _activePage;
    final node = page.body.find(selectedId);
    if (node == null) return;
    if (node.type == 'spacer') {
      _showMessage('A Spacer cannot contain another widget');
      return;
    }
    final wrapperType = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _WrapWidgetSheet(widgetLabel: WidgetCatalog.byType(node.type).label),
    );
    if (!mounted || wrapperType == null) return;
    final definition = WidgetCatalog.byType(wrapperType);
    final wrapper = WidgetNode(
      id: '${wrapperType}_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}',
      type: wrapperType,
      properties: definition.defaultProperties,
      children: node.type == 'expanded' ? node.children : [node],
    );
    final replacement = node.type == 'expanded'
        ? node.copyWith(children: [wrapper])
        : wrapper;
    _commitPage(
      page.copyWith(body: page.body.update(node.id, replacement)),
      selectId: wrapper.id,
    );
    _showMessage(
      '${WidgetCatalog.byType(node.type).label} wrapped with ${definition.label}',
    );
  }

  void _addDefinition(WidgetDefinition definition) {
    if (definition.type == 'image') {
      unawaited(_addImportedImage(definition));
      return;
    }
    _insertDefinition(definition);
  }

  Future<void> _addImportedImage(WidgetDefinition definition) async {
    final asset = await _pickImageAsset();
    if (asset == null || !mounted) return;
    _insertDefinition(definition, propertyOverrides: {'asset': asset.path});
  }

  void _insertDefinition(
    WidgetDefinition definition, {
    Map<String, Object?> propertyOverrides = const {},
  }) {
    final page = _activePage;
    var parent = page.body;
    final selected = _selectedId == null ? null : page.body.find(_selectedId!);
    if (selected != null && _canContain(selected, definition.type)) {
      parent = selected;
    } else if (!_canContain(parent, definition.type)) {
      _showMessage('Select a compatible Row, Column, Stack, or container');
      return;
    }
    final node = WidgetNode(
      id: '${definition.type}_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}',
      type: definition.type,
      properties: {...definition.defaultProperties, ...propertyOverrides},
    );
    _commitPage(
      page.copyWith(body: _appendChild(page.body, parent.id, node)),
      selectId: node.id,
    );
  }

  void _drop(String parentId, _EditorDragData data, [int? index]) {
    if (data.definition?.type == 'image') {
      unawaited(_dropImportedImage(parentId, data, index));
      return;
    }
    _performDrop(parentId, data, index);
  }

  Future<void> _dropImportedImage(
    String parentId,
    _EditorDragData data,
    int? index,
  ) async {
    final asset = await _pickImageAsset();
    if (asset == null || !mounted) return;
    _performDrop(
      parentId,
      data,
      index,
      propertyOverrides: {'asset': asset.path},
    );
  }

  void _performDrop(
    String parentId,
    _EditorDragData data,
    int? index, {
    Map<String, Object?> propertyOverrides = const {},
  }) {
    final page = _activePage;
    final parent = page.body.find(parentId);
    if (parent == null) return;
    final type =
        data.definition?.type ?? page.body.find(data.nodeId ?? '')?.type;
    if (type == null || !_canDrop(parentId, data)) {
      _showMessage('That widget is not valid in this drop zone');
      return;
    }
    WidgetNode node;
    var body = page.body;
    if (data.definition != null) {
      node = WidgetNode(
        id: '${type}_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}',
        type: type,
        properties: {
          ...data.definition!.defaultProperties,
          ...propertyOverrides,
        },
      );
    } else {
      node = body.find(data.nodeId!)!;
      if (node.contains(parentId) || node.id == parentId) return;
      if (index != null) {
        final oldIndex = parent.children.indexWhere(
          (child) => child.id == node.id,
        );
        if (oldIndex >= 0 && oldIndex < index) index--;
      }
      body = body.remove(node.id);
    }
    body = _insertChild(body, parentId, node, index);
    _commitPage(page.copyWith(body: body), selectId: node.id);
  }

  Future<ProjectAsset?> _pickImageAsset() async {
    try {
      final asset = await _repository.importAsset(
        id: widget.project.id,
        kind: ProjectAssetKind.image,
      );
      if (asset != null && mounted) {
        _showMessage('Imported ${asset.name}');
      }
      return asset;
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(error.message ?? 'Could not import the image');
      }
      return null;
    }
  }

  bool _canContain(WidgetNode parent, String childType) {
    final definition = WidgetCatalog.byType(parent.type);
    if (!definition.acceptsChildren) return false;
    if (definition.maxChildren != null &&
        parent.children.length >= definition.maxChildren!) {
      return false;
    }
    if ((childType == 'expanded' || childType == 'spacer') &&
        parent.type != 'row' &&
        parent.type != 'column') {
      return false;
    }
    return true;
  }

  bool _canDrop(String parentId, _EditorDragData data) {
    final parent = _activePage.body.find(parentId);
    if (parent == null) return false;
    final child = data.nodeId == null
        ? null
        : _activePage.body.find(data.nodeId!);
    final childType = data.definition?.type ?? child?.type;
    if (childType == null || child?.id == parent.id) return false;
    if (child?.contains(parent.id) == true) return false;
    final definition = WidgetCatalog.byType(parent.type);
    if (!definition.acceptsChildren) return false;
    var childCount = parent.children.length;
    if (child != null && parent.children.any((item) => item.id == child.id)) {
      childCount--;
    }
    if (definition.maxChildren != null &&
        childCount >= definition.maxChildren!) {
      return false;
    }
    if ((childType == 'expanded' || childType == 'spacer') &&
        parent.type != 'row' &&
        parent.type != 'column') {
      return false;
    }
    return true;
  }

  WidgetNode _appendChild(WidgetNode root, String parentId, WidgetNode child) =>
      _insertChild(root, parentId, child, null);

  WidgetNode _insertChild(
    WidgetNode root,
    String parentId,
    WidgetNode child,
    int? index,
  ) {
    if (root.id == parentId) {
      final children = [...root.children];
      children.insert(
        (index ?? children.length).clamp(0, children.length),
        child,
      );
      return root.copyWith(children: children);
    }
    return root.copyWith(
      children: root.children
          .map((item) => _insertChild(item, parentId, child, index))
          .toList(growable: false),
    );
  }

  void _removeNode(String id) {
    final page = _activePage;
    if (id == page.body.id) {
      _showMessage('The screen body cannot be deleted');
      return;
    }
    _commitPage(page.copyWith(body: page.body.remove(id)), selectId: null);
  }

  PageDesign get _activePage => _design!.pages.firstWhere(
    (page) => page.id == _activePageId,
    orElse: () => _design!.initialPage,
  );

  void _commitPage(PageDesign page, {String? selectId}) =>
      _commit(_design!.updatePage(page), selectId: selectId);

  void _commit(ScreenDesign next, {String? selectId}) {
    _history.add(_design!);
    if (_history.length > 50) _history.removeAt(0);
    _future.clear();
    setState(() {
      _design = next;
      _selectedId = selectId;
    });
    widget.controller.update(next, _activePageId ?? next.initialPageId);
    _scheduleSave();
  }

  void _activatePage(String id) {
    if (_design == null || !_design!.pages.any((page) => page.id == id)) return;
    setState(() {
      _activePageId = id;
      _selectedId = null;
    });
    widget.controller.update(_design!, id);
  }

  void _assignCustomUi(String pageId, CustomWidgetDefinition? widget) {
    final design = _design;
    if (design == null) return;
    final page = design.pages.where((item) => item.id == pageId).firstOrNull;
    if (page == null) return;
    _commit(
      design.updatePage(
        page.copyWith(customUi: widget, removeCustomUi: widget == null),
      ),
      selectId: null,
    );
  }

  void _undo() {
    if (_history.isEmpty) return;
    _future.add(_design!);
    setState(() {
      _design = _history.removeLast();
      _selectedId = null;
    });
    widget.controller.update(_design!, _activePage.id);
    _scheduleSave();
  }

  void _redo() {
    if (_future.isEmpty) return;
    _history.add(_design!);
    setState(() {
      _design = _future.removeLast();
      _selectedId = null;
    });
    widget.controller.update(_design!, _activePage.id);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    setState(() => _saving = true);
    _saveTimer = Timer(const Duration(milliseconds: 450), _save);
  }

  Future<void> _save() async {
    try {
      await _repository.writeDesign(id: widget.project.id, design: _design!);
      if (mounted) setState(() => _saving = false);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message ?? 'Could not save the design');
    }
  }

  Future<void> _flushDesign() async {
    _saveTimer?.cancel();
    if (_design != null) await _save();
  }

  Future<void> _showWidgetProperties(WidgetNode node) async {
    final definition = WidgetCatalog.byType(node.type);
    final action = await showModalBottomSheet<_WidgetPropertyResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WidgetPropertySheet(
        node: node,
        definition: definition,
        canDelete: node.id != _activePage.body.id,
        unavailableIds: _widgetIds.where((id) => id != node.id).toSet(),
        onPickImageAsset: definition.type == 'image'
            ? () async => (await _pickImageAsset())?.path
            : null,
        onEditEvent: widget.onEditEvent == null
            ? null
            : (event) {
                Navigator.pop(context);
                widget.onEditEvent!(
                  node.id,
                  event.name,
                  '${definition.label} · ${event.label}',
                );
              },
      ),
    );
    if (!mounted || action == null) return;
    if (action.delete) {
      _removeNode(node.id);
      return;
    }
    final renamed = action.id != node.id;
    if (renamed) {
      try {
        final source = await _repository.readLogic(widget.project.id);
        final logic = jsonDecode(source) as Map<String, Object?>;
        final updatedLogic = renameLogicWidgetId(
          logic,
          from: node.id,
          to: action.id,
        );
        await _repository.writeLogic(
          id: widget.project.id,
          content: const JsonEncoder.withIndent('  ').convert(updatedLogic),
        );
      } on Object catch (error) {
        if (!mounted) return;
        final message = error is PlatformException ? error.message : null;
        _showMessage(message ?? 'Could not rename the widget ID');
        return;
      }
    }
    final updatedNode = node.copyWith(id: action.id, properties: action.values);
    _commitPage(
      _activePage.copyWith(body: _activePage.body.update(node.id, updatedNode)),
      selectId: action.id,
    );
    if (renamed) {
      await _flushDesign();
      widget.onWidgetRenamed?.call();
      if (mounted) _showMessage('Widget ID changed to ${action.id}');
    }
  }

  Iterable<String> get _widgetIds sync* {
    void collect(WidgetNode node, List<String> ids) {
      ids.add(node.id);
      for (final child in node.children) {
        collect(child, ids);
      }
    }

    for (final page in _design!.pages) {
      final ids = <String>[];
      collect(page.body, ids);
      yield* ids;
      if (page.floatingActionButton.enabled) {
        yield '${page.floatingActionButton.properties['id'] ?? '${page.id}_fab'}';
      }
    }
  }

  Future<void> _showScaffoldProperties(String selection) async {
    final appBar = selection == _appBarSelection;
    final slot = appBar ? _activePage.appBar : _activePage.floatingActionButton;
    final controller = TextEditingController(
      text: '${slot.properties[appBar ? 'title' : 'tooltip'] ?? ''}',
    );
    final result = await showModalBottomSheet<_ScaffoldResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
                appBar ? 'AppBar properties' : 'Floating button properties',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: controller,
                label: appBar ? 'Title' : 'Tooltip',
                prefixIcon: appBar
                    ? Icons.title_rounded
                    : Icons.touch_app_outlined,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              if (!appBar && widget.onEditEvent != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bolt_rounded),
                  title: const Text('On tap'),
                  subtitle: const Text('onPressed'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEditEvent!(
                      '${slot.properties['id'] ?? '${_activePage.id}_fab'}',
                      'onPressed',
                      '${_activePage.name} · Floating button · On tap',
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Remove',
                      variant: AppButtonVariant.danger,
                      leadingIcon: Icons.delete_outline_rounded,
                      onPressed: () => Navigator.pop(
                        context,
                        const _ScaffoldResult(remove: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Save',
                      trailingIcon: Icons.check_rounded,
                      onPressed: () => Navigator.pop(
                        context,
                        _ScaffoldResult(value: controller.text),
                      ),
                    ),
                  ),
                ],
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
    if (!mounted || result == null) return;
    final properties = Map<String, Object?>.from(slot.properties);
    properties[appBar ? 'title' : 'tooltip'] = result.value;
    final updated = slot.copyWith(
      enabled: !result.remove,
      properties: properties,
    );
    _commitPage(
      appBar
          ? _activePage.copyWith(appBar: updated)
          : _activePage.copyWith(floatingActionButton: updated),
      selectId: null,
    );
  }

  Future<void> _showScreenSettings() async {
    var appBarEnabled = _activePage.appBar.enabled;
    var fabEnabled = _activePage.floatingActionButton.enabled;
    final result = await showModalBottomSheet<(bool, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Screen settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: appBarEnabled,
                  title: const Text('AppBar'),
                  subtitle: const Text('Show the top application bar'),
                  onChanged: (value) =>
                      setModalState(() => appBarEnabled = value),
                ),
                SwitchListTile(
                  value: fabEnabled,
                  title: const Text('Floating action button'),
                  subtitle: const Text('Show the primary floating action'),
                  onChanged: (value) => setModalState(() => fabEnabled = value),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Apply settings',
                  trailingIcon: Icons.check_rounded,
                  onPressed: () =>
                      Navigator.pop(context, (appBarEnabled, fabEnabled)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    _commitPage(
      _activePage.copyWith(
        appBar: _activePage.appBar.copyWith(enabled: result.$1),
        floatingActionButton: _activePage.floatingActionButton.copyWith(
          enabled: result.$2,
        ),
      ),
    );
  }

  Future<void> _createPage() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create new page'),
        content: AppTextField(
          controller: controller,
          label: 'Page name',
          helper: 'Example: Profile or Order details',
          prefixIcon: Icons.note_add_outlined,
          autofocus: true,
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            expanded: false,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: 'Create page',
            expanded: false,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
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
    if (!mounted || name == null) return;
    var id = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (id.isEmpty) id = 'page';
    if (RegExp(r'^\d').hasMatch(id)) id = 'page_$id';
    final base = id;
    var suffix = 2;
    while (_design!.pages.any((page) => page.id == id)) {
      id = '${base}_${suffix++}';
    }
    final page = PageDesign(
      id: id,
      name: name,
      route: '/$id',
      appBar: ScaffoldSlot(enabled: true, properties: {'title': name}),
      floatingActionButton: ScaffoldSlot(
        enabled: false,
        properties: {'id': '${id}_fab', 'icon': 'add', 'tooltip': 'Action'},
      ),
      body: WidgetNode(
        id: '${id}_root_column',
        type: 'column',
        properties: const {
          'mainAxisAlignment': 'start',
          'crossAxisAlignment': 'start',
        },
        children: const [],
      ),
    );
    _commit(_design!.copyWith(pages: [..._design!.pages, page]));
    setState(() {
      _activePageId = id;
      _selectedId = null;
    });
    widget.controller.update(_design!, id);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.page,
    required this.selectedId,
    required this.canWrap,
    required this.paletteOpen,
    required this.canUndo,
    required this.canRedo,
    required this.saving,
    required this.onTogglePalette,
    required this.onUndo,
    required this.onRedo,
    required this.onWrap,
    required this.onSettings,
    required this.onSelectWidget,
  });

  final PageDesign page;
  final String? selectedId;
  final bool canWrap;
  final bool paletteOpen;
  final bool canUndo;
  final bool canRedo;
  final bool saving;
  final VoidCallback onTogglePalette;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onWrap;
  final VoidCallback onSettings;
  final ValueChanged<String> onSelectWidget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: AppRadii.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                tooltip: paletteOpen ? 'Hide widgets' : 'Show widgets',
                style: IconButton.styleFrom(
                  backgroundColor: paletteOpen
                      ? colors.secondaryContainer
                      : Colors.transparent,
                  foregroundColor: paletteOpen
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),
                onPressed: onTogglePalette,
                icon: Icon(
                  paletteOpen
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Undo',
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: canRedo ? onRedo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
              _WidgetTreeMenu(
                page: page,
                selectedId: selectedId,
                onSelected: onSelectWidget,
              ),
              const Spacer(),
              if (saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (canWrap)
                IconButton(
                  tooltip: 'Wrap selected widget',
                  onPressed: onWrap,
                  icon: const Icon(Icons.wrap_text_rounded),
                ),
              IconButton(
                tooltip: 'Screen settings',
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrapWidgetSheet extends StatelessWidget {
  const _WrapWidgetSheet({required this.widgetLabel});

  final String widgetLabel;

  static const _types = [
    'container',
    'padding',
    'center',
    'card',
    'row',
    'column',
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wrap widget', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          'Choose a parent for $widgetLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.18,
          ),
          itemCount: _types.length,
          itemBuilder: (context, index) {
            final definition = WidgetCatalog.byType(_types[index]);
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: AppRadii.inputBorder,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pop(context, definition.type),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconFor(definition.iconName), size: 24),
                      const SizedBox(height: 7),
                      Text(
                        definition.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _WidgetTreeMenu extends StatelessWidget {
  const _WidgetTreeMenu({
    required this.page,
    required this.selectedId,
    required this.onSelected,
  });

  final PageDesign page;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = <_WidgetTreeEntry>[
      if (page.appBar.enabled)
        const _WidgetTreeEntry(
          id: _appBarSelection,
          label: 'AppBar',
          icon: Icons.web_asset_rounded,
          depth: 0,
        ),
      ..._flattenWidgetTree(page.body),
      if (page.floatingActionButton.enabled)
        const _WidgetTreeEntry(
          id: _fabSelection,
          label: 'Floating button',
          icon: Icons.add_circle_rounded,
          depth: 0,
        ),
    ];
    final selected = entries.where((item) => item.id == selectedId).firstOrNull;
    return PopupMenuButton<String>(
      tooltip: 'Select widget from tree',
      initialValue: selectedId,
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      itemBuilder: (context) => entries
          .map(
            (item) => PopupMenuItem<String>(
              value: item.id,
              child: Row(
                children: [
                  SizedBox(width: item.depth * 14.0),
                  Icon(
                    item.icon,
                    size: 20,
                    color: item.id == selectedId
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.id == selectedId)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: AppRadii.inputBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected?.icon ?? Icons.account_tree_outlined, size: 18),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 66),
              child: Text(
                selected?.label ?? 'Widgets',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _WidgetTreeEntry {
  const _WidgetTreeEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.depth,
  });

  final String id;
  final String label;
  final IconData icon;
  final int depth;
}

List<_WidgetTreeEntry> _flattenWidgetTree(WidgetNode root, [int depth = 0]) {
  final definition = WidgetCatalog.byType(root.type);
  final customLabel = root.properties['text'] ?? root.properties['label'];
  final suffix = customLabel == null || '$customLabel'.trim().isEmpty
      ? ''
      : ' · $customLabel';
  return [
    _WidgetTreeEntry(
      id: root.id,
      label: '${definition.label}$suffix',
      icon: _iconFor(definition.iconName),
      depth: depth,
    ),
    for (final child in root.children) ..._flattenWidgetTree(child, depth + 1),
  ];
}

class _WidgetPalette extends StatelessWidget {
  const _WidgetPalette({
    required this.category,
    required this.query,
    required this.onCategoryChanged,
    required this.onQueryChanged,
    required this.onAdd,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final WidgetCategory? category;
  final String query;
  final ValueChanged<WidgetCategory?> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<WidgetDefinition> onAdd;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final items = WidgetCatalog.definitions
        .where(
          (item) =>
              (category == null || item.category == category) &&
              (normalized.isEmpty ||
                  item.label.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
    return SizedBox(
      width: 144,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Widgets',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: TextField(
              onChanged: onQueryChanged,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonFormField<WidgetCategory?>(
              initialValue: category,
              isExpanded: true,
              style: Theme.of(context).textTheme.labelSmall,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...WidgetCategory.values.map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_categoryName(value)),
                  ),
                ),
              ],
              onChanged: onCategoryChanged,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final tile = _PaletteTile(
                  definition: item,
                  onTap: () => onAdd(item),
                );
                return LongPressDraggable<_EditorDragData>(
                  data: _EditorDragData(definition: item),
                  onDragStarted: onDragStarted,
                  onDragEnd: (_) => onDragEnded(),
                  feedback: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(item.label),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.4, child: tile),
                  child: tile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryName(WidgetCategory category) => switch (category) {
    WidgetCategory.layout => 'Layout',
    WidgetCategory.content => 'Content',
    WidgetCategory.input => 'Input',
    WidgetCategory.scrolling => 'Scroll',
    WidgetCategory.feedback => 'Feedback',
  };
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({required this.definition, required this.onTap});

  final WidgetDefinition definition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      child: Row(
        children: [
          Icon(_iconFor(definition.iconName), size: 20),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              definition.label,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.drag_indicator_rounded, size: 15),
        ],
      ),
    ),
  );
}

class _PhoneCanvas extends StatelessWidget {
  const _PhoneCanvas({
    required this.project,
    required this.page,
    required this.selectedId,
    required this.showDropZones,
    required this.onSelect,
    required this.onOpenProperties,
    required this.onDrop,
    required this.canDrop,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final ProjectSummary project;
  final PageDesign page;
  final String? selectedId;
  final bool showDropZones;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenProperties;
  final void Function(String, _EditorDragData, [int?]) onDrop;
  final bool Function(String, _EditorDragData) canDrop;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: 360,
            height: 780,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26.5),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Row(
                        children: [
                          const Text(
                            '9:41',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 46,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .82),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.signal_cellular_alt_rounded,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.wifi_rounded, size: 12),
                          const SizedBox(width: 4),
                          const Icon(Icons.battery_full_rounded, size: 12),
                        ],
                      ),
                    ),
                    if (page.appBar.enabled)
                      _SelectableSlot(
                        selected: selectedId == _appBarSelection,
                        onTap: () => onSelect(_appBarSelection),
                        onDoubleTap: () => onOpenProperties(_appBarSelection),
                        child: Container(
                          height: 56,
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${page.appBar.properties['title'] ?? page.name}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: page.customUi == null
                                ? _NodeRenderer(
                                    node: page.body,
                                    parentType: 'screen',
                                    selectedId: selectedId,
                                    showDropZones: showDropZones,
                                    onSelect: onSelect,
                                    onOpenProperties: onOpenProperties,
                                    onDrop: onDrop,
                                    canDrop: canDrop,
                                    onDragStarted: onDragStarted,
                                    onDragEnded: onDragEnded,
                                  )
                                : _CustomUiCanvas(widget: page.customUi!),
                          ),
                          if (page.floatingActionButton.enabled)
                            Positioned(
                              right: 18,
                              bottom: 18,
                              child: _SelectableSlot(
                                selected: selectedId == _fabSelection,
                                circular: true,
                                onTap: () => onSelect(_fabSelection),
                                onDoubleTap: () =>
                                    onOpenProperties(_fabSelection),
                                child: FloatingActionButton(
                                  heroTag: 'visual_editor_fab_${project.id}',
                                  onPressed: () => onSelect(_fabSelection),
                                  child: Icon(
                                    _materialIcon(
                                      '${page.floatingActionButton.properties['icon'] ?? 'add'}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CustomUiCanvas extends StatelessWidget {
  const _CustomUiCanvas({required this.widget});

  final CustomWidgetDefinition widget;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.widgets_outlined, size: 36),
              const SizedBox(height: 10),
              Text(
                widget.className,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                widget.arguments.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('  •  '),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NodeRenderer extends StatelessWidget {
  const _NodeRenderer({
    required this.node,
    required this.parentType,
    required this.selectedId,
    required this.showDropZones,
    required this.onSelect,
    required this.onOpenProperties,
    required this.onDrop,
    required this.canDrop,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final WidgetNode node;
  final String parentType;
  final String? selectedId;
  final bool showDropZones;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenProperties;
  final void Function(String, _EditorDragData, [int?]) onDrop;
  final bool Function(String, _EditorDragData) canDrop;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    final selected = selectedId == node.id;
    final wrapped = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onSelect(node.id),
      onDoubleTap: () => onOpenProperties(node.id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: content,
      ),
    );
    if (parentType == 'screen') return wrapped;
    final draggable = LongPressDraggable<_EditorDragData>(
      data: _EditorDragData(nodeId: node.id),
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded(),
      feedback: Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(WidgetCatalog.byType(node.type).label),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: wrapped),
      child: wrapped,
    );
    if (node.type == 'expanded' || node.type == 'spacer') {
      return Expanded(
        flex: _integer(node.properties['flex'], 1),
        child: draggable,
      );
    }
    return draggable;
  }

  Widget _content(BuildContext context) {
    final children = node.children
        .map(
          (child) => _NodeRenderer(
            node: child,
            parentType: node.type,
            selectedId: selectedId,
            showDropZones: showDropZones,
            onSelect: onSelect,
            onOpenProperties: onOpenProperties,
            onDrop: onDrop,
            canDrop: canDrop,
            onDragStarted: onDragStarted,
            onDragEnded: onDragEnded,
          ),
        )
        .toList(growable: false);
    final p = node.properties;
    Widget dropContainer(Widget child) => DragTarget<_EditorDragData>(
      onWillAcceptWithDetails: (details) => canDrop(node.id, details.data),
      onAcceptWithDetails: (details) => onDrop(node.id, details.data),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: candidates.isEmpty
            ? Colors.transparent
            : Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.65),
        child: child,
      ),
    );
    List<Widget> linearChildren(Axis axis, String label) {
      if (!showDropZones) {
        return children.isEmpty
            ? [_EmptyDropZone(label: 'Drop widgets into $label')]
            : children;
      }
      if (children.isEmpty) {
        return [
          _EmptyInsertionDropTarget(
            parentId: node.id,
            index: 0,
            axis: axis,
            label: 'Drop inside $label',
            canDrop: canDrop,
            onDrop: onDrop,
          ),
        ];
      }
      return [
        for (var index = 0; index < children.length; index++)
          _wrapLinearDropTargets(
            child: children[index],
            parentId: node.id,
            index: index,
            axis: axis,
            canDrop: canDrop,
            onDrop: onDrop,
          ),
      ];
    }

    switch (node.type) {
      case 'column':
        return dropContainer(
          Column(
            mainAxisAlignment: _mainAxis(
              '${p['mainAxisAlignment'] ?? 'start'}',
            ),
            crossAxisAlignment: _crossAxis(
              '${p['crossAxisAlignment'] ?? 'start'}',
            ),
            mainAxisSize: p['mainAxisSize'] == 'min'
                ? MainAxisSize.min
                : MainAxisSize.max,
            verticalDirection: p['verticalDirection'] == 'up'
                ? VerticalDirection.up
                : VerticalDirection.down,
            textDirection: p['textDirection'] == 'rtl'
                ? TextDirection.rtl
                : TextDirection.ltr,
            children: linearChildren(Axis.vertical, 'Column'),
          ),
        );
      case 'row':
        return dropContainer(
          Row(
            mainAxisAlignment: _mainAxis(
              '${p['mainAxisAlignment'] ?? 'start'}',
            ),
            crossAxisAlignment: _crossAxis(
              '${p['crossAxisAlignment'] ?? 'start'}',
            ),
            mainAxisSize: p['mainAxisSize'] == 'min'
                ? MainAxisSize.min
                : MainAxisSize.max,
            verticalDirection: p['verticalDirection'] == 'up'
                ? VerticalDirection.up
                : VerticalDirection.down,
            textDirection: p['textDirection'] == 'rtl'
                ? TextDirection.rtl
                : TextDirection.ltr,
            children: linearChildren(Axis.horizontal, 'Row'),
          ),
        );
      case 'stack':
        return dropContainer(
          SizedBox(
            width: double.infinity,
            height: 140,
            child: Stack(
              alignment: _alignment('${p['alignment'] ?? 'topLeft'}'),
              fit: switch (p['fit']) {
                'expand' => StackFit.expand,
                'passthrough' => StackFit.passthrough,
                _ => StackFit.loose,
              },
              clipBehavior: _clipBehavior('${p['clipBehavior'] ?? 'hardEdge'}'),
              children: [
                if (children.isEmpty)
                  const Positioned.fill(
                    child: _EmptyDropZone(label: 'Drop into Stack'),
                  )
                else
                  ...children,
              ],
            ),
          ),
        );
      case 'container':
        return dropContainer(
          Container(
            width: _autoDimension(p['width']),
            height: _autoDimension(p['height']),
            padding: EdgeInsets.all(_double(p['padding'], 12)),
            margin: EdgeInsets.all(_double(p['margin'], 0)),
            alignment: _alignment('${p['alignment'] ?? 'topLeft'}'),
            decoration: BoxDecoration(
              color:
                  _optionalColor(p['backgroundColor']) ??
                  Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(
                _double(p['borderRadius'], 0),
              ),
              border: _double(p['borderWidth'], 0) <= 0
                  ? null
                  : Border.all(
                      color:
                          _optionalColor(p['borderColor']) ??
                          Theme.of(context).colorScheme.outline,
                      width: _double(p['borderWidth'], 0),
                    ),
            ),
            child: children.isEmpty
                ? const _EmptyDropZone(label: 'Container')
                : children.first,
          ),
        );
      case 'center':
        return dropContainer(
          Center(
            widthFactor: _nullablePositive(p['widthFactor']),
            heightFactor: _nullablePositive(p['heightFactor']),
            child: children.isEmpty
                ? const _EmptyDropZone(label: 'Center')
                : children.first,
          ),
        );
      case 'padding':
        return dropContainer(
          Padding(
            padding: p['individual'] == true
                ? EdgeInsets.fromLTRB(
                    _double(p['left'], 16),
                    _double(p['top'], 16),
                    _double(p['right'], 16),
                    _double(p['bottom'], 16),
                  )
                : EdgeInsets.all(_double(p['padding'], 16)),
            child: children.isEmpty
                ? const _EmptyDropZone(label: 'Padding')
                : children.first,
          ),
        );
      case 'card':
        return dropContainer(
          Card(
            elevation: _double(p['elevation'], 1),
            margin: EdgeInsets.all(_double(p['margin'], 4)),
            color: _optionalColor(p['color']),
            clipBehavior: _clipBehavior('${p['clipBehavior'] ?? 'none'}'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                _double(p['borderRadius'], 12),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(_double(p['padding'], 12)),
              child: children.isEmpty
                  ? const _EmptyDropZone(label: 'Card')
                  : children.first,
            ),
          ),
        );
      case 'expanded':
        return dropContainer(
          children.isEmpty
              ? const _EmptyDropZone(label: 'Expanded')
              : children.first,
        );
      case 'sizedBox':
        return SizedBox(
          width: _double(p['width'], 16),
          height: _double(p['height'], 16),
        );
      case 'spacer':
        return const SizedBox(width: 24, height: 24);
      case 'text':
        final themeStyle = _textStyle(context, '${p['style'] ?? 'bodyLarge'}');
        final fontSize = _double(p['fontSize'], 0);
        return Text(
          p['binding'] == 'counter' ? '0' : '${p['text'] ?? 'Text'}',
          textAlign: _textAlign('${p['textAlign'] ?? 'left'}'),
          maxLines: _integer(p['maxLines'], 0) <= 0
              ? null
              : _integer(p['maxLines'], 0),
          overflow: _textOverflow('${p['overflow'] ?? 'clip'}'),
          softWrap: p['softWrap'] != false,
          style: themeStyle?.copyWith(
            fontSize: fontSize <= 0 ? null : fontSize,
            fontWeight: _fontWeight('${p['fontWeight'] ?? 'normal'}'),
            color: _optionalColor(p['color']),
            letterSpacing: _double(p['letterSpacing'], 0),
            height: _double(p['lineHeight'], 1),
          ),
        );
      case 'icon':
        return Icon(
          _materialIcon('${p['icon'] ?? 'star'}'),
          size: _double(p['size'], 32),
          color: _optionalColor(p['color']),
          semanticLabel: '${p['semanticLabel'] ?? ''}'.isEmpty
              ? null
              : '${p['semanticLabel']}',
        );
      case 'image':
        final asset = '${p['asset'] ?? ''}';
        return Opacity(
          opacity: _double(p['opacity'], 1).clamp(0, 1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_double(p['borderRadius'], 0)),
            child: Container(
              width: _double(p['width'], 120),
              height: _double(p['height'], 120),
              alignment: _alignment('${p['alignment'] ?? 'center'}'),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined),
                  if (asset.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        asset.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      case 'divider':
        return SizedBox(
          height: _double(p['height'], 16),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: _double(p['indent'], 0),
              end: _double(p['endIndent'], 0),
            ),
            child: Center(
              child: Container(
                height: _double(p['thickness'], 1),
                color:
                    _optionalColor(p['color']) ??
                    Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        );
      case 'button':
        final enabled = p['enabled'] != false;
        final callback = enabled ? () {} : null;
        final iconName = '${p['icon'] ?? 'none'}';
        final label = Text(
          '${p['text'] ?? 'Button'}',
          style: _double(p['textSize'], 0) <= 0
              ? null
              : TextStyle(fontSize: _double(p['textSize'], 0)),
        );
        final content = iconName == 'none'
            ? label
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: p['iconPosition'] == 'right'
                    ? [
                        label,
                        const SizedBox(width: 8),
                        Icon(_materialIcon(iconName)),
                      ]
                    : [
                        Icon(_materialIcon(iconName)),
                        const SizedBox(width: 8),
                        label,
                      ],
              );
        final style = ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(0, _double(p['height'], 48)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                _double(p['borderRadius'], 99),
              ),
            ),
          ),
        );
        final button = switch (p['variant']) {
          'tonal' => FilledButton.tonal(
            onPressed: callback,
            style: style,
            child: content,
          ),
          'elevated' => ElevatedButton(
            onPressed: callback,
            style: style,
            child: content,
          ),
          'outlined' => OutlinedButton(
            onPressed: callback,
            style: style,
            child: content,
          ),
          'text' => TextButton(
            onPressed: callback,
            style: style,
            child: content,
          ),
          _ => FilledButton(onPressed: callback, style: style, child: content),
        };
        final sizedButton = switch (p['widthMode']) {
          'full' => SizedBox(width: double.infinity, child: button),
          'fixed' => SizedBox(width: _double(p['width'], 160), child: button),
          _ => button,
        };
        return IgnorePointer(
          child: '${p['tooltip'] ?? ''}'.isEmpty
              ? sizedButton
              : Tooltip(message: '${p['tooltip']}', child: sizedButton),
        );
      case 'textField':
        return IgnorePointer(
          child: TextField(
            enabled: p['enabled'] != false,
            readOnly: true,
            obscureText: p['obscureText'] == true,
            maxLines: p['obscureText'] == true
                ? 1
                : _integer(p['maxLines'], 1).clamp(1, 20),
            decoration: InputDecoration(
              labelText: '${p['label'] ?? 'Input'}',
              hintText: '${p['hint'] ?? ''}'.isEmpty ? null : '${p['hint']}',
              prefixIcon: '${p['prefixIcon'] ?? 'none'}' == 'none'
                  ? null
                  : Icon(_materialIcon('${p['prefixIcon']}')),
            ),
          ),
        );
      case 'checkbox':
        final checkbox = Checkbox(
          value: p['value'] == true,
          onChanged: p['enabled'] == false ? null : (_) {},
        );
        final checkboxLabel = Text('${p['label'] ?? 'Checkbox'}');
        return IgnorePointer(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: p['controlAffinity'] == 'trailing'
                ? [checkboxLabel, checkbox]
                : [checkbox, checkboxLabel],
          ),
        );
      case 'switch':
        final toggle = Switch(
          value: p['value'] == true,
          onChanged: p['enabled'] == false ? null : (_) {},
        );
        final switchLabel = Text('${p['label'] ?? 'Switch'}');
        return IgnorePointer(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: p['controlAffinity'] == 'trailing'
                ? [switchLabel, toggle]
                : [toggle, switchLabel],
          ),
        );
      case 'slider':
        final min = _double(p['min'], 0);
        final rawMax = _double(p['max'], 1);
        final max = rawMax <= min ? min + 1 : rawMax;
        return IgnorePointer(
          child: Slider(
            value: _double(p['value'], 0.5).clamp(min, max),
            min: min,
            max: max,
            divisions: _integer(p['divisions'], 0) <= 0
                ? null
                : _integer(p['divisions'], 0),
            label: '${p['label'] ?? ''}'.isEmpty ? null : '${p['label']}',
            onChanged: p['enabled'] == false ? null : (_) {},
          ),
        );
      case 'listView':
        final listAxis = p['scrollDirection'] == 'horizontal'
            ? Axis.horizontal
            : Axis.vertical;
        return dropContainer(
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: listAxis,
              reverse: p['reverse'] == true,
              shrinkWrap: p['shrinkWrap'] != false,
              padding: EdgeInsets.all(_double(p['padding'], 0)),
              children: linearChildren(listAxis, 'ListView'),
            ),
          ),
        );
      case 'gridView':
        final gridAxis = p['scrollDirection'] == 'horizontal'
            ? Axis.horizontal
            : Axis.vertical;
        return dropContainer(
          SizedBox(
            height: 180,
            child: GridView.count(
              scrollDirection: gridAxis,
              reverse: p['reverse'] == true,
              padding: EdgeInsets.all(_double(p['padding'], 0)),
              crossAxisCount: _integer(p['columns'], 2).clamp(1, 6),
              mainAxisSpacing: _double(p['mainAxisSpacing'], 0),
              crossAxisSpacing: _double(p['crossAxisSpacing'], 0),
              childAspectRatio: _double(p['childAspectRatio'], 1),
              children: linearChildren(gridAxis, 'GridView'),
            ),
          ),
        );
      case 'scrollView':
        return dropContainer(
          SingleChildScrollView(
            scrollDirection: p['scrollDirection'] == 'horizontal'
                ? Axis.horizontal
                : Axis.vertical,
            reverse: p['reverse'] == true,
            padding: EdgeInsets.all(_double(p['padding'], 0)),
            child: children.isEmpty
                ? const _EmptyDropZone(label: 'ScrollView')
                : children.first,
          ),
        );
      case 'progress':
        final progressValue = p['indeterminate'] == true
            ? null
            : _double(p['value'], 0.65).clamp(0.0, 1.0).toDouble();
        return p['type'] == 'linear'
            ? LinearProgressIndicator(
                value: progressValue,
                color: _optionalColor(p['color']),
                backgroundColor: _optionalColor(p['backgroundColor']),
                minHeight: _double(p['strokeWidth'], 4),
              )
            : CircularProgressIndicator(
                value: progressValue,
                color: _optionalColor(p['color']),
                backgroundColor: _optionalColor(p['backgroundColor']),
                strokeWidth: _double(p['strokeWidth'], 4),
              );
      default:
        return Text('Unsupported ${node.type}');
    }
  }
}

Widget _wrapLinearDropTargets({
  required Widget child,
  required String parentId,
  required int index,
  required Axis axis,
  required bool Function(String, _EditorDragData) canDrop,
  required void Function(String, _EditorDragData, [int?]) onDrop,
}) {
  Widget wrap(Widget content) => _LinearDropSlot(
    parentId: parentId,
    index: index,
    axis: axis,
    canDrop: canDrop,
    onDrop: onDrop,
    child: content,
  );

  if (child is Expanded) {
    return Expanded(flex: child.flex, child: wrap(child.child));
  }
  return wrap(child);
}

class _LinearDropSlot extends StatelessWidget {
  const _LinearDropSlot({
    required this.parentId,
    required this.index,
    required this.axis,
    required this.canDrop,
    required this.onDrop,
    required this.child,
  });

  final String parentId;
  final int index;
  final Axis axis;
  final bool Function(String, _EditorDragData) canDrop;
  final void Function(String, _EditorDragData, [int?]) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      child,
      if (axis == Axis.vertical) ...[
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 14,
          child: _InsertionDropOverlay(
            parentId: parentId,
            index: index,
            axis: axis,
            edge: _DropEdge.leading,
            canDrop: canDrop,
            onDrop: onDrop,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 14,
          child: _InsertionDropOverlay(
            parentId: parentId,
            index: index + 1,
            axis: axis,
            edge: _DropEdge.trailing,
            canDrop: canDrop,
            onDrop: onDrop,
          ),
        ),
      ] else ...[
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: 14,
          child: _InsertionDropOverlay(
            parentId: parentId,
            index: index,
            axis: axis,
            edge: _DropEdge.leading,
            canDrop: canDrop,
            onDrop: onDrop,
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 14,
          child: _InsertionDropOverlay(
            parentId: parentId,
            index: index + 1,
            axis: axis,
            edge: _DropEdge.trailing,
            canDrop: canDrop,
            onDrop: onDrop,
          ),
        ),
      ],
    ],
  );
}

enum _DropEdge { leading, trailing }

class _InsertionDropOverlay extends StatelessWidget {
  const _InsertionDropOverlay({
    required this.parentId,
    required this.index,
    required this.axis,
    required this.edge,
    required this.canDrop,
    required this.onDrop,
  });

  final String parentId;
  final int index;
  final Axis axis;
  final _DropEdge edge;
  final bool Function(String, _EditorDragData) canDrop;
  final void Function(String, _EditorDragData, [int?]) onDrop;

  @override
  Widget build(BuildContext context) => DragTarget<_EditorDragData>(
    onWillAcceptWithDetails: (details) => canDrop(parentId, details.data),
    onAcceptWithDetails: (details) => onDrop(parentId, details.data, index),
    builder: (context, candidates, rejected) {
      final active = candidates.isNotEmpty;
      final alignment = axis == Axis.vertical
          ? edge == _DropEdge.leading
                ? Alignment.topCenter
                : Alignment.bottomCenter
          : edge == _DropEdge.leading
          ? Alignment.centerLeft
          : Alignment.centerRight;
      return ColoredBox(
        color: Colors.transparent,
        child: Align(
          alignment: alignment,
          child: AnimatedContainer(
            key: active ? const ValueKey('active-insertion-line') : null,
            duration: const Duration(milliseconds: 90),
            width: axis == Axis.vertical ? double.infinity : (active ? 3 : 0),
            height: axis == Axis.vertical ? (active ? 3 : 0) : double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      );
    },
  );
}

class _EmptyInsertionDropTarget extends StatelessWidget {
  const _EmptyInsertionDropTarget({
    required this.parentId,
    required this.index,
    required this.axis,
    required this.label,
    required this.canDrop,
    required this.onDrop,
  });

  final String parentId;
  final int index;
  final Axis axis;
  final String label;
  final bool Function(String, _EditorDragData) canDrop;
  final void Function(String, _EditorDragData, [int?]) onDrop;

  @override
  Widget build(BuildContext context) => DragTarget<_EditorDragData>(
    onWillAcceptWithDetails: (details) => canDrop(parentId, details.data),
    onAcceptWithDetails: (details) => onDrop(parentId, details.data, index),
    builder: (context, candidates, rejected) {
      final active = candidates.isNotEmpty;
      final colors = Theme.of(context).colorScheme;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: axis == Axis.horizontal ? 96 : double.infinity,
        height: axis == Axis.vertical ? 44 : 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: active
              ? colors.primaryContainer
              : colors.primary.withValues(alpha: .06),
          border: Border.all(
            color: active
                ? colors.primary
                : colors.primary.withValues(alpha: .35),
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? colors.primary : colors.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    },
  );
}

class _EmptyDropZone extends StatelessWidget {
  const _EmptyDropZone({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 54, minWidth: 90),
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall,
      textAlign: TextAlign.center,
    ),
  );
}

class _SelectableSlot extends StatelessWidget {
  const _SelectableSlot({
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.child,
    this.circular = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Widget child;
  final bool circular;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onDoubleTap: onDoubleTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        border: selected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
            : null,
      ),
      child: IgnorePointer(child: child),
    ),
  );
}

class _EditorDragData {
  const _EditorDragData({this.definition, this.nodeId});

  final WidgetDefinition? definition;
  final String? nodeId;
}

class _WidgetPropertySheet extends StatefulWidget {
  const _WidgetPropertySheet({
    required this.node,
    required this.definition,
    required this.canDelete,
    required this.unavailableIds,
    this.onPickImageAsset,
    this.onEditEvent,
  });

  final WidgetNode node;
  final WidgetDefinition definition;
  final bool canDelete;
  final Set<String> unavailableIds;
  final Future<String?> Function()? onPickImageAsset;
  final ValueChanged<EventDefinition>? onEditEvent;

  @override
  State<_WidgetPropertySheet> createState() => _WidgetPropertySheetState();
}

class _WidgetPropertySheetState extends State<_WidgetPropertySheet> {
  late final Map<String, Object?> _values = Map.from(widget.node.properties);
  late String _id = widget.node.id;
  bool _showEvents = false;
  List<PropertyDefinition> get _properties =>
      WidgetCatalog.propertiesFor(widget.definition);

  Object? _value(PropertyDefinition property) =>
      _values[property.key] ?? property.defaultValue;

  @override
  Widget build(BuildContext context) {
    final events = widget.definition.events;
    final showingEvents = _showEvents && events.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(widget.definition.iconName), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.definition.label} properties',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.canDelete)
                IconButton(
                  tooltip: 'Delete widget',
                  onPressed: () => Navigator.pop(
                    context,
                    const _WidgetPropertyResult.delete(),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  _WidgetPropertyResult(id: _id, values: _values),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
          if (events.isNotEmpty)
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Properties'),
                  selected: !showingEvents,
                  onSelected: (_) => setState(() => _showEvents = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Events'),
                  selected: showingEvents,
                  onSelected: (_) => setState(() => _showEvents = true),
                ),
              ],
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: showingEvents
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: events.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _HorizontalPropertyCard(
                        icon: Icons.bolt_rounded,
                        label: event.label,
                        value: event.name,
                        onTap: widget.onEditEvent == null
                            ? null
                            : () => widget.onEditEvent!(event),
                      );
                    },
                  )
                : ListView.separated(
                    key: const ValueKey('horizontal-widget-properties'),
                    scrollDirection: Axis.horizontal,
                    itemCount: _properties.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _HorizontalPropertyCard(
                          key: const ValueKey('widget-id-property'),
                          icon: Icons.tag_rounded,
                          label: 'Widget ID',
                          value: _id,
                          onTap: _editId,
                        );
                      }
                      final property = _properties[index - 1];
                      return _HorizontalPropertyCard(
                        icon: _propertyIcon(property),
                        label: property.label,
                        value: _displayValue(property),
                        onTap: () => _editProperty(property),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _displayValue(PropertyDefinition property) {
    final value = _value(property);
    if (property.kind == PropertyKind.choice) {
      return property.options['$value'] ?? '$value';
    }
    if (property.kind == PropertyKind.toggle) {
      return value == true ? 'On' : 'Off';
    }
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? 'Not set' : text;
  }

  IconData _propertyIcon(PropertyDefinition property) => property.key == 'asset'
      ? Icons.add_photo_alternate_outlined
      : switch (property.kind) {
          PropertyKind.toggle => Icons.toggle_on_outlined,
          PropertyKind.choice => Icons.list_alt_rounded,
          PropertyKind.color => Icons.palette_outlined,
          PropertyKind.number ||
          PropertyKind.integer => Icons.straighten_rounded,
          PropertyKind.text => Icons.edit_outlined,
        };

  Future<void> _editId() async {
    final controller = TextEditingController(text: _id);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change widget ID'),
        content: Form(
          key: formKey,
          child: AppTextField(
            key: const ValueKey('widget-id-field'),
            controller: controller,
            label: 'Widget ID',
            helper: 'Lowercase letters, numbers, and underscores',
            prefixIcon: Icons.tag_rounded,
            autofocus: true,
            autocorrect: false,
            maxLength: 64,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
            ],
            validator: (value) {
              final id = value?.trim() ?? '';
              if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id)) {
                return 'Start with a letter and use a-z, 0-9, or _';
              }
              if (widget.unavailableIds.contains(id)) {
                return 'That widget ID is already in use';
              }
              return null;
            },
            onSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Change ID'),
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
    if (result != null && mounted) setState(() => _id = result);
  }

  Future<void> _editProperty(PropertyDefinition property) async {
    if (property.key == 'asset' && widget.onPickImageAsset != null) {
      final path = await widget.onPickImageAsset!();
      if (path != null && mounted) {
        setState(() => _values[property.key] = path);
      }
      return;
    }
    if (property.kind == PropertyKind.toggle) {
      setState(() => _values[property.key] = _value(property) != true);
      return;
    }
    if (property.kind == PropertyKind.choice) {
      final current = '${_value(property) ?? property.options.keys.first}';
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(property.label),
          children: [
            for (final option in property.options.entries)
              ListTile(
                title: Text(option.value),
                trailing: option.key == current
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(dialogContext, option.key),
              ),
          ],
        ),
      );
      if (result != null && mounted) {
        setState(() => _values[property.key] = result);
      }
      return;
    }

    final controller = TextEditingController(text: '${_value(property) ?? ''}');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(property.label),
        content: Form(
          key: formKey,
          child: AppTextField(
            controller: controller,
            label: property.label,
            prefixIcon: _propertyIcon(property),
            autofocus: true,
            keyboardType:
                property.kind == PropertyKind.number ||
                    property.kind == PropertyKind.integer
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : null,
            validator: (value) {
              if ((property.kind == PropertyKind.number ||
                      property.kind == PropertyKind.integer) &&
                  double.tryParse(value ?? '') == null) {
                return 'Enter a valid number';
              }
              return null;
            },
            onSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: const Text('Apply'),
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
    if (result == null || !mounted) return;
    if (property.kind == PropertyKind.number ||
        property.kind == PropertyKind.integer) {
      final parsed = double.parse(result);
      final limited = parsed.clamp(
        property.min ?? double.negativeInfinity,
        property.max ?? double.infinity,
      );
      setState(() {
        _values[property.key] = property.kind == PropertyKind.integer
            ? limited.round()
            : limited;
      });
    } else {
      setState(() => _values[property.key] = result);
    }
  }
}

class _HorizontalPropertyCard extends StatelessWidget {
  const _HorizontalPropertyCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 108,
    child: Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WidgetPropertyResult {
  const _WidgetPropertyResult({required this.id, required this.values})
    : delete = false;

  const _WidgetPropertyResult.delete()
    : id = '',
      values = const {},
      delete = true;

  final String id;
  final Map<String, Object?> values;
  final bool delete;
}

class _ScaffoldResult {
  const _ScaffoldResult({this.remove = false, this.value = ''});

  final bool remove;
  final String value;
}

double _double(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

int _integer(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

double? _autoDimension(Object? value) {
  final result = _double(value, 0);
  return result <= 0 ? null : result;
}

double? _nullablePositive(Object? value) {
  final result = _double(value, 0);
  return result <= 0 ? null : result;
}

Color? _optionalColor(Object? value) {
  final source = '$value'.trim().replaceFirst('#', '');
  if (source.isEmpty || source == '00000000') return null;
  final normalized = source.length == 6 ? 'FF$source' : source;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null || normalized.length != 8 ? null : Color(parsed);
}

Alignment _alignment(String value) => switch (value) {
  'topCenter' => Alignment.topCenter,
  'topRight' => Alignment.topRight,
  'centerLeft' => Alignment.centerLeft,
  'center' => Alignment.center,
  'centerRight' => Alignment.centerRight,
  'bottomLeft' => Alignment.bottomLeft,
  'bottomCenter' => Alignment.bottomCenter,
  'bottomRight' => Alignment.bottomRight,
  _ => Alignment.topLeft,
};

Clip _clipBehavior(String value) => switch (value) {
  'hardEdge' => Clip.hardEdge,
  'antiAlias' => Clip.antiAlias,
  _ => Clip.none,
};

TextAlign _textAlign(String value) => switch (value) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  'justify' => TextAlign.justify,
  _ => TextAlign.left,
};

TextOverflow _textOverflow(String value) => switch (value) {
  'ellipsis' => TextOverflow.ellipsis,
  'fade' => TextOverflow.fade,
  'visible' => TextOverflow.visible,
  _ => TextOverflow.clip,
};

FontWeight _fontWeight(String value) => switch (value) {
  'w300' => FontWeight.w300,
  'w500' => FontWeight.w500,
  'w600' => FontWeight.w600,
  'bold' => FontWeight.bold,
  _ => FontWeight.normal,
};

TextStyle? _textStyle(BuildContext context, String name) => switch (name) {
  'bodySmall' => Theme.of(context).textTheme.bodySmall,
  'bodyMedium' => Theme.of(context).textTheme.bodyMedium,
  'bodyLarge' => Theme.of(context).textTheme.bodyLarge,
  'titleMedium' => Theme.of(context).textTheme.titleMedium,
  'titleLarge' => Theme.of(context).textTheme.titleLarge,
  'headlineSmall' => Theme.of(context).textTheme.headlineSmall,
  'headlineMedium' => Theme.of(context).textTheme.headlineMedium,
  'headlineLarge' => Theme.of(context).textTheme.headlineLarge,
  _ => Theme.of(context).textTheme.bodyLarge,
};

MainAxisAlignment _mainAxis(String value) => switch (value) {
  'center' => MainAxisAlignment.center,
  'end' => MainAxisAlignment.end,
  'spaceAround' => MainAxisAlignment.spaceAround,
  'spaceBetween' => MainAxisAlignment.spaceBetween,
  'spaceEvenly' => MainAxisAlignment.spaceEvenly,
  _ => MainAxisAlignment.start,
};

CrossAxisAlignment _crossAxis(String value) => switch (value) {
  'center' => CrossAxisAlignment.center,
  'start' => CrossAxisAlignment.start,
  'end' => CrossAxisAlignment.end,
  'stretch' => CrossAxisAlignment.stretch,
  _ => CrossAxisAlignment.start,
};

IconData _materialIcon(String name) => switch (name) {
  'add' => Icons.add_rounded,
  'home' => Icons.home_rounded,
  'favorite' => Icons.favorite_rounded,
  'settings' => Icons.settings_rounded,
  'person' => Icons.person_rounded,
  'search' => Icons.search_rounded,
  'close' => Icons.close_rounded,
  'check' => Icons.check_rounded,
  'delete' => Icons.delete_rounded,
  'edit' => Icons.edit_rounded,
  'arrowBack' => Icons.arrow_back_rounded,
  'arrowForward' => Icons.arrow_forward_rounded,
  'play' => Icons.play_arrow_rounded,
  'pause' => Icons.pause_rounded,
  'info' => Icons.info_rounded,
  'warning' => Icons.warning_rounded,
  'email' => Icons.email_rounded,
  'phone' => Icons.phone_rounded,
  'location' => Icons.location_on_rounded,
  'lock' => Icons.lock_rounded,
  _ => Icons.star_rounded,
};

IconData _iconFor(String name) => switch (name) {
  'view_column' => Icons.view_column_rounded,
  'view_row' => Icons.table_rows_rounded,
  'layers' => Icons.layers_outlined,
  'crop_square' => Icons.crop_square_rounded,
  'filter_center_focus' => Icons.filter_center_focus_rounded,
  'padding' => Icons.padding_rounded,
  'credit_card' => Icons.credit_card_rounded,
  'open_in_full' => Icons.open_in_full_rounded,
  'aspect_ratio' => Icons.aspect_ratio_rounded,
  'space_bar' => Icons.space_bar_rounded,
  'text_fields' => Icons.text_fields_rounded,
  'insert_emoticon' => Icons.insert_emoticon_outlined,
  'image' => Icons.image_outlined,
  'horizontal_rule' => Icons.horizontal_rule_rounded,
  'smart_button' => Icons.smart_button_rounded,
  'edit_note' => Icons.edit_note_rounded,
  'check_box' => Icons.check_box_outlined,
  'toggle_on' => Icons.toggle_on_outlined,
  'tune' => Icons.tune_rounded,
  'view_list' => Icons.view_list_rounded,
  'grid_view' => Icons.grid_view_rounded,
  'swap_vert' => Icons.swap_vert_rounded,
  'progress_activity' => Icons.hourglass_bottom_rounded,
  _ => Icons.widgets_outlined,
};
