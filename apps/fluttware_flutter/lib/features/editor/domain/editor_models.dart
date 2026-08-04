import 'dart:convert';

class WidgetNode {
  const WidgetNode({
    required this.id,
    required this.type,
    this.properties = const {},
    this.children = const [],
  });

  final String id;
  final String type;
  final Map<String, Object?> properties;
  final List<WidgetNode> children;

  factory WidgetNode.fromJson(Map<String, Object?> json) => WidgetNode(
    id: json['id'] as String,
    type: json['type'] as String,
    properties: Map<String, Object?>.from(
      json['properties'] as Map<String, Object?>? ?? const {},
    ),
    children: (json['children'] as List<Object?>? ?? const [])
        .cast<Map<String, Object?>>()
        .map(WidgetNode.fromJson)
        .toList(growable: false),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'properties': properties,
    'children': children.map((child) => child.toJson()).toList(),
  };

  WidgetNode copyWith({
    String? id,
    String? type,
    Map<String, Object?>? properties,
    List<WidgetNode>? children,
  }) => WidgetNode(
    id: id ?? this.id,
    type: type ?? this.type,
    properties: properties ?? this.properties,
    children: children ?? this.children,
  );

  WidgetNode? find(String nodeId) {
    if (id == nodeId) return this;
    for (final child in children) {
      final result = child.find(nodeId);
      if (result != null) return result;
    }
    return null;
  }

  WidgetNode update(String nodeId, WidgetNode replacement) {
    if (id == nodeId) return replacement;
    return copyWith(
      children: children
          .map((child) => child.update(nodeId, replacement))
          .toList(growable: false),
    );
  }

  WidgetNode remove(String nodeId) => copyWith(
    children: children
        .where((child) => child.id != nodeId)
        .map((child) => child.remove(nodeId))
        .toList(growable: false),
  );

  bool contains(String nodeId) => find(nodeId) != null;
}

class ScaffoldSlot {
  const ScaffoldSlot({required this.enabled, this.properties = const {}});

  final bool enabled;
  final Map<String, Object?> properties;

  factory ScaffoldSlot.fromJson(Map<String, Object?>? json) => ScaffoldSlot(
    enabled: json?['enabled'] as bool? ?? false,
    properties: Map<String, Object?>.from(
      json?['properties'] as Map<String, Object?>? ?? const {},
    ),
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'properties': properties,
  };

  ScaffoldSlot copyWith({bool? enabled, Map<String, Object?>? properties}) =>
      ScaffoldSlot(
        enabled: enabled ?? this.enabled,
        properties: properties ?? this.properties,
      );
}

class CustomWidgetParameter {
  const CustomWidgetParameter({
    required this.name,
    required this.type,
    this.defaultValue = '',
  });

  final String name;
  final String type;
  final String defaultValue;

  factory CustomWidgetParameter.fromJson(Map<String, Object?> json) =>
      CustomWidgetParameter(
        name: json['name'] as String? ?? 'value',
        type: json['type'] as String? ?? 'String',
        defaultValue: json['defaultValue'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    'defaultValue': defaultValue,
  };
}

class CustomWidgetDefinition {
  const CustomWidgetDefinition({
    required this.id,
    required this.name,
    required this.className,
    required this.path,
    this.parameters = const [],
    this.arguments = const {},
  });

  final String id;
  final String name;
  final String className;
  final String path;
  final List<CustomWidgetParameter> parameters;
  final Map<String, String> arguments;

