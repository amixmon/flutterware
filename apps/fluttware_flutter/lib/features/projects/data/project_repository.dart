import 'dart:convert';

import 'package:flutter/services.dart';

import '../../editor/domain/editor_models.dart';
import '../domain/project_configuration.dart';
import '../domain/project_file.dart';
import '../domain/project_summary.dart';

class ProjectRepository {
  const ProjectRepository();

  static const _channel = MethodChannel('com.flutterware.app/runtime');

  Future<List<ProjectSummary>> list() async {
    final values = await _channel.invokeListMethod<Object?>('listProjects');
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ProjectSummary.fromMap)
        .toList(growable: false);
  }

  Future<ProjectSummary> create({
    required String id,
    required String name,
    required String packageName,
    required int color,
    Uint8List? iconBytes,
  }) async {
    final value = await _channel
        .invokeMapMethod<Object?, Object?>('createProject', {
          'id': id,
          'name': name,
          'packageName': packageName,
          'color': color,
          'iconBytes': ?iconBytes,
        });
    if (value == null) {
      throw StateError('Native project creation returned no data');
    }
    return ProjectSummary.fromMap(value);
  }

  Future<Uint8List?> pickProjectIcon() =>
      _channel.invokeMethod<Uint8List>('pickProjectIcon');

  Future<ProjectAsset?> importAsset({
    required String id,
    required ProjectAssetKind kind,
  }) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'importProjectAsset',
      {'id': id, 'kind': kind.name},
    );
    return value == null ? null : ProjectAsset.fromMap(value);
  }

  Future<ProjectSummary> updateEditor({
    required String id,
    required bool hasButton,
    required String buttonText,
  }) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'updateProjectEditor',
      {'id': id, 'hasButton': hasButton, 'buttonText': buttonText},
    );
    if (value == null) {
      throw StateError('Native project update returned no data');
    }
    return ProjectSummary.fromMap(value);
  }

  Future<List<ProjectDependency>> listDependencies(String id) async {
    final values = await _channel.invokeListMethod<Object?>(
      'listProjectDependencies',
      {'id': id},
    );
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ProjectDependency.fromMap)
        .toList(growable: false);
  }

  Future<List<ProjectDependency>> upsertDependency({
    required String id,
    required ProjectDependency dependency,
  }) async {
    final values = await _channel.invokeListMethod<Object?>(
      'upsertProjectDependency',
      {'id': id, ...dependency.toMap()},
    );
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ProjectDependency.fromMap)
        .toList(growable: false);
  }

  Future<List<ProjectDependency>> removeDependency({
    required String id,
    required String name,
  }) async {
    final values = await _channel.invokeListMethod<Object?>(
      'removeProjectDependency',
      {'id': id, 'name': name},
    );
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ProjectDependency.fromMap)
        .toList(growable: false);
  }

  Future<List<ProjectFile>> listFiles(String id) async {
    final values = await _channel.invokeListMethod<Object?>(
      'listProjectFiles',
      {'id': id},
    );
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ProjectFile.fromMap)
        .toList(growable: false);
  }

  Future<({String content, bool editable})> readFile({
    required String id,
    required String path,
  }) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'readProjectFile',
      {'id': id, 'path': path},
    );
    if (value == null) throw StateError('Native file read returned no data');
    return (
      content: value['content'] as String? ?? '',
      editable: value['editable'] as bool? ?? false,
    );
  }

  Future<void> writeFile({
    required String id,
    required String path,
    required String content,
  }) => _channel.invokeMethod<void>('writeProjectFile', {
    'id': id,
    'path': path,
    'content': content,
  });

  Future<List<CustomWidgetDefinition>> listCustomWidgets(String id) async {
    final values = await _channel.invokeListMethod<Object?>(
      'listCustomWidgets',
      {'id': id},
    );
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(CustomWidgetDefinition.fromMap)
        .toList(growable: false);
  }

  Future<CustomWidgetDefinition> createCustomWidget({
    required String projectId,
    required CustomWidgetDefinition widget,
    bool createFile = true,
  }) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      createFile ? 'createCustomWidget' : 'registerCustomWidget',
      {'id': projectId, ...widget.toJson()},
    );
    if (value == null) {
      throw StateError('Native custom widget creation returned no data');
    }
    return CustomWidgetDefinition.fromMap(value);
  }

  Future<int> counterStep(String id) async {
    final file = await readFile(id: id, path: '.fluttware/logic.json');
    final model = jsonDecode(file.content) as Map<String, Object?>;
    final events = model['events']! as List<Object?>;
    final event = events.first! as Map<String, Object?>;
    final blocks = event['blocks']! as List<Object?>;
    final block = blocks.first! as Map<String, Object?>;
    final expression = block['value']! as Map<String, Object?>;
    final right = expression['right']! as Map<String, Object?>;
    return (right['value'] as num).toInt();
  }

  Future<void> updateCounterStep({required String id, required int step}) =>
      _channel.invokeMethod<void>('updateCounterStep', {
        'id': id,
        'step': step,
      });

  Future<ScreenDesign> readDesign({
    required String id,
    required String projectName,
  }) async {
    final source = await _channel.invokeMethod<String>('readProjectDesign', {
      'id': id,
    });
    if (source == null) return ScreenDesign.fallback(projectName);
    return ScreenDesign.fromJsonString(source);
  }

  Future<void> writeDesign({
    required String id,
    required ScreenDesign design,
  }) => _channel.invokeMethod<void>('writeProjectDesign', {
    'id': id,
    'content': design.toJsonString(),
  });

  Future<String> readLogic(String id) async =>
      await _channel.invokeMethod<String>('readProjectLogic', {'id': id}) ??
      '{"schemaVersion":1,"variables":[],"events":[]}';

  Future<void> writeLogic({required String id, required String content}) =>
      _channel.invokeMethod<void>('writeProjectLogic', {
        'id': id,
        'content': content,
      });
}
