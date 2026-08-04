import '../../editor/domain/editor_models.dart';

enum DemoComplexity { beginner, intermediate, advanced }

class DemoProjectTemplate {
  const DemoProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.packageName,
    required this.color,
    required this.iconName,
    required this.complexity,
    required this.highlights,
    required this.design,
    required this.logic,
  });

  final String id;
  final String name;
  final String description;
  final String packageName;
  final int color;
  final String iconName;
  final DemoComplexity complexity;
  final List<String> highlights;
  final ScreenDesign design;
  final Map<String, Object?> logic;
}

abstract final class DemoProjectTemplates {
  static final all = <DemoProjectTemplate>[
    DemoProjectTemplate(
      id: 'demo_counter_lab',
      name: 'Counter Lab',
      description:
          'A friendly first project with state, several button events, and user feedback.',
      packageName: 'dev.fluttware.demo.counterlab',
      color: 0xFF2563EB,
      iconName: 'calculate',
      complexity: DemoComplexity.beginner,
      highlights: const ['State', 'Button events', 'Snackbars'],
      design: ScreenDesign(
        initialPageId: 'home',
        pages: [
          _page(
            id: 'home',
            name: 'Counter',
            title: 'Counter Lab',
            body: _list('counter_list', [
              _text(
                'counter_heading',
                'Small logic, clearly explained',
                style: 'headlineSmall',
              ),
              _text(
                'counter_intro',
                'Explore how multiple events update one shared variable.',
              ),
              _gap('counter_gap_1', 20),
              _card(
                'counter_card',
                _column('counter_card_column', [
                  _text('counter_caption', 'CURRENT VALUE', style: 'bodySmall'),
                  const WidgetNode(
                    id: 'counter_value',
                    type: 'text',
                    properties: {
                      'binding': 'counter',
                      'style': 'headlineLarge',
                      'textAlign': 'center',
                      'fontSize': 54.0,
                      'fontWeight': 'bold',
                    },
                  ),
                  _gap('counter_gap_2', 16),
                  _row(
                    'counter_actions',
                    [
                      _button(
                        'decrement_button',
                        'Decrease',
                        icon: 'arrowBack',
                        variant: 'outlined',
                      ),
                      _gap('counter_action_gap', 12, width: 12),
                      _button('increment_button', 'Increase', icon: 'add'),
                    ],
                    main: 'center',
                    cross: 'center',
                  ),
                  _gap('counter_gap_3', 12),
                  _button(
                    'reset_button',
                    'Reset counter',
                    icon: 'close',
                    variant: 'tonal',
                    widthMode: 'full',
                  ),
                ], cross: 'stretch'),
              ),
            ]),
          ),
        ],
      ),
      logic: _logic(
        variables: [_variable('counter', 'int', 0)],
        events: [
          _event('increment_button', 'onPressed', [
            _set('counter', 'add', 1),
            _message('Counter increased'),
          ]),
          _event('decrement_button', 'onPressed', [
            _set('counter', 'subtract', 1),
          ]),
          _event('reset_button', 'onPressed', [
            _set('counter', 'set', 0),
            _message('Back to zero'),
          ]),
        ],
      ),
    ),
    DemoProjectTemplate(
      id: 'demo_focus_flow',
      name: 'Focus Flow',
      description:
          'A polished task dashboard combining forms, progress, preferences, and chained logic.',
      packageName: 'dev.fluttware.demo.focusflow',
      color: 0xFF7C3AED,
      iconName: 'task',
      complexity: DemoComplexity.intermediate,
      highlights: const ['Forms', 'Chained actions', 'Progress UI'],
      design: ScreenDesign(
        initialPageId: 'home',
        pages: [
          _page(
            id: 'home',
            name: 'Today',
            title: 'Focus Flow',
            body: _list('focus_list', [
              _text('focus_greeting', 'Good morning', style: 'headlineSmall'),
              _text('focus_subtitle', 'Three focused steps make a great day.'),
              _gap('focus_gap_1', 18),
              _card(
                'focus_progress_card',
                _column('focus_progress_column', [
                  _row(
                    'focus_progress_header',
                    [
                      _text(
                        'focus_progress_title',
                        'Daily progress',
                        style: 'titleMedium',
                      ),
                      _text(
                        'focus_progress_value',
                        '67%',
                        style: 'titleMedium',
                      ),
                    ],
                    main: 'spaceBetween',
                    cross: 'center',
                  ),
                  _gap('focus_gap_2', 12),
                  const WidgetNode(
                    id: 'daily_progress',
                    type: 'progress',
                    properties: {
                      'type': 'linear',
                      'value': 0.67,
                      'strokeWidth': 8.0,
                    },
                  ),
                ], cross: 'stretch'),
              ),
              _gap('focus_gap_3', 14),
              _text('focus_tasks_title', 'Today’s tasks', style: 'titleMedium'),
              const WidgetNode(
                id: 'task_plan',
                type: 'checkbox',
                properties: {'label': 'Plan the day', 'value': true},
              ),
              const WidgetNode(
                id: 'task_deep_work',
                type: 'checkbox',
                properties: {
                  'label': 'Complete a deep-work session',
                  'value': false,
                },
              ),
              const WidgetNode(
                id: 'task_review',
                type: 'checkbox',
                properties: {
                  'label': 'Review and celebrate progress',
                  'value': false,
                },
              ),
              _gap('focus_gap_4', 14),
              const WidgetNode(
                id: 'focus_mode',
                type: 'switch',
                properties: {'label': 'Silence distractions', 'value': true},
              ),
              _gap('focus_gap_5', 14),
              const WidgetNode(
                id: 'new_task_field',
                type: 'textField',
                properties: {
                  'label': 'New task',
                  'hint': 'What needs your attention?',
                  'prefixIcon': 'edit',
                },
              ),
              _gap('focus_gap_6', 12),
              _button(
                'add_task_button',
                'Add to today',
                icon: 'add',
                widthMode: 'full',
              ),
            ]),
          ),
        ],
      ),
      logic: _logic(
        variables: [
          _variable('completedTasks', 'int', 1),
          _variable('focusEnabled', 'bool', true),
        ],
        events: [
          _event('task_deep_work', 'onChanged', [
            _set('completedTasks', 'add', 1),
            _message('Deep work complete — excellent focus!'),
          ]),
          _event('focus_mode', 'onChanged', [
            _set('focusEnabled', 'set', true),
            _log('Focus preference changed'),
          ]),
          _event('new_task_field', 'onSubmitted', [
            _message('Task captured from the keyboard'),
          ]),
          _event('add_task_button', 'onPressed', [
            _message('Adding your task…'),
            _delay(350),
            _dialog('Task added', 'Your new focus item is ready for today.'),
          ]),
        ],
      ),
    ),
    DemoProjectTemplate(
      id: 'demo_market_mosaic',
      name: 'Market Mosaic',
      description:
          'A multi-page storefront with a responsive catalog, product details, and cart logic.',
      packageName: 'dev.fluttware.demo.marketmosaic',
      color: 0xFFEA580C,
      iconName: 'storefront',
      complexity: DemoComplexity.advanced,
      highlights: const ['Multi-page', 'Grid layout', 'Cart state'],
      design: ScreenDesign(
        initialPageId: 'catalog',
        pages: [
          _page(
            id: 'catalog',
            name: 'Catalog',
            title: 'Market Mosaic',
            body: _list('market_list', [
              _text('market_title', 'Fresh finds', style: 'headlineSmall'),
              _text(
                'market_subtitle',
                'A complete storefront made from editable widgets.',
              ),
              _gap('market_gap_1', 16),
              const WidgetNode(
                id: 'market_search',
                type: 'textField',
                properties: {
                  'label': 'Search products',
                  'hint': 'Try “headphones”',
                  'prefixIcon': 'search',
                },
              ),
              _gap('market_gap_2', 16),
              _grid('product_grid', [
                _productCard(
                  'audio_product',
                  'Studio headphones',
                  r'$129',
                  'favorite',
                ),
                _productCard('watch_product', 'Minimal watch', r'$89', 'star'),
                _productCard('lamp_product', 'Desk light', r'$54', 'warning'),
                _productCard('bag_product', 'Everyday bag', r'$72', 'person'),
              ]),
              _gap('market_gap_3', 16),
              _button(
                'open_product_button',
                'Explore featured product',
                icon: 'arrowForward',
                widthMode: 'full',
              ),
            ]),
          ),
          _page(
            id: 'product',
            name: 'Product details',
            route: '/product',
            title: 'Product details',
            body: _list('product_detail_list', [
              _container(
                'product_hero',
                _icon('product_hero_icon', 'favorite', size: 84),
                height: 220,
                color: '#FFF1E8',
                radius: 28,
                alignment: 'center',
              ),
              _gap('product_gap_1', 20),
              _text(
                'product_name',
                'Studio headphones',
                style: 'headlineSmall',
              ),
              _text(
                'product_price',
                r'$129 • Free delivery',
                style: 'titleMedium',
              ),
              _gap('product_gap_2', 12),
              _text(
                'product_copy',
                'Balanced sound, soft memory cushions, and a battery that lasts through the week.',
              ),
              _gap('product_gap_3', 20),
              _button(
                'add_cart_button',
                'Add to cart',
                icon: 'add',
                widthMode: 'full',
              ),
              _gap('product_gap_4', 10),
              _button(
                'back_catalog_button',
                'Back to catalog',
                variant: 'outlined',
                widthMode: 'full',
              ),
            ]),
          ),
        ],
      ),
      logic: _logic(
        variables: [_variable('counter', 'int', 0)],
        events: [
          _event('market_search', 'onSubmitted', [
            _log('Catalog search submitted'),
          ]),
          _event('open_product_button', 'onPressed', [_navigate('/product')]),
          _event('add_cart_button', 'onPressed', [
            _set('counter', 'add', 1),
            _message('Studio headphones added to your cart'),
          ]),
          _event('back_catalog_button', 'onPressed', [_pop()]),
        ],
      ),
    ),
    DemoProjectTemplate(
      id: 'demo_pocket_budget',
      name: 'Pocket Budget',
      description:
          'A dense finance dashboard demonstrating cards, charts, forms, and asynchronous actions.',
      packageName: 'dev.fluttware.demo.pocketbudget',
      color: 0xFF059669,
      iconName: 'account_balance_wallet',
      complexity: DemoComplexity.advanced,
      highlights: const ['Dashboard UI', 'Form controls', 'Async logic'],
      design: ScreenDesign(
        initialPageId: 'dashboard',
        pages: [
          _page(
            id: 'dashboard',
            name: 'Dashboard',
            title: 'Pocket Budget',
            body: _list('budget_list', [
              _text(
                'budget_eyebrow',
                'AVAILABLE THIS MONTH',
                style: 'bodySmall',
              ),
              _text('budget_balance', r'$2,480.50', style: 'headlineLarge'),
              _text('budget_change', '↑ 12% compared with last month'),
              _gap('budget_gap_1', 20),
              _row('budget_stats', [
                _card(
                  'income_card',
                  _column('income_column', [
                    _icon('income_icon', 'add', size: 28),
                    _text('income_label', 'Income', style: 'bodySmall'),
                    _text('income_value', r'$4,200', style: 'titleMedium'),
                  ]),
                ),
                _card(
                  'spent_card',
                  _column('spent_column', [
                    _icon('spent_icon', 'arrowForward', size: 28),
                    _text('spent_label', 'Spent', style: 'bodySmall'),
                    _text('spent_value', r'$1,719', style: 'titleMedium'),
                  ]),
                ),
              ], main: 'spaceBetween'),
              _gap('budget_gap_2', 18),
              _card(
                'budget_health_card',
                _column('budget_health_column', [
                  _text(
                    'budget_health_title',
                    'Monthly budget',
                    style: 'titleMedium',
                  ),
                  _gap('budget_gap_3', 10),
                  const WidgetNode(
                    id: 'budget_progress',
                    type: 'progress',
                    properties: {
                      'type': 'linear',
                      'value': 0.41,
                      'strokeWidth': 10.0,
                    },
                  ),
                  _gap('budget_gap_4', 8),
                  _text('budget_health_caption', r'$1,719 of $4,200 used'),
                ], cross: 'stretch'),
              ),
              _gap('budget_gap_5', 18),
              _text('expense_title', 'Quick expense', style: 'titleMedium'),
              const WidgetNode(
                id: 'expense_name',
                type: 'textField',
                properties: {
                  'label': 'Description',
                  'hint': 'Coffee, transport…',
                  'prefixIcon': 'edit',
                },
              ),
              _gap('budget_gap_6', 12),
              const WidgetNode(
                id: 'expense_amount',
                type: 'textField',
                properties: {
                  'label': 'Amount',
                  'hint': '0.00',
                  'keyboardType': 'number',
                },
              ),
              _gap('budget_gap_7', 12),
              _button(
                'save_expense_button',
                'Save expense',
                icon: 'check',
                widthMode: 'full',
              ),
            ]),
          ),
        ],
      ),
      logic: _logic(
        variables: [
          _variable('monthlySpent', 'double', 1719.5),
          _variable('transactionCount', 'int', 12),
        ],
        events: [
          _event('expense_amount', 'onSubmitted', [
            _log('Expense amount submitted'),
          ]),
          _event('save_expense_button', 'onPressed', [
            _message('Saving transaction…'),
            _delay(500),
            _set('transactionCount', 'add', 1),
            _dialog('Expense saved', 'Your dashboard has been updated.'),
          ]),
        ],
      ),
    ),
    DemoProjectTemplate(
      id: 'demo_roam_planner',
      name: 'Roam Planner',
      description:
          'A three-page travel planner with discovery, booking controls, navigation, and dialogs.',
      packageName: 'dev.fluttware.demo.roamplanner',
      color: 0xFF0891B2,
      iconName: 'travel_explore',
      complexity: DemoComplexity.advanced,
      highlights: const ['Three pages', 'Navigation', 'Rich controls'],
      design: ScreenDesign(
        initialPageId: 'home',
        pages: [
          _page(
            id: 'home',
            name: 'Home',
            title: 'Roam Planner',
            body: _list('roam_home_list', [
              _container(
                'roam_hero',
                _column('roam_hero_column', [
                  _icon('roam_hero_icon', 'location', size: 48),
                  _text(
                    'roam_hero_title',
                    'Where will you go next?',
                    style: 'headlineSmall',
                  ),
                  _text(
                    'roam_hero_copy',
                    'Build an itinerary, tune the budget, and keep every detail together.',
                  ),
                ], cross: 'center'),
                color: '#E5F8FC',
                radius: 28,
                padding: 24,
              ),
              _gap('roam_gap_1', 20),
              _button(
                'explore_button',
                'Explore destinations',
                icon: 'search',
                widthMode: 'full',
              ),
              _gap('roam_gap_2', 10),
              _button(
                'trip_button',
                'Open my trip',
                icon: 'arrowForward',
                variant: 'tonal',
                widthMode: 'full',
              ),
            ]),
          ),
          _page(
            id: 'explore',
            name: 'Explore',
            route: '/explore',
            title: 'Explore',
            body: _list('explore_list', [
              const WidgetNode(
                id: 'destination_search',
                type: 'textField',
                properties: {
                  'label': 'Destination',
                  'hint': 'City or country',
                  'prefixIcon': 'search',
                },
              ),
              _gap('explore_gap_1', 16),
              _text(
                'popular_title',
                'Popular this season',
                style: 'titleMedium',
              ),
              _card(
                'lisbon_card',
                _destination(
                  'lisbon_content',
                  'Lisbon',
                  'Coast, culture, and warm evenings',
                  'location',
                ),
              ),
              _card(
                'kyoto_card',
                _destination(
                  'kyoto_content',
                  'Kyoto',
                  'Gardens, temples, and quiet streets',
                  'star',
                ),
              ),
              _card(
                'addis_card',
                _destination(
                  'addis_content',
                  'Addis Ababa',
                  'Coffee, history, and mountain air',
                  'favorite',
                ),
              ),
              _gap('explore_gap_2', 12),
              _button(
                'choose_destination_button',
                'Plan Lisbon trip',
                icon: 'check',
                widthMode: 'full',
              ),
            ]),
          ),
          _page(
            id: 'trip',
            name: 'My trip',
            route: '/trip',
            title: 'Lisbon itinerary',
            body: _list('trip_list', [
              _text('trip_dates', 'MAY 18 — MAY 24', style: 'bodySmall'),
              _text(
                'trip_heading',
                'Six days in Lisbon',
                style: 'headlineSmall',
              ),
              _gap('trip_gap_1', 18),
              _card(
                'flight_card',
                _destination(
                  'flight_content',
                  'Flight booked',
                  'Monday • 08:45 departure',
                  'check',
                ),
              ),
              _card(
                'hotel_card',
                _destination(
                  'hotel_content',
                  'Stay selected',
                  'Alfama • 5 nights',
                  'home',
                ),
              ),
              _gap('trip_gap_2', 16),
              _text('budget_title', 'Daily budget', style: 'titleMedium'),
              const WidgetNode(
                id: 'daily_budget',
                type: 'slider',
                properties: {
                  'value': 90.0,
                  'min': 30.0,
                  'max': 250.0,
                  'divisions': 22,
                  'label': 'Daily budget',
                },
              ),
              const WidgetNode(
                id: 'offline_maps',
                type: 'switch',
                properties: {
                  'label': 'Download maps for offline use',
                  'value': true,
                },
              ),
              _gap('trip_gap_3', 14),
              _button(
                'confirm_trip_button',
                'Confirm itinerary',
                icon: 'check',
                widthMode: 'full',
              ),
              _gap('trip_gap_4', 10),
              _button(
                'trip_back_button',
                'Back',
                variant: 'outlined',
                widthMode: 'full',
              ),
            ]),
          ),
        ],
      ),
      logic: _logic(
        variables: [
          _variable('dailyBudget', 'double', 90.0),
          _variable('offlineMaps', 'bool', true),
        ],
        events: [
          _event('explore_button', 'onPressed', [_navigate('/explore')]),
          _event('trip_button', 'onPressed', [_navigate('/trip')]),
          _event('destination_search', 'onSubmitted', [
            _message('Searching destinations…'),
            _delay(300),
          ]),
          _event('choose_destination_button', 'onPressed', [
            _navigate('/trip'),
          ]),
          _event('daily_budget', 'onChanged', [_log('Daily budget adjusted')]),
          _event('offline_maps', 'onChanged', [
            _set('offlineMaps', 'set', true),
          ]),
          _event('confirm_trip_button', 'onPressed', [
            _dialog('Trip ready', 'Your Lisbon itinerary is ready to explore.'),
            _message('Itinerary saved for offline use'),
          ]),
          _event('trip_back_button', 'onPressed', [_pop()]),
        ],
      ),
    ),
  ];
}

