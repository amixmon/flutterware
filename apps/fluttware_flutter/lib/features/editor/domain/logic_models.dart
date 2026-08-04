enum LogicBlockCategory {
  variables,
  control,
  interface,
  navigation,
  data,
  custom,
}

enum LogicFieldKind { text, integer, decimal, choice, code }

Map<String, Object?> renameLogicWidgetId(
  Map<String, Object?> logic, {
  required String from,
  required String to,
}) {
  Object? copyAndRename(Object? value) {
    if (value is List<Object?>) {
      return value.map(copyAndRename).toList(growable: false);
    }
    if (value is! Map<String, Object?>) return value;

    final referencesWidget = value['widgetId'] == from;
    final copy = <String, Object?>{
      for (final entry in value.entries) entry.key: copyAndRename(entry.value),
    };
    if (referencesWidget) {
      copy['widgetId'] = to;
      final eventName = value['event'];
      if (eventName is String &&
          value['id'] == '${from}_${eventName.toLowerCase()}') {
        copy['id'] = '${to}_${eventName.toLowerCase()}';
      }
    }
    return copy;
  }

  return copyAndRename(logic)! as Map<String, Object?>;
}

class LogicFieldDefinition {
  const LogicFieldDefinition({
    required this.key,
    required this.label,
    required this.kind,
    this.defaultValue,
    this.options = const {},
  });

  final String key;
  final String label;
  final LogicFieldKind kind;
  final Object? defaultValue;
  final Map<String, String> options;
}

class LogicBlockDefinition {
  const LogicBlockDefinition({
    required this.type,
    required this.label,
    required this.description,
    required this.category,
    required this.iconName,
    this.fields = const [],
  });

  final String type;
  final String label;
  final String description;
  final LogicBlockCategory category;
  final String iconName;
  final List<LogicFieldDefinition> fields;

  Map<String, Object?> createBlock() => {
    'id': '${type}_${DateTime.now().microsecondsSinceEpoch}',
    'type': type,
    for (final field in fields) field.key: field.defaultValue,
  };
}

class LogicEventRequest {
  const LogicEventRequest(this.widgetId, this.eventName, this.label);
  final String widgetId;
  final String eventName;
  final String label;
  String get key => '$widgetId::$eventName';
}

abstract final class LogicBlockCatalog {
  static const definitions = <LogicBlockDefinition>[
    LogicBlockDefinition(
      type: 'setVariable',
      label: 'Set variable',
      description: 'Assign or change a page variable',
      category: LogicBlockCategory.variables,
      iconName: 'variable',
      fields: [
        LogicFieldDefinition(
          key: 'variableId',
          label: 'Variable',
          kind: LogicFieldKind.choice,
        ),
        LogicFieldDefinition(
          key: 'operation',
          label: 'Operation',
          kind: LogicFieldKind.choice,
          defaultValue: 'set',
          options: {
            'set': 'Set to',
            'add': 'Increase by',
            'subtract': 'Decrease by',
          },
        ),
        LogicFieldDefinition(
          key: 'value',
          label: 'Value',
          kind: LogicFieldKind.text,
          defaultValue: '0',
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'delay',
      label: 'Wait',
      description: 'Pause this event before continuing',
      category: LogicBlockCategory.control,
      iconName: 'timer',
      fields: [
        LogicFieldDefinition(
          key: 'milliseconds',
          label: 'Milliseconds',
          kind: LogicFieldKind.integer,
          defaultValue: 500,
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'stopEvent',
      label: 'Stop event',
      description: 'Return immediately from this event',
      category: LogicBlockCategory.control,
      iconName: 'stop',
    ),
    LogicBlockDefinition(
      type: 'showSnackBar',
      label: 'Show message',
      description: 'Show a Material SnackBar',
      category: LogicBlockCategory.interface,
      iconName: 'message',
      fields: [
        LogicFieldDefinition(
          key: 'message',
          label: 'Message',
          kind: LogicFieldKind.text,
          defaultValue: 'Hello from Flutterware',
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'showDialog',
      label: 'Show dialog',
      description: 'Open a Material alert dialog',
      category: LogicBlockCategory.interface,
      iconName: 'dialog',
      fields: [
        LogicFieldDefinition(
          key: 'title',
          label: 'Title',
          kind: LogicFieldKind.text,
          defaultValue: 'Notice',
        ),
        LogicFieldDefinition(
          key: 'message',
          label: 'Message',
          kind: LogicFieldKind.text,
          defaultValue: 'Dialog message',
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'navigate',
      label: 'Open page',
      description: 'Push another generated page',
      category: LogicBlockCategory.navigation,
      iconName: 'open',
      fields: [
        LogicFieldDefinition(
          key: 'route',
          label: 'Page',
          kind: LogicFieldKind.choice,
          defaultValue: '/',
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'pop',
      label: 'Go back',
      description: 'Close the current page',
      category: LogicBlockCategory.navigation,
      iconName: 'back',
    ),
    LogicBlockDefinition(
      type: 'log',
      label: 'Debug log',
      description: 'Write a message to the debug console',
      category: LogicBlockCategory.data,
      iconName: 'terminal',
      fields: [
        LogicFieldDefinition(
          key: 'message',
          label: 'Message',
          kind: LogicFieldKind.text,
          defaultValue: 'Flutterware log',
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'customAction',
      label: 'Named action',
      description: 'Call a user-owned action handler',
      category: LogicBlockCategory.custom,
      iconName: 'bolt',
      fields: [
        LogicFieldDefinition(
          key: 'name',
          label: 'Action name',
          kind: LogicFieldKind.text,
          defaultValue: 'action',
        ),
      ],
    ),
    LogicBlockDefinition(
      type: 'customCode',
      label: 'Dart code',
      description: 'Insert advanced Dart statements',
      category: LogicBlockCategory.custom,
      iconName: 'code',
      fields: [
        LogicFieldDefinition(
          key: 'code',
          label: 'Dart statements',
          kind: LogicFieldKind.code,
          defaultValue: '// Advanced Dart code',
        ),
      ],
    ),
  ];

  static LogicBlockDefinition byType(String type) => definitions.firstWhere(
    (definition) => definition.type == type,
    orElse: () => definitions.last,
  );
}
