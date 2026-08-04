import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'project_configuration.dart';

@immutable
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.packageName,
    required this.modifiedLabel,
    required this.color,
    this.schemaVersion = 1,
    this.theme = const ProjectThemeSettings(
      mode: ProjectThemeMode.system,
      seedColor: 0xFF168CF3,
    ),
    this.dependencies = const [],
    this.iconBytes,
    this.pinned = false,
    this.hasButton = false,
    this.buttonText = 'Button',
  });

  final String id;
  final String name;
  final String packageName;
  final String modifiedLabel;
  final Color color;
  final int schemaVersion;
  final ProjectThemeSettings theme;
  final List<ProjectDependency> dependencies;
  final Uint8List? iconBytes;
  final bool pinned;
  final bool hasButton;
  final String buttonText;

  factory ProjectSummary.fromMap(Map<Object?, Object?> map) {
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      (map['updatedAt'] as num?)?.toInt() ?? 0,
    );
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    final modifiedLabel = difference.inMinutes < 2
        ? 'Edited just now'
        : difference.inHours < 24
        ? 'Edited ${difference.inHours}h ago'
        : 'Edited ${difference.inDays}d ago';
    final color = (map['color'] as num?)?.toInt() ?? 0xFF168CF3;
    return ProjectSummary(
      id: map['id'] as String,
      name: map['name'] as String,
      packageName: map['packageName'] as String,
      modifiedLabel: modifiedLabel,
      color: Color(color),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      theme: ProjectThemeSettings.fromMap(
        map['theme'] as Map<Object?, Object?>?,
        fallbackColor: color,
      ),
      dependencies: (map['dependencies'] as List<Object?>? ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(ProjectDependency.fromMap)
          .toList(growable: false),
      iconBytes: _iconBytes(map['iconBytes']),
      pinned: map['pinned'] as bool? ?? false,
      hasButton: map['hasButton'] as bool? ?? false,
      buttonText: map['buttonText'] as String? ?? 'Button',
    );
  }

  ProjectSummary copyWith({
    Color? color,
    ProjectThemeSettings? theme,
    Uint8List? iconBytes,
    bool? pinned,
    bool? hasButton,
    String? buttonText,
    String? modifiedLabel,
  }) {
    return ProjectSummary(
      id: id,
      name: name,
      packageName: packageName,
      modifiedLabel: modifiedLabel ?? this.modifiedLabel,
      color: color ?? this.color,
      schemaVersion: schemaVersion,
      theme: theme ?? this.theme,
      dependencies: dependencies,
      iconBytes: iconBytes ?? this.iconBytes,
      pinned: pinned ?? this.pinned,
      hasButton: hasButton ?? this.hasButton,
      buttonText: buttonText ?? this.buttonText,
    );
  }

  static Uint8List? _iconBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) {
      final bytes = value.whereType<num>().map((item) => item.toInt()).toList();
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    }
    return null;
  }
}