PageDesign _page({
  required String id,
  required String name,
  required String title,
  required WidgetNode body,
  String route = '/',
}) => PageDesign(
  id: id,
  name: name,
  route: route,
  appBar: ScaffoldSlot(enabled: true, properties: {'title': title}),
  floatingActionButton: const ScaffoldSlot(enabled: false),
  body: body,
);

WidgetNode _text(String id, String text, {String style = 'bodyLarge'}) =>
    WidgetNode(
      id: id,
      type: 'text',
      properties: {'text': text, 'style': style},
    );

WidgetNode _icon(String id, String icon, {double size = 32}) =>
    WidgetNode(id: id, type: 'icon', properties: {'icon': icon, 'size': size});

WidgetNode _gap(String id, double height, {double width = 0}) => WidgetNode(
  id: id,
  type: 'sizedBox',
  properties: {'height': height, 'width': width},
);

WidgetNode _column(
  String id,
  List<WidgetNode> children, {
  String main = 'start',
  String cross = 'start',
}) => WidgetNode(
  id: id,
  type: 'column',
  properties: {'mainAxisAlignment': main, 'crossAxisAlignment': cross},
  children: children,
);

WidgetNode _row(
  String id,
  List<WidgetNode> children, {
  String main = 'start',
  String cross = 'start',
}) => WidgetNode(
  id: id,
  type: 'row',
  properties: {'mainAxisAlignment': main, 'crossAxisAlignment': cross},
  children: children,
);

