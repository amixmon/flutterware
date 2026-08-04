import 'package:flutter/foundation.dart';

enum ProjectThemeMode { system, light, dark }

@immutable
class ProjectThemeSettings {
  const ProjectThemeSettings({
    required this.mode,
    required this.seedColor,
    this.fontFamily,
  });

  final ProjectThemeMode mode;
  final int seedColor;
  final String? fontFamily;

  factory ProjectThemeSettings.fromMap(
    Map<Object?, Object?>? map, {
    required int fallbackColor,
  }) {
    final modeName = map?['mode'] as String?;
    return ProjectThemeSettings(
      mode: ProjectThemeMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => ProjectThemeMode.system,
      ),
      seedColor: (map?['seedColor'] as num?)?.toInt() ?? fallbackColor,
      fontFamily: (map?['fontFamily'] as String?)?.trim().isNotEmpty == true
          ? (map?['fontFamily'] as String).trim()
          : null,
    );
  }

  Map<String, Object?> toMap() => {
    'mode': mode.name,
    'seedColor': seedColor,
    'fontFamily': fontFamily,
  };
}

enum PackageCompatibility {
  pureDart,
  flutter,
  androidPlugin,
  unsupported,
  unknown,
}

@immutable
class ProjectDependency {
  const ProjectDependency({
    required this.name,
    required this.constraint,
    required this.compatibility,
    this.direct = true,
  });

  final String name;
  final String constraint;
  final PackageCompatibility compatibility;
  final bool direct;

  factory ProjectDependency.fromMap(Map<Object?, Object?> map) =>
      ProjectDependency(
        name: map['name'] as String? ?? '',
        constraint: map['constraint'] as String? ?? 'any',
        compatibility: PackageCompatibility.values.firstWhere(
          (value) => value.name == map['compatibility'],
          orElse: () => PackageCompatibility.unknown,
        ),
        direct: map['direct'] as bool? ?? true,
      );

  Map<String, Object?> toMap() => {
    'name': name,
    'constraint': constraint,
    'compatibility': compatibility.name,
    'direct': direct,
  };
}