  factory CustomWidgetDefinition.fromJson(Map<String, Object?> json) =>
      CustomWidgetDefinition(
        id: json['id'] as String? ?? 'custom_widget',
        name: json['name'] as String? ?? 'Custom widget',
        className: json['className'] as String? ?? 'CustomWidget',
        path: json['path'] as String? ?? 'lib/custom/custom_widget.dart',
        parameters: (json['parameters'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .map(CustomWidgetParameter.fromJson)
            .toList(growable: false),
        arguments: Map<String, String>.from(
          json['arguments'] as Map<String, Object?>? ?? const {},
        ),
      );

  factory CustomWidgetDefinition.fromMap(Map<Object?, Object?> value) =>
      CustomWidgetDefinition.fromJson(
        jsonDecode(jsonEncode(value)) as Map<String, Object?>,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'className': className,
    'path': path,
    'parameters': parameters.map((item) => item.toJson()).toList(),
    'arguments': arguments,
  };

  CustomWidgetDefinition copyWith({Map<String, String>? arguments}) =>
      CustomWidgetDefinition(
        id: id,
        name: name,
        className: className,
        path: path,
        parameters: parameters,
        arguments: arguments ?? this.arguments,
      );
}

class PageDesign {
  const PageDesign({
    required this.id,
    required this.name,
    required this.route,
    required this.appBar,
    required this.floatingActionButton,
    required this.body,
    this.customUi,
  });

  final String id;
  final String name;
  final String route;
  final ScaffoldSlot appBar;
  final ScaffoldSlot floatingActionButton;
  final WidgetNode body;
  final CustomWidgetDefinition? customUi;

  factory PageDesign.fromJson(Map<String, Object?> json) => PageDesign(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Page',
    route: json['route'] as String? ?? '/',
    appBar: ScaffoldSlot.fromJson(json['appBar'] as Map<String, Object?>?),
    floatingActionButton: ScaffoldSlot.fromJson(
      json['floatingActionButton'] as Map<String, Object?>?,
    ),
    body: WidgetNode.fromJson(json['body']! as Map<String, Object?>),
    customUi: switch (json['customUi']) {
      final Map<String, Object?> value => CustomWidgetDefinition.fromJson(
        value,
      ),
      _ => null,
    },
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'route': route,
    'appBar': appBar.toJson(),
    'floatingActionButton': floatingActionButton.toJson(),
    'body': body.toJson(),
    'customUi': customUi?.toJson(),
  };

  PageDesign copyWith({
    String? id,
    String? name,
    String? route,
    ScaffoldSlot? appBar,
    ScaffoldSlot? floatingActionButton,
    WidgetNode? body,
    CustomWidgetDefinition? customUi,
    bool removeCustomUi = false,
  }) => PageDesign(
    id: id ?? this.id,
    name: name ?? this.name,
    route: route ?? this.route,
    appBar: appBar ?? this.appBar,
    floatingActionButton: floatingActionButton ?? this.floatingActionButton,
    body: body ?? this.body,
    customUi: removeCustomUi ? null : customUi ?? this.customUi,
  );
}

class ScreenDesign {
  const ScreenDesign({
    required this.pages,
    required this.initialPageId,
    this.schemaVersion = 3,
  });

  final int schemaVersion;
  final List<PageDesign> pages;
  final String initialPageId;

  PageDesign get initialPage => pages.firstWhere(
    (page) => page.id == initialPageId,
    orElse: () => pages.first,
  );

  // Compatibility helpers for code that operates on the initial page.
  ScaffoldSlot get appBar => initialPage.appBar;
  ScaffoldSlot get floatingActionButton => initialPage.floatingActionButton;
  WidgetNode get body => initialPage.body;

  factory ScreenDesign.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    if ((json['schemaVersion'] as num?)?.toInt() == 3) {
      final pages = (json['pages'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(PageDesign.fromJson)
          .toList(growable: false);
      if (pages.isNotEmpty) {
        return ScreenDesign(
          pages: pages,
          initialPageId: json['initialPageId'] as String? ?? pages.first.id,
        );
      }
    }
    if ((json['schemaVersion'] as num?)?.toInt() == 2) {
      final screen = json['screen']! as Map<String, Object?>;
      return ScreenDesign(
        initialPageId: 'home',
        pages: [
          PageDesign(
            id: screen['id'] as String? ?? 'home',
            name: 'Home',
            route: screen['route'] as String? ?? '/',
            appBar: ScaffoldSlot.fromJson(
              screen['appBar'] as Map<String, Object?>?,
            ),
            floatingActionButton: ScaffoldSlot.fromJson(
              screen['floatingActionButton'] as Map<String, Object?>?,
            ),
            body: WidgetNode.fromJson(screen['body']! as Map<String, Object?>),
          ),
        ],
      );
    }
    return ScreenDesign.fallback('Flutter App');
  }

  factory ScreenDesign.fallback(String projectName) => ScreenDesign(
    initialPageId: 'home',
    pages: [
      PageDesign(
        id: 'home',
        name: 'Home',
        route: '/',
        appBar: ScaffoldSlot(enabled: true, properties: {'title': projectName}),
        floatingActionButton: const ScaffoldSlot(
          enabled: true,
          properties: {
            'id': 'counter_fab',
            'icon': 'add',
            'tooltip': 'Increment',
          },
        ),
        body: const WidgetNode(
          id: 'root_column',
          type: 'column',
          properties: {
            'mainAxisAlignment': 'start',
            'crossAxisAlignment': 'start',
          },
          children: [
            WidgetNode(
              id: 'counter_label',
              type: 'text',
              properties: {
                'text': 'You have pushed the button this many times:',
                'textAlign': 'center',
              },
            ),
            WidgetNode(
              id: 'counter_value',
              type: 'text',
              properties: {'binding': 'counter', 'style': 'headlineMedium'},
            ),
          ],
        ),
      ),
    ],
  );

  String toJsonString() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 3,
    'initialPageId': initialPageId,
    'pages': pages.map((page) => page.toJson()).toList(),
  });

  ScreenDesign copyWith({
    List<PageDesign>? pages,
    String? initialPageId,
    ScaffoldSlot? appBar,
    ScaffoldSlot? floatingActionButton,
    WidgetNode? body,
  }) {
    final nextPages = pages ?? this.pages;
    if (appBar == null && floatingActionButton == null && body == null) {
      return ScreenDesign(
        pages: nextPages,
        initialPageId: initialPageId ?? this.initialPageId,
      );
    }
    final updated = nextPages
        .map(
          (page) => page.id == this.initialPageId
              ? page.copyWith(
                  appBar: appBar,
                  floatingActionButton: floatingActionButton,
                  body: body,
                )
              : page,
        )
        .toList(growable: false);
    return ScreenDesign(
      pages: updated,
      initialPageId: initialPageId ?? this.initialPageId,
    );
  }

  ScreenDesign updatePage(PageDesign page) => copyWith(
    pages: pages
        .map((item) => item.id == page.id ? page : item)
        .toList(growable: false),
  );
}

enum WidgetCategory { layout, content, input, scrolling, feedback }

enum PropertyKind { text, number, integer, toggle, choice, color }

class PropertyDefinition {
  const PropertyDefinition({
    required this.key,
    required this.label,
    required this.kind,
    this.options = const {},
    this.min,
    this.max,
    this.defaultValue,
  });
  final String key;
  final String label;
  final PropertyKind kind;
  final Map<String, String> options;
  final double? min;
  final double? max;
  final Object? defaultValue;
}

class EventDefinition {
  const EventDefinition({required this.name, required this.label});
  final String name;
  final String label;
}

class WidgetDefinition {
  const WidgetDefinition({
    required this.type,
    required this.label,
    required this.category,
    required this.iconName,
    this.acceptsChildren = false,
    this.maxChildren,
    this.defaultProperties = const {},
    this.properties = const [],
    this.events = const [],
  });

