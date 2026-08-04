import 'package:flutter/foundation.dart';

enum ProjectThemeMode { system, light, dark }

@immutable
class ProjectThemeSettings {
  const ProjectThemeSettings({
    required this.mode,
    required this.seedColor,
    this.fontFamily,
    this.cornerRadius = 16,
    this.cardElevation = 0,
    this.inputFilled = true,
  });

  final ProjectThemeMode mode;
  final int seedColor;
  final String? fontFamily;
  final double cornerRadius;
  final double cardElevation;
  final bool inputFilled;

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
      cornerRadius: (map?['cornerRadius'] as num?)?.toDouble() ?? 16,
      cardElevation: (map?['cardElevation'] as num?)?.toDouble() ?? 0,
      inputFilled: map?['inputFilled'] as bool? ?? true,
    );
  }

  ProjectThemeSettings copyWith({
    ProjectThemeMode? mode,
    int? seedColor,
    String? fontFamily,
    bool clearFontFamily = false,
    double? cornerRadius,
    double? cardElevation,
    bool? inputFilled,
  }) => ProjectThemeSettings(
    mode: mode ?? this.mode,
    seedColor: seedColor ?? this.seedColor,
    fontFamily: clearFontFamily ? null : fontFamily ?? this.fontFamily,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    cardElevation: cardElevation ?? this.cardElevation,
    inputFilled: inputFilled ?? this.inputFilled,
  );

  Map<String, Object?> toMap() => {
    'mode': mode.name,
    'seedColor': seedColor,
    'fontFamily': fontFamily,
    'cornerRadius': cornerRadius,
    'cardElevation': cardElevation,
    'inputFilled': inputFilled,
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
