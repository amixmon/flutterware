import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/theme/app_tokens.dart';
import '../../../ui/widgets/app_button.dart';
import '../../../ui/widgets/app_color_picker.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_configuration.dart';
import '../../projects/domain/project_summary.dart';
import '../domain/project_theme_builder.dart';

class ThemeStudioPage extends StatefulWidget {
  const ThemeStudioPage({
    super.key,
    required this.project,
    this.repository = const ProjectRepository(),
  });

  final ProjectSummary project;
  final ProjectRepository repository;

  @override
  State<ThemeStudioPage> createState() => _ThemeStudioPageState();
}

class _ThemeStudioPageState extends State<ThemeStudioPage> {
  static const _seedPresets = <Color>[
    Color(0xFF168CF3),
    Color(0xFF6750A4),
    Color(0xFF006C4C),
    Color(0xFF8C4A60),
    Color(0xFF8B5000),
    Color(0xFF00639B),
  ];

  late ProjectThemeSettings _settings = widget.project.theme;
  Brightness _previewBrightness = Brightness.light;
  bool _initializedBrightness = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedBrightness) return;
    _previewBrightness = ProjectThemeBuilder.brightnessFor(
      _settings,
      MediaQuery.platformBrightnessOf(context),
    );
    _initializedBrightness = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final project = await widget.repository.updateTheme(
        id: widget.project.id,
        theme: _settings,
      );
      if (mounted) Navigator.pop(context, project);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error is PlatformException
          ? error.message ?? 'Could not save the project theme'
          : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _resetStyle() {
    setState(() {
      _settings = ProjectThemeSettings(
        mode: ProjectThemeMode.system,
        seedColor: widget.project.color.toARGB32(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Studio'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _resetStyle,
            child: const Text('Reset'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _ThemePreview(
              settings: _settings,
              brightness: _previewBrightness,
              onBrightnessChanged: (value) {
                setState(() => _previewBrightness = value);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _StudioSection(
              title: 'Appearance',
              description:
                  'Choose how the generated app follows the device theme.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ProjectThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ProjectThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ProjectThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ProjectThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {_settings.mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      setState(
                        () =>
                            _settings = _settings.copyWith(mode: value.single),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Seed color',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppColorPicker(
                    value: Color(_settings.seedColor),
                    presets: _seedPresets,
                    onChanged: (color) {
                      setState(
                        () => _settings = _settings.copyWith(
                          seedColor: color.toARGB32(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _StudioSection(
              title: 'Typography',
              description:
                  'Choose a project font. Imported font families will be added by Font Manager.',
              child: DropdownButtonFormField<String>(
                initialValue: _settings.fontFamily ?? 'system',
                decoration: const InputDecoration(
                  labelText: 'Font family',
                  prefixIcon: Icon(Icons.font_download_outlined),
                ),
                items: _fontChoices(_settings.fontFamily),
                onChanged: (value) {
                  setState(() {
                    _settings = value == null || value == 'system'
                        ? _settings.copyWith(clearFontFamily: true)
                        : _settings.copyWith(fontFamily: value);
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _StudioSection(
              title: 'Shapes',
              description:
                  'Apply one consistent Material 3 radius across components.',
              child: _LabeledSlider(
                label: 'Corner radius',
                valueLabel: '${_settings.cornerRadius.round()} dp',
                value: _settings.cornerRadius,
                min: 0,
                max: 32,
                divisions: 16,
                onChanged: (value) {
                  setState(
                    () => _settings = _settings.copyWith(cornerRadius: value),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _StudioSection(
              title: 'Components',
              description:
                  'Tune shared cards and form fields in the generated theme.',
              child: Column(
                children: [
                  _LabeledSlider(
                    label: 'Card elevation',
                    valueLabel: _settings.cardElevation == 0
                        ? 'Flat'
                        : '${_settings.cardElevation.round()} dp',
                    value: _settings.cardElevation,
                    min: 0,
                    max: 8,
                    divisions: 8,
                    onChanged: (value) {
                      setState(
                        () => _settings = _settings.copyWith(
                          cardElevation: value,
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Filled text fields'),
                    subtitle: const Text(
                      'Use Material 3 surface fill behind inputs',
                    ),
                    value: _settings.inputFilled,
                    onChanged: (value) {
                      setState(
                        () =>
                            _settings = _settings.copyWith(inputFilled: value),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Save project theme',
              leadingIcon: Icons.check_rounded,
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  static List<DropdownMenuItem<String>> _fontChoices(String? current) {
    final choices = <String>['system', 'Roboto', 'serif', 'monospace'];
    if (current != null && !choices.contains(current)) choices.add(current);
    return choices
        .map(
          (value) => DropdownMenuItem(
            value: value,
            child: Text(value == 'system' ? 'System default' : value),
          ),
        )
        .toList(growable: false);
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.settings,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  final ProjectThemeSettings settings;
  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

  @override
  Widget build(BuildContext context) {
    final previewTheme = ProjectThemeBuilder.build(settings, brightness);
    return Theme(
      data: previewTheme,
      child: Builder(
        builder: (context) => Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Live preview',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      SegmentedButton<Brightness>(
                        segments: const [
                          ButtonSegment(
                            value: Brightness.light,
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: Brightness.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {brightness},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) {
                          onBrightnessChanged(value.single);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material 3 project',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Colors, typography, shapes, and components update together.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Project name',
                          prefixIcon: Icon(Icons.apps_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {},
                              child: const Text('Primary'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Secondary'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Notifications'),
                        value: true,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioSection extends StatelessWidget {
  const _StudioSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: valueLabel,
        onChanged: onChanged,
      ),
    ],
  );
}
