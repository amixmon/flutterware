import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/theme/app_tokens.dart';
import '../../../ui/widgets/app_button.dart';
import '../../../ui/widgets/app_color_picker.dart';
import '../../../ui/widgets/app_section_card.dart';
import '../../../ui/widgets/app_text_field.dart';
import '../../../ui/widgets/flutterware_logo.dart';
import '../data/project_repository.dart';
import '../domain/project_summary.dart';

class NewProjectPage extends StatefulWidget {
  const NewProjectPage({super.key});

  @override
  State<NewProjectPage> createState() => _NewProjectPageState();
}

class _NewProjectPageState extends State<NewProjectPage> {
  static const _colors = [
    Color(0xFF168CF3),
    Color(0xFF6750A4),
    Color(0xFF9A4522),
    Color(0xFF386A20),
    Color(0xFF415F91),
  ];

  final _formKey = GlobalKey<FormState>();
  final _appName = TextEditingController();
  final _packageName = TextEditingController(text: 'com.example.myapp');
  final _projectId = TextEditingController(text: 'my_app');
  final _repository = const ProjectRepository();
  Color _color = _colors.first;
  Uint8List? _iconBytes;
  bool _pickingIcon = false;
  bool _saving = false;
  bool _packageEdited = false;
  bool _idEdited = false;

  @override
  void initState() {
    super.initState();
    _appName.addListener(_deriveNames);
  }

  void _deriveNames() {
    var slug = _appName.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty || !RegExp(r'^[a-z]').hasMatch(slug)) slug = 'my_app';
    if (slug.length > 27) slug = slug.substring(0, 27);
    if (!_idEdited) _projectId.value = TextEditingValue(text: slug);
    if (!_packageEdited) {
      _packageName.value = TextEditingValue(
        text: 'com.example.${slug.replaceAll('_', '')}',
      );
    }
  }

  @override
  void dispose() {
    _appName.dispose();
    _packageName.dispose();
    _projectId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Flutter project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pageHorizontal,
            AppSpacing.xl,
            AppSizes.pageHorizontal,
            120,
          ),
          children: [
            Center(
              child: SizedBox(
                width: 76,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: _iconBytes == null
                        ? const FlutterwareLogo(size: 58)
                        : Image.memory(
                            _iconBytes!,
                            width: 76,
                            height: 76,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppTextField(
              controller: _appName,
              label: 'Application name',
              helper: 'The name shown on the installed application',
              prefixIcon: Icons.android_rounded,
              autofocus: true,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Enter an application name';
                if (text.length > 40) return 'Use 40 characters or fewer';
                return null;
              },
            ),
            const SizedBox(height: AppSizes.fieldGap),
            AppTextField(
              controller: _packageName,
              label: 'Package name',
              helper: 'Example: com.example.myapp',
              prefixIcon: Icons.inventory_2_outlined,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (_) => _packageEdited = true,
              validator: (value) {
                final valid = RegExp(
                  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
                ).hasMatch(value?.trim() ?? '');
                return valid ? null : 'Enter a valid lowercase package name';
              },
            ),
            const SizedBox(height: AppSizes.fieldGap),
            AppTextField(
              controller: _projectId,
              label: 'Project name',
              helper: 'Lowercase letters, numbers and underscores',
              prefixIcon: Icons.folder_outlined,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onChanged: (_) => _idEdited = true,
              validator: (value) {
                final valid = RegExp(
                  r'^[a-z][a-z0-9_]{2,30}$',
                ).hasMatch(value?.trim() ?? '');
                return valid ? null : 'Use 3–31 lowercase characters';
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSectionCard(
              title: 'App icon',
              subtitle:
                  'Choose a PNG, JPEG or WebP image. Flutterware adds safe transparent padding and generates a launcher-ready 192 × 192 PNG.',
              leading: Icon(
                Icons.apps_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: _pickingIcon
                        ? 'Opening images…'
                        : _iconBytes == null
                        ? 'Choose app icon'
                        : 'Change app icon',
                    busy: _pickingIcon,
                    variant: AppButtonVariant.outlined,
                    leadingIcon: Icons.image_outlined,
                    onPressed: _pickingIcon ? null : _pickIcon,
                  ),
                  if (_iconBytes != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Use Flutterware default',
                      variant: AppButtonVariant.text,
                      leadingIcon: Icons.restart_alt_rounded,
                      onPressed: () => setState(() => _iconBytes = null),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.fieldGap),
            AppSectionCard(
              title: 'App color',
              subtitle:
                  'Choose a preset, enter a hex value, or use the color wheel.',
              leading: Icon(
                Icons.palette_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: AppColorPicker(
                value: _color,
                presets: _colors,
                onChanged: (color) => setState(() => _color = color),
              ),
            ),
            const SizedBox(height: AppSizes.fieldGap),
            const AppSectionCard(
              title: 'Debug project',
              subtitle: 'This first editor builds ARM64 Flutter debug APKs.',
              leading: Icon(Icons.bug_report_outlined),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Flutter DEBUG banner stays visible')),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.text,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: _saving ? 'Creating…' : 'Create project',
                  busy: _saving,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: _saving ? null : _create,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final project = await _repository.create(
        id: _projectId.text.trim(),
        name: _appName.text.trim(),
        packageName: _packageName.text.trim(),
        color: _color.toARGB32(),
        iconBytes: _iconBytes,
      );
      if (mounted) Navigator.pop<ProjectSummary>(context, project);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not create project')),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _pickIcon() async {
    setState(() => _pickingIcon = true);
    try {
      final bytes = await _repository.pickProjectIcon();
      if (mounted && bytes != null) setState(() => _iconBytes = bytes);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not select the icon')),
      );
    } finally {
      if (mounted) setState(() => _pickingIcon = false);
    }
  }
}