WidgetNode _list(String id, List<WidgetNode> children) => WidgetNode(
  id: id,
  type: 'listView',
  properties: const {'padding': 20.0, 'shrinkWrap': false},
  children: children,
);

WidgetNode _grid(String id, List<WidgetNode> children) => WidgetNode(
  id: id,
  type: 'gridView',
  properties: const {
    'columns': 2,
    'mainAxisSpacing': 10.0,
    'crossAxisSpacing': 10.0,
    'childAspectRatio': 0.86,
  },
  children: children,
);

WidgetNode _card(String id, WidgetNode child) => WidgetNode(
  id: id,
  type: 'card',
  properties: const {'padding': 16.0, 'margin': 4.0, 'borderRadius': 20.0},
  children: [child],
);

WidgetNode _container(
  String id,
  WidgetNode child, {
  double height = 0,
  double padding = 16,
  double radius = 20,
  String color = '',
  String alignment = 'topLeft',
}) => WidgetNode(
  id: id,
  type: 'container',
  properties: {
    'height': height,
    'padding': padding,
    'borderRadius': radius,
    'backgroundColor': color,
    'alignment': alignment,
  },
  children: [child],
);

WidgetNode _button(
  String id,
  String text, {
  String icon = 'none',
  String variant = 'filled',
  String widthMode = 'auto',
}) => WidgetNode(
  id: id,
  type: 'button',
  properties: {
    'text': text,
    'icon': icon,
    'variant': variant,
    'widthMode': widthMode,
    'height': 50.0,
    'enabled': true,
  },
);

