import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RuntimeSnapshot {
  const RuntimeSnapshot({
    this.phase = 'idle',
    this.message = 'Ready',
    this.busy = false,
    this.progress = 0,
    this.apkPath,
    this.packageName,
    this.projectId,
    this.error,
    this.logs = const [],
  });

  final String phase;
  final String message;
  final bool busy;
  final double progress;
  final String? apkPath;
  final String? packageName;
  final String? projectId;
  final String? error;
  final List<String> logs;

  bool get completed => phase == 'completed' || phase == 'installed';

  factory RuntimeSnapshot.fromMap(Map<Object?, Object?> map) {
    return RuntimeSnapshot(
      phase: map['phase'] as String? ?? 'idle',
      message: map['message'] as String? ?? 'Ready',
      busy: map['busy'] as bool? ?? false,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      apkPath: map['apkPath'] as String?,
      packageName: map['packageName'] as String?,
      projectId: map['projectId'] as String?,
      error: map['error'] as String?,
      logs: (map['logs'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  RuntimeSnapshot withLog(String line) {
    final updated = [...logs, line];
    return RuntimeSnapshot(
      phase: phase,
      message: message,
      busy: busy,
      progress: progress,
      apkPath: apkPath,
      packageName: packageName,
      projectId: projectId,
      error: error,
      logs: updated.length > 300
          ? updated.sublist(updated.length - 300)
          : updated,
    );
  }
}

class RuntimeController extends ChangeNotifier {
  RuntimeController._();

  static final RuntimeController instance = RuntimeController._();
  static const _methods = MethodChannel('com.flutterware.app/runtime');
  static const _events = EventChannel('com.flutterware.app/runtime_events');

  RuntimeSnapshot _snapshot = const RuntimeSnapshot();
  StreamSubscription<Object?>? _subscription;

  RuntimeSnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    _subscription ??= _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error) {
        debugPrint('Runtime event error: $error');
      },
    );
    final state = await _methods.invokeMapMethod<Object?, Object?>(
      'getRuntimeState',
    );
    if (state != null) _applyState(state);
  }

  Future<void> startCreateBuild({
    required String projectId,
    required String projectName,
    required String packageName,
  }) async {
    await _methods.invokeMethod<Object?>('startCreateBuild', {
      'projectId': projectId,
      'projectName': projectName,
      'packageName': packageName,
    });
  }

  Future<void> cancelBuild() => _methods.invokeMethod<void>('cancelBuild');

  Future<bool> installAndLaunch() async {
    final response = await _methods.invokeMapMethod<Object?, Object?>(
      'installAndLaunch',
    );
    return response?['permissionRequired'] == true;
  }

  void _handleEvent(Object? event) {
    if (event is! Map<Object?, Object?>) return;
    if (event['type'] == 'log') {
      final line = event['line'];
      if (line is String) {
        _snapshot = _snapshot.withLog(line);
        notifyListeners();
      }
      return;
    }
    _applyState(event);
  }

  void _applyState(Map<Object?, Object?> state) {
    _snapshot = RuntimeSnapshot.fromMap(state);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
