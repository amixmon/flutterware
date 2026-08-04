class ProjectFile {
  const ProjectFile({
    required this.path,
    required this.name,
    required this.directory,
    required this.generated,
    required this.editable,
    required this.openable,
    required this.size,
  });

  final String path;
  final String name;
  final bool directory;
  final bool generated;
  final bool editable;
  final bool openable;
  final int size;

  int get depth => '/'.allMatches(path).length;
  String get parentPath =>
      path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';

  factory ProjectFile.fromMap(Map<Object?, Object?> map) => ProjectFile(
    path: map['path'] as String,
    name: map['name'] as String,
    directory: map['directory'] as bool? ?? false,
    generated: map['generated'] as bool? ?? false,
    editable: map['editable'] as bool? ?? false,
    openable: map['openable'] as bool? ?? false,
    size: (map['size'] as num?)?.toInt() ?? 0,
  );
}

enum ProjectAssetKind { image, font, sound, file }

class ProjectAsset {
  const ProjectAsset({
    required this.path,
    required this.name,
    required this.kind,
    required this.size,
  });

  final String path;
  final String name;
  final ProjectAssetKind kind;
  final int size;

  factory ProjectAsset.fromMap(Map<Object?, Object?> map) => ProjectAsset(
    path: map['path'] as String,
    name: map['name'] as String,
    kind: ProjectAssetKind.values.firstWhere(
      (value) => value.name == map['kind'],
      orElse: () => ProjectAssetKind.file,
    ),
    size: (map['size'] as num?)?.toInt() ?? 0,
  );
}
