import 'package:flutter/foundation.dart';

import '../../projects/domain/project_configuration.dart';

@immutable
class PubPackageSummary {
  const PubPackageSummary({required this.name});

  final String name;

  factory PubPackageSummary.fromJson(Map<String, Object?> json) =>
      PubPackageSummary(name: json['package'] as String? ?? '');
}

@immutable
class PubPackageDetails {
  const PubPackageDetails({
    required this.name,
    required this.version,
    required this.description,
    required this.compatibility,
    this.homepage,
  });

  final String name;
  final String version;
  final String description;
  final String? homepage;
  final PackageCompatibility compatibility;

  bool get canAdd => compatibility != PackageCompatibility.unsupported;

  String get compatibilityLabel => switch (compatibility) {
    PackageCompatibility.pureDart => 'Pure Dart',
    PackageCompatibility.flutter => 'Flutter',
    PackageCompatibility.androidPlugin => 'Android plugin',
    PackageCompatibility.unsupported => 'Not Android-compatible',
    PackageCompatibility.unknown => 'Compatibility unknown',
  };

  factory PubPackageDetails.fromJson(Map<String, Object?> json) {
    final latest = _objectMap(json['latest']);
    final pubspec = _objectMap(latest['pubspec']);
    return PubPackageDetails(
      name: json['name'] as String? ?? pubspec['name'] as String? ?? '',
      version: latest['version'] as String? ?? '',
      description: pubspec['description'] as String? ?? '',
      homepage: (pubspec['homepage'] as String?)?.trim().isNotEmpty == true
          ? (pubspec['homepage'] as String).trim()
          : null,
      compatibility: classifyPubPackage(pubspec),
    );
  }
}

PackageCompatibility classifyPubPackage(Map<String, Object?> pubspec) {
  final flutter = _objectMap(pubspec['flutter']);
  final plugin = _objectMap(flutter['plugin']);
  if (plugin.isNotEmpty) {
    final platforms = _objectMap(plugin['platforms']);
    return platforms.containsKey('android')
        ? PackageCompatibility.androidPlugin
        : PackageCompatibility.unsupported;
  }

  final dependencies = _objectMap(pubspec['dependencies']);
  final environment = _objectMap(pubspec['environment']);
  if (dependencies.containsKey('flutter') ||
      environment.containsKey('flutter')) {
    return PackageCompatibility.flutter;
  }
  return PackageCompatibility.pureDart;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value));
}