WidgetNode _productCard(String id, String name, String price, String icon) =>
    _card(
      id,
      _column('${id}_column', [
        _container(
          '${id}_image',
          _icon('${id}_icon', icon, size: 44),
          height: 88,
          color: '#FFF1E8',
          radius: 14,
          alignment: 'center',
        ),
        _gap('${id}_gap', 10),
        _text('${id}_name', name, style: 'titleMedium'),
        _text('${id}_price', price, style: 'bodySmall'),
      ]),
    );

WidgetNode _destination(
  String id,
  String title,
  String subtitle,
  String icon,
) => _row(id, [
  _icon('${id}_icon', icon, size: 34),
  _gap('${id}_gap', 12, width: 12),
  _column('${id}_copy', [
    _text('${id}_title', title, style: 'titleMedium'),
    _text('${id}_subtitle', subtitle, style: 'bodySmall'),
  ]),
], cross: 'center');

Map<String, Object?> _logic({
  required List<Map<String, Object?>> variables,
  required List<Map<String, Object?>> events,
}) => {'schemaVersion': 1, 'variables': variables, 'events': events};

Map<String, Object?> _variable(String id, String type, Object value) => {
  'id': id,
  'name': id,
  'type': type,
  'initialValue': value,
};

Map<String, Object?> _event(
  String widgetId,
  String event,
  List<Map<String, Object?>> blocks,
) => {
  'id': '${widgetId}_${event.toLowerCase()}',
  'widgetId': widgetId,
  'event': event,
  'blocks': blocks,
};

Map<String, Object?> _set(String variable, String operation, Object value) => {
  'type': 'setVariable',
  'variableId': variable,
  'operation': operation,
  'value': value,
};

Map<String, Object?> _message(String message) => {
  'type': 'showSnackBar',
  'message': message,
};

Map<String, Object?> _dialog(String title, String message) => {
  'type': 'showDialog',
  'title': title,
  'message': message,
};

Map<String, Object?> _delay(int milliseconds) => {
  'type': 'delay',
  'milliseconds': milliseconds,
};

Map<String, Object?> _navigate(String route) => {
  'type': 'navigate',
  'route': route,
};

Map<String, Object?> _pop() => {'type': 'pop'};

Map<String, Object?> _log(String message) => {
  'type': 'log',
  'message': message,
};