  final String type;
  final String label;
  final WidgetCategory category;
  final String iconName;
  final bool acceptsChildren;
  final int? maxChildren;
  final Map<String, Object?> defaultProperties;
  final List<PropertyDefinition> properties;
  final List<EventDefinition> events;
}

abstract final class WidgetCatalog {
  static const definitions = <WidgetDefinition>[
    WidgetDefinition(
      type: 'column',
      label: 'Column',
      category: WidgetCategory.layout,
      iconName: 'view_column',
      acceptsChildren: true,
      defaultProperties: {
        'mainAxisAlignment': 'start',
        'crossAxisAlignment': 'start',
      },
      properties: [
        PropertyDefinition(
          key: 'mainAxisAlignment',
          label: 'Main alignment',
          kind: PropertyKind.choice,
          options: {
            'start': 'Start',
            'center': 'Center',
            'end': 'End',
            'spaceBetween': 'Space between',
            'spaceAround': 'Space around',
            'spaceEvenly': 'Space evenly',
          },
        ),
        PropertyDefinition(
          key: 'crossAxisAlignment',
          label: 'Cross alignment',
          kind: PropertyKind.choice,
          options: {
            'start': 'Start',
            'center': 'Center',
            'end': 'End',
            'stretch': 'Stretch',
          },
        ),
      ],
    ),
    WidgetDefinition(
      type: 'row',
      label: 'Row',
      category: WidgetCategory.layout,
      iconName: 'view_row',
      acceptsChildren: true,
      defaultProperties: {
        'mainAxisAlignment': 'start',
        'crossAxisAlignment': 'start',
      },
      properties: [
        PropertyDefinition(
          key: 'mainAxisAlignment',
          label: 'Main alignment',
          kind: PropertyKind.choice,
          options: {
            'start': 'Start',
            'center': 'Center',
            'end': 'End',
            'spaceBetween': 'Space between',
            'spaceAround': 'Space around',
            'spaceEvenly': 'Space evenly',
          },
        ),
        PropertyDefinition(
          key: 'crossAxisAlignment',
          label: 'Cross alignment',
          kind: PropertyKind.choice,
          options: {
            'start': 'Start',
            'center': 'Center',
            'end': 'End',
            'stretch': 'Stretch',
          },
        ),
      ],
    ),
    WidgetDefinition(
      type: 'stack',
      label: 'Stack',
      category: WidgetCategory.layout,
      iconName: 'layers',
      acceptsChildren: true,
    ),
    WidgetDefinition(
      type: 'container',
      label: 'Container',
      category: WidgetCategory.layout,
      iconName: 'crop_square',
      acceptsChildren: true,
      maxChildren: 1,
      defaultProperties: {'padding': 12.0, 'width': 0.0, 'height': 0.0},
      properties: [
        PropertyDefinition(
          key: 'padding',
          label: 'Padding',
          kind: PropertyKind.number,
          min: 0,
          max: 96,
        ),
        PropertyDefinition(
          key: 'width',
          label: 'Width (0 = auto)',
          kind: PropertyKind.number,
          min: 0,
          max: 1000,
        ),
        PropertyDefinition(
          key: 'height',
          label: 'Height (0 = auto)',
          kind: PropertyKind.number,
          min: 0,
          max: 1000,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'center',
      label: 'Center',
      category: WidgetCategory.layout,
      iconName: 'filter_center_focus',
      acceptsChildren: true,
      maxChildren: 1,
    ),
    WidgetDefinition(
      type: 'padding',
      label: 'Padding',
      category: WidgetCategory.layout,
      iconName: 'padding',
      acceptsChildren: true,
      maxChildren: 1,
      defaultProperties: {'padding': 16.0},
      properties: [
        PropertyDefinition(
          key: 'padding',
          label: 'Padding',
          kind: PropertyKind.number,
          min: 0,
          max: 96,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'card',
      label: 'Card',
      category: WidgetCategory.layout,
      iconName: 'credit_card',
      acceptsChildren: true,
      maxChildren: 1,
      defaultProperties: {'elevation': 1.0},
      properties: [
        PropertyDefinition(
          key: 'elevation',
          label: 'Elevation',
          kind: PropertyKind.number,
          min: 0,
          max: 24,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'expanded',
      label: 'Expanded',
      category: WidgetCategory.layout,
      iconName: 'open_in_full',
      acceptsChildren: true,
      maxChildren: 1,
      defaultProperties: {'flex': 1},
      properties: [
        PropertyDefinition(
          key: 'flex',
          label: 'Flex',
          kind: PropertyKind.integer,
          min: 1,
          max: 12,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'sizedBox',
      label: 'SizedBox',
      category: WidgetCategory.layout,
      iconName: 'aspect_ratio',
      defaultProperties: {'width': 16.0, 'height': 16.0},
      properties: [
        PropertyDefinition(
          key: 'width',
          label: 'Width',
          kind: PropertyKind.number,
          min: 0,
          max: 1000,
        ),
        PropertyDefinition(
          key: 'height',
          label: 'Height',
          kind: PropertyKind.number,
          min: 0,
          max: 1000,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'spacer',
      label: 'Spacer',
      category: WidgetCategory.layout,
      iconName: 'space_bar',
      defaultProperties: {'flex': 1},
      properties: [
        PropertyDefinition(
          key: 'flex',
          label: 'Flex',
          kind: PropertyKind.integer,
          min: 1,
          max: 12,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'text',
      label: 'Text',
      category: WidgetCategory.content,
      iconName: 'text_fields',
      defaultProperties: {
        'text': 'Text',
        'textAlign': 'left',
        'style': 'bodyLarge',
      },
      properties: [
        PropertyDefinition(key: 'text', label: 'Text', kind: PropertyKind.text),
        PropertyDefinition(
          key: 'textAlign',
          label: 'Alignment',
          kind: PropertyKind.choice,
          options: {
            'left': 'Left',
            'center': 'Center',
            'right': 'Right',
            'justify': 'Justify',
          },
        ),
        PropertyDefinition(
          key: 'style',
          label: 'Text style',
          kind: PropertyKind.choice,
          options: {
            'bodySmall': 'Body small',
            'bodyMedium': 'Body medium',
            'bodyLarge': 'Body large',
            'titleMedium': 'Title',
            'headlineSmall': 'Headline',
          },
        ),
      ],
    ),
    WidgetDefinition(
      type: 'icon',
      label: 'Icon',
      category: WidgetCategory.content,
      iconName: 'insert_emoticon',
      defaultProperties: {'icon': 'star', 'size': 32.0},
      properties: [
        PropertyDefinition(
          key: 'icon',
          label: 'Material icon',
          kind: PropertyKind.choice,
          options: {
            'star': 'Star',
            'add': 'Add',
            'home': 'Home',
            'menu': 'Menu',
            'favorite': 'Favorite',
            'settings': 'Settings',
            'person': 'Person',
            'search': 'Search',
          },
        ),
        PropertyDefinition(
          key: 'size',
          label: 'Size',
          kind: PropertyKind.number,
          min: 8,
          max: 200,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'image',
      label: 'Image',
      category: WidgetCategory.content,
      iconName: 'image',
      defaultProperties: {'asset': '', 'width': 120.0, 'height': 120.0},
      properties: [
        PropertyDefinition(
          key: 'asset',
          label: 'Asset path',
          kind: PropertyKind.text,
        ),
        PropertyDefinition(
          key: 'width',
          label: 'Width',
          kind: PropertyKind.number,
          min: 1,
          max: 1000,
        ),
        PropertyDefinition(
          key: 'height',
          label: 'Height',
          kind: PropertyKind.number,
          min: 1,
          max: 1000,
        ),
        PropertyDefinition(
          key: 'fit',
          label: 'Fit',
          kind: PropertyKind.choice,
          options: {
            'cover': 'Cover',
            'contain': 'Contain',
            'fill': 'Fill',
            'fitWidth': 'Fit width',
            'fitHeight': 'Fit height',
          },
        ),
      ],
    ),
    WidgetDefinition(
      type: 'divider',
      label: 'Divider',
      category: WidgetCategory.content,
      iconName: 'horizontal_rule',
    ),
    WidgetDefinition(
      type: 'button',
      label: 'Button',
      category: WidgetCategory.input,
      iconName: 'smart_button',
      defaultProperties: {
        'text': 'Button',
        'variant': 'filled',
        'widthMode': 'auto',
        'width': 160.0,
        'height': 48.0,
        'enabled': true,
      },
      properties: [
        PropertyDefinition(
          key: 'text',
          label: 'Label',
          kind: PropertyKind.text,
        ),
        PropertyDefinition(
          key: 'variant',
          label: 'Button type',
          kind: PropertyKind.choice,
          options: {
            'filled': 'Filled',
            'tonal': 'Filled tonal',
            'elevated': 'Elevated',
            'outlined': 'Outlined',
            'text': 'Text',
          },
        ),
        PropertyDefinition(
          key: 'icon',
          label: 'Icon',
          kind: PropertyKind.choice,
          defaultValue: 'none',
          options: {
            'none': 'None',
            'add': 'Add',
            'check': 'Check',
            'close': 'Close',
            'edit': 'Edit',
            'delete': 'Delete',
            'favorite': 'Favorite',
            'play': 'Play',
            'arrowForward': 'Arrow forward',
          },
        ),
        PropertyDefinition(
          key: 'widthMode',
          label: 'Width',
          kind: PropertyKind.choice,
          options: {
            'auto': 'Fit content',
            'full': 'Full width',
            'fixed': 'Fixed',
          },
        ),
        PropertyDefinition(
          key: 'width',
          label: 'Fixed width',
          kind: PropertyKind.number,
          min: 48,
          max: 1000,
        ),
        PropertyDefinition(
          key: 'height',
          label: 'Height',
          kind: PropertyKind.number,
          min: 32,
          max: 120,
        ),
        PropertyDefinition(
          key: 'enabled',
          label: 'Enabled',
          kind: PropertyKind.toggle,
        ),
      ],
      events: [
        EventDefinition(name: 'onPressed', label: 'On tap'),
        EventDefinition(name: 'onLongPress', label: 'On long press'),
      ],
    ),
    WidgetDefinition(
      type: 'textField',
      label: 'Text field',
      category: WidgetCategory.input,
      iconName: 'edit_note',
      defaultProperties: {
        'label': 'Input',
        'hint': '',
        'keyboardType': 'text',
        'obscureText': false,
      },
      properties: [
        PropertyDefinition(
          key: 'label',
          label: 'Label',
          kind: PropertyKind.text,
        ),
        PropertyDefinition(key: 'hint', label: 'Hint', kind: PropertyKind.text),
        PropertyDefinition(
          key: 'keyboardType',
          label: 'Keyboard',
          kind: PropertyKind.choice,
          options: {
            'text': 'Text',
            'number': 'Number',
            'email': 'Email',
            'phone': 'Phone',
          },
        ),
        PropertyDefinition(
          key: 'obscureText',
          label: 'Password field',
          kind: PropertyKind.toggle,
        ),
      ],
      events: [
        EventDefinition(name: 'onChanged', label: 'On changed'),
        EventDefinition(name: 'onSubmitted', label: 'On submitted'),
      ],
    ),
    WidgetDefinition(
      type: 'checkbox',
      label: 'Checkbox',
      category: WidgetCategory.input,
      iconName: 'check_box',
      defaultProperties: {'label': 'Checkbox', 'value': false},
      properties: [
        PropertyDefinition(
          key: 'label',
          label: 'Label',
          kind: PropertyKind.text,
        ),
        PropertyDefinition(
          key: 'value',
          label: 'Checked',
          kind: PropertyKind.toggle,
        ),
      ],
      events: [EventDefinition(name: 'onChanged', label: 'On changed')],
    ),
    WidgetDefinition(
      type: 'switch',
      label: 'Switch',
      category: WidgetCategory.input,
      iconName: 'toggle_on',
      defaultProperties: {'label': 'Switch', 'value': false},
      properties: [
        PropertyDefinition(
          key: 'label',
          label: 'Label',
          kind: PropertyKind.text,
        ),
        PropertyDefinition(
          key: 'value',
          label: 'On',
          kind: PropertyKind.toggle,
        ),
      ],
      events: [EventDefinition(name: 'onChanged', label: 'On changed')],
    ),
    WidgetDefinition(
      type: 'slider',
      label: 'Slider',
      category: WidgetCategory.input,
      iconName: 'tune',
      defaultProperties: {'value': 0.5},
      properties: [
        PropertyDefinition(
          key: 'value',
          label: 'Value',
          kind: PropertyKind.number,
          min: 0,
          max: 1,
        ),
      ],
      events: [EventDefinition(name: 'onChanged', label: 'On changed')],
    ),
    WidgetDefinition(
      type: 'listView',
      label: 'ListView',
      category: WidgetCategory.scrolling,
      iconName: 'view_list',
      acceptsChildren: true,
    ),
    WidgetDefinition(
      type: 'gridView',
      label: 'GridView',
      category: WidgetCategory.scrolling,
      iconName: 'grid_view',
      acceptsChildren: true,
      defaultProperties: {'columns': 2},
      properties: [
        PropertyDefinition(
          key: 'columns',
          label: 'Columns',
          kind: PropertyKind.integer,
          min: 1,
          max: 6,
        ),
      ],
    ),
    WidgetDefinition(
      type: 'scrollView',
      label: 'ScrollView',
      category: WidgetCategory.scrolling,
      iconName: 'swap_vert',
      acceptsChildren: true,
      maxChildren: 1,
    ),
    WidgetDefinition(
      type: 'progress',
      label: 'Progress',
      category: WidgetCategory.feedback,
      iconName: 'progress_activity',
      defaultProperties: {'value': 0.65},
      properties: [
        PropertyDefinition(
          key: 'value',
          label: 'Progress',
          kind: PropertyKind.number,
          min: 0,
          max: 1,
        ),
      ],
    ),
  ];

  static List<PropertyDefinition> propertiesFor(WidgetDefinition definition) {
    final properties = [...definition.properties];
    for (final property in _extendedProperties(definition.type)) {
      final index = properties.indexWhere((item) => item.key == property.key);
      if (index < 0) {
        properties.add(property);
      } else {
        properties[index] = property;
      }
    }
    return properties;
  }

  static List<PropertyDefinition> _extendedProperties(String type) =>
      switch (type) {
        'column' || 'row' => const [
          PropertyDefinition(
            key: 'mainAxisSize',
            label: 'Main axis size',
            kind: PropertyKind.choice,
            defaultValue: 'max',
            options: {'max': 'Maximum', 'min': 'Minimum'},
          ),
          PropertyDefinition(
            key: 'verticalDirection',
            label: 'Vertical direction',
            kind: PropertyKind.choice,
            defaultValue: 'down',
            options: {'down': 'Down', 'up': 'Up'},
          ),
          PropertyDefinition(
            key: 'textDirection',
            label: 'Text direction',
            kind: PropertyKind.choice,
            defaultValue: 'ltr',
            options: {'ltr': 'Left to right', 'rtl': 'Right to left'},
          ),
        ],
        'stack' => const [
          PropertyDefinition(
            key: 'alignment',
            label: 'Alignment',
            kind: PropertyKind.choice,
            defaultValue: 'topLeft',
            options: {
              'topLeft': 'Top left',
              'topCenter': 'Top center',
              'topRight': 'Top right',
              'centerLeft': 'Center left',
              'center': 'Center',
              'centerRight': 'Center right',
              'bottomLeft': 'Bottom left',
              'bottomCenter': 'Bottom center',
              'bottomRight': 'Bottom right',
            },
          ),
          PropertyDefinition(
            key: 'fit',
            label: 'Fit',
            kind: PropertyKind.choice,
            defaultValue: 'loose',
            options: {
              'loose': 'Loose',
              'expand': 'Expand',
              'passthrough': 'Passthrough',
            },
          ),
          PropertyDefinition(
            key: 'clipBehavior',
            label: 'Clip content',
            kind: PropertyKind.choice,
            defaultValue: 'hardEdge',
            options: {
              'none': 'None',
              'hardEdge': 'Hard edge',
              'antiAlias': 'Anti-alias',
            },
          ),
        ],
        'container' => const [
          PropertyDefinition(
            key: 'margin',
            label: 'Margin',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'alignment',
            label: 'Child alignment',
            kind: PropertyKind.choice,
            defaultValue: 'topLeft',
            options: {
              'topLeft': 'Top left',
              'topCenter': 'Top center',
              'topRight': 'Top right',
              'centerLeft': 'Center left',
              'center': 'Center',
              'centerRight': 'Center right',
              'bottomLeft': 'Bottom left',
              'bottomCenter': 'Bottom center',
              'bottomRight': 'Bottom right',
            },
          ),
          PropertyDefinition(
            key: 'backgroundColor',
            label: 'Background color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
          PropertyDefinition(
            key: 'borderColor',
            label: 'Border color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
          PropertyDefinition(
            key: 'borderWidth',
            label: 'Border width',
            kind: PropertyKind.number,
            min: 0,
            max: 24,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'borderRadius',
            label: 'Corner radius',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
        ],
        'center' => const [
          PropertyDefinition(
            key: 'widthFactor',
            label: 'Width factor (0 = auto)',
            kind: PropertyKind.number,
            min: 0,
            max: 10,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'heightFactor',
            label: 'Height factor (0 = auto)',
            kind: PropertyKind.number,
            min: 0,
            max: 10,
            defaultValue: 0.0,
          ),
        ],
        'padding' => const [
          PropertyDefinition(
            key: 'individual',
            label: 'Use individual sides',
            kind: PropertyKind.toggle,
            defaultValue: false,
          ),
          PropertyDefinition(
            key: 'left',
            label: 'Left',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 16.0,
          ),
          PropertyDefinition(
            key: 'top',
            label: 'Top',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 16.0,
          ),
          PropertyDefinition(
            key: 'right',
            label: 'Right',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 16.0,
          ),
          PropertyDefinition(
            key: 'bottom',
            label: 'Bottom',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 16.0,
          ),
        ],
        'card' => const [
          PropertyDefinition(
            key: 'padding',
            label: 'Inner padding',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 12.0,
          ),
          PropertyDefinition(
            key: 'margin',
            label: 'Outer margin',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 4.0,
          ),
          PropertyDefinition(
            key: 'color',
            label: 'Card color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
          PropertyDefinition(
            key: 'borderRadius',
            label: 'Corner radius',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 12.0,
          ),
          PropertyDefinition(
            key: 'clipBehavior',
            label: 'Clip content',
            kind: PropertyKind.choice,
            defaultValue: 'none',
            options: {
              'none': 'None',
              'hardEdge': 'Hard edge',
              'antiAlias': 'Anti-alias',
            },
          ),
        ],
        'text' => const [
          PropertyDefinition(
            key: 'fontSize',
            label: 'Custom font size (0 = theme)',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'fontWeight',
            label: 'Font weight',
            kind: PropertyKind.choice,
            defaultValue: 'normal',
            options: {
              'w300': 'Light',
              'normal': 'Normal',
              'w500': 'Medium',
              'w600': 'Semi-bold',
              'bold': 'Bold',
            },
          ),
          PropertyDefinition(
            key: 'color',
            label: 'Text color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
          PropertyDefinition(
            key: 'maxLines',
            label: 'Maximum lines (0 = unlimited)',
            kind: PropertyKind.integer,
            min: 0,
            max: 100,
            defaultValue: 0,
          ),
          PropertyDefinition(
            key: 'overflow',
            label: 'Overflow',
            kind: PropertyKind.choice,
            defaultValue: 'clip',
            options: {
              'clip': 'Clip',
              'ellipsis': 'Ellipsis',
              'fade': 'Fade',
              'visible': 'Visible',
            },
          ),
          PropertyDefinition(
            key: 'softWrap',
            label: 'Soft wrap',
            kind: PropertyKind.toggle,
            defaultValue: true,
          ),
          PropertyDefinition(
            key: 'letterSpacing',
            label: 'Letter spacing',
            kind: PropertyKind.number,
            min: -10,
            max: 50,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'lineHeight',
            label: 'Line height',
            kind: PropertyKind.number,
            min: 0.5,
            max: 5,
            defaultValue: 1.0,
          ),
        ],
        'icon' => const [
          PropertyDefinition(
            key: 'icon',
            label: 'Material icon',
            kind: PropertyKind.choice,
            defaultValue: 'star',
            options: {
              'star': 'Star',
              'add': 'Add',
              'home': 'Home',
              'menu': 'Menu',
              'favorite': 'Favorite',
              'settings': 'Settings',
              'person': 'Person',
              'search': 'Search',
              'close': 'Close',
              'check': 'Check',
              'delete': 'Delete',
              'edit': 'Edit',
              'arrowBack': 'Arrow back',
              'arrowForward': 'Arrow forward',
              'play': 'Play',
              'pause': 'Pause',
              'info': 'Info',
              'warning': 'Warning',
              'email': 'Email',
              'phone': 'Phone',
              'location': 'Location',
            },
          ),
          PropertyDefinition(
            key: 'color',
            label: 'Icon color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
          PropertyDefinition(
            key: 'semanticLabel',
            label: 'Accessibility label',
            kind: PropertyKind.text,
            defaultValue: '',
          ),
        ],
        'image' => const [
          PropertyDefinition(
            key: 'alignment',
            label: 'Alignment',
            kind: PropertyKind.choice,
            defaultValue: 'center',
            options: {
              'topLeft': 'Top left',
              'topCenter': 'Top center',
              'topRight': 'Top right',
              'centerLeft': 'Center left',
              'center': 'Center',
              'centerRight': 'Center right',
              'bottomLeft': 'Bottom left',
              'bottomCenter': 'Bottom center',
              'bottomRight': 'Bottom right',
            },
          ),
          PropertyDefinition(
            key: 'borderRadius',
            label: 'Corner radius',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'opacity',
            label: 'Opacity',
            kind: PropertyKind.number,
            min: 0,
            max: 1,
            defaultValue: 1.0,
          ),
        ],
        'divider' => const [
          PropertyDefinition(
            key: 'height',
            label: 'Layout height',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 16.0,
          ),
          PropertyDefinition(
            key: 'thickness',
            label: 'Thickness',
            kind: PropertyKind.number,
            min: 0,
            max: 24,
            defaultValue: 1.0,
          ),
          PropertyDefinition(
            key: 'indent',
            label: 'Start indent',
            kind: PropertyKind.number,
            min: 0,
            max: 500,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'endIndent',
            label: 'End indent',
            kind: PropertyKind.number,
            min: 0,
            max: 500,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'color',
            label: 'Color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
        ],
        'button' => const [
          PropertyDefinition(
            key: 'icon',
            label: 'Icon',
            kind: PropertyKind.choice,
            defaultValue: 'none',
            options: {
              'none': 'None',
              'add': 'Add',
              'check': 'Check',
              'close': 'Close',
              'edit': 'Edit',
              'delete': 'Delete',
              'favorite': 'Favorite',
              'play': 'Play',
              'arrowForward': 'Arrow forward',
            },
          ),
          PropertyDefinition(
            key: 'iconPosition',
            label: 'Icon position',
            kind: PropertyKind.choice,
            defaultValue: 'left',
            options: {'left': 'Left', 'right': 'Right'},
          ),
          PropertyDefinition(
            key: 'tooltip',
            label: 'Tooltip',
            kind: PropertyKind.text,
            defaultValue: '',
          ),
          PropertyDefinition(
            key: 'borderRadius',
            label: 'Corner radius',
            kind: PropertyKind.number,
            min: 0,
            max: 100,
            defaultValue: 99.0,
          ),
          PropertyDefinition(
            key: 'textSize',
            label: 'Text size (0 = theme)',
            kind: PropertyKind.number,
            min: 0,
            max: 72,
            defaultValue: 0.0,
          ),
        ],
        'textField' => const [
          PropertyDefinition(
            key: 'enabled',
            label: 'Enabled',
            kind: PropertyKind.toggle,
            defaultValue: true,
          ),
          PropertyDefinition(
            key: 'readOnly',
            label: 'Read only',
            kind: PropertyKind.toggle,
            defaultValue: false,
          ),
          PropertyDefinition(
            key: 'maxLines',
            label: 'Maximum lines',
            kind: PropertyKind.integer,
            min: 1,
            max: 20,
            defaultValue: 1,
          ),
          PropertyDefinition(
            key: 'prefixIcon',
            label: 'Prefix icon',
            kind: PropertyKind.choice,
            defaultValue: 'none',
            options: {
              'none': 'None',
              'person': 'Person',
              'email': 'Email',
              'phone': 'Phone',
              'search': 'Search',
              'lock': 'Lock',
              'edit': 'Edit',
            },
          ),
        ],
        'checkbox' || 'switch' => const [
          PropertyDefinition(
            key: 'enabled',
            label: 'Enabled',
            kind: PropertyKind.toggle,
            defaultValue: true,
          ),
          PropertyDefinition(
            key: 'controlAffinity',
            label: 'Control position',
            kind: PropertyKind.choice,
            defaultValue: 'leading',
            options: {'leading': 'Leading', 'trailing': 'Trailing'},
          ),
        ],
        'slider' => const [
          PropertyDefinition(
            key: 'min',
            label: 'Minimum',
            kind: PropertyKind.number,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'max',
            label: 'Maximum',
            kind: PropertyKind.number,
            defaultValue: 1.0,
          ),
          PropertyDefinition(
            key: 'divisions',
            label: 'Divisions (0 = continuous)',
            kind: PropertyKind.integer,
            min: 0,
            max: 1000,
            defaultValue: 0,
          ),
          PropertyDefinition(
            key: 'label',
            label: 'Value label',
            kind: PropertyKind.text,
            defaultValue: '',
          ),
          PropertyDefinition(
            key: 'enabled',
            label: 'Enabled',
            kind: PropertyKind.toggle,
            defaultValue: true,
          ),
        ],
        'listView' => const [
          PropertyDefinition(
            key: 'scrollDirection',
            label: 'Scroll direction',
            kind: PropertyKind.choice,
            defaultValue: 'vertical',
            options: {'vertical': 'Vertical', 'horizontal': 'Horizontal'},
          ),
          PropertyDefinition(
            key: 'reverse',
            label: 'Reverse',
            kind: PropertyKind.toggle,
            defaultValue: false,
          ),
          PropertyDefinition(
            key: 'shrinkWrap',
            label: 'Shrink wrap',
            kind: PropertyKind.toggle,
            defaultValue: true,
          ),
          PropertyDefinition(
            key: 'padding',
            label: 'Padding',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
        ],
        'gridView' => const [
          PropertyDefinition(
            key: 'scrollDirection',
            label: 'Scroll direction',
            kind: PropertyKind.choice,
            defaultValue: 'vertical',
            options: {'vertical': 'Vertical', 'horizontal': 'Horizontal'},
          ),
          PropertyDefinition(
            key: 'reverse',
            label: 'Reverse',
            kind: PropertyKind.toggle,
            defaultValue: false,
          ),
          PropertyDefinition(
            key: 'padding',
            label: 'Padding',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'mainAxisSpacing',
            label: 'Main spacing',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'crossAxisSpacing',
            label: 'Cross spacing',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
          PropertyDefinition(
            key: 'childAspectRatio',
            label: 'Child aspect ratio',
            kind: PropertyKind.number,
            min: 0.1,
            max: 10,
            defaultValue: 1.0,
          ),
        ],
        'scrollView' => const [
          PropertyDefinition(
            key: 'scrollDirection',
            label: 'Scroll direction',
            kind: PropertyKind.choice,
            defaultValue: 'vertical',
            options: {'vertical': 'Vertical', 'horizontal': 'Horizontal'},
          ),
          PropertyDefinition(
            key: 'reverse',
            label: 'Reverse',
            kind: PropertyKind.toggle,
            defaultValue: false,
          ),
          PropertyDefinition(
            key: 'padding',
            label: 'Padding',
            kind: PropertyKind.number,
            min: 0,
            max: 200,
            defaultValue: 0.0,
          ),
        ],
        'progress' => const [
          PropertyDefinition(
            key: 'type',
            label: 'Indicator type',
            kind: PropertyKind.choice,
            defaultValue: 'circular',
            options: {'circular': 'Circular', 'linear': 'Linear'},
          ),
          PropertyDefinition(
            key: 'indeterminate',
            label: 'Indeterminate',
            kind: PropertyKind.toggle,
            defaultValue: false,
          ),
          PropertyDefinition(
            key: 'strokeWidth',
            label: 'Stroke width',
            kind: PropertyKind.number,
            min: 1,
            max: 30,
            defaultValue: 4.0,
          ),
          PropertyDefinition(
            key: 'color',
            label: 'Progress color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
          PropertyDefinition(
            key: 'backgroundColor',
            label: 'Track color',
            kind: PropertyKind.color,
            defaultValue: '#00000000',
          ),
        ],
        _ => const [],
      };

  static WidgetDefinition byType(String type) => definitions.firstWhere(
    (definition) => definition.type == type,
    orElse: () => definitions.first,
  );
}
