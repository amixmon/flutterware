import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_text_field.dart';

class AppColorPicker extends StatefulWidget {
  const AppColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = const [],
  });

  final Color value;
  final ValueChanged<Color> onChanged;
  final List<Color> presets;

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _toHex(widget.value));
  }

  @override
  void didUpdateWidget(covariant AppColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _hexController.text.toUpperCase() != _toHex(widget.value)) {
      _hexController.text = _toHex(widget.value);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _hexController,
          label: 'Hex color',
          helper: 'Use #RRGGBB',
          prefixIcon: Icons.tag_rounded,
          suffixIcon: Icons.palette_outlined,
          onSuffixPressed: _openWheel,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          onChanged: _applyHex,
          validator: (value) => _parseHex(value ?? '') == null
              ? 'Enter a valid color such as #168CF3'
              : null,
        ),
        if (widget.presets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: widget.presets.map((color) {
              final selected = color.toARGB32() == widget.value.toARGB32();
              return Semantics(
                button: true,
                selected: selected,
                label: 'Select ${_toHex(color)}',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _select(color),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? colors.onSurface
                            : colors.outlineVariant,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            color: _foregroundFor(color),
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Open color wheel',
          onPressed: _openWheel,
          variant: AppButtonVariant.outlined,
          trailingIcon: Icons.colorize_rounded,
        ),
      ],
    );
  }

  void _applyHex(String value) {
    final color = _parseHex(value);
    if (color != null) widget.onChanged(color);
  }

  void _select(Color color) {
    _hexController.text = _toHex(color);
    widget.onChanged(color);
  }

  Future<void> _openWheel() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorWheelDialog(initialColor: widget.value),
    );
    if (selected != null) _select(selected);
  }

  static String _toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color? _parseHex(String input) {
    var value = input.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8 || !RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse(value, radix: 16));
  }

  static Color _foregroundFor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose app color'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (details) =>
                        _pick(details.localPosition, constraints.biggest),
                    onPanUpdate: (details) =>
                        _pick(details.localPosition, constraints.biggest),
                    child: CustomPaint(painter: _ColorWheelPainter(_hsv)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.brightness_6_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Slider(
                      value: _hsv.value,
                      onChanged: (value) =>
                          setState(() => _hsv = _hsv.withValue(value)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: double.infinity,
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: _hsv.toColor(),
                  borderRadius: AppRadii.inputBorder,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: _AppColorPickerState._foregroundFor(
                        _hsv.toColor(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Preview  ${_AppColorPickerState._toHex(_hsv.toColor())}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _AppColorPickerState._foregroundFor(
                          _hsv.toColor(),
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          expanded: false,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: 'Use color',
          expanded: false,
          trailingIcon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, _hsv.toColor()),
        ),
      ],
    );
  }

  void _pick(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final offset = position - center;
    final radius = size.shortestSide / 2;
    final saturation = (offset.distance / radius).clamp(0.0, 1.0);
    final hue = (math.atan2(offset.dy, offset.dx) * 180 / math.pi + 360) % 360;
    setState(() => _hsv = _hsv.withHue(hue).withSaturation(saturation));
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final huePaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Colors.red,
          Colors.yellow,
          Colors.green,
          Colors.cyan,
          Colors.blue,
          Color(0xFFFF00FF),
          Colors.red,
        ],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, huePaint);

    final saturationPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0x00FFFFFF)],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, saturationPaint);
    if (hsv.value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - hsv.value),
      );
    }

    final angle = hsv.hue * math.pi / 180;
    final marker =
        center +
        Offset(math.cos(angle), math.sin(angle)) * radius * hsv.saturation;
    canvas.drawCircle(marker, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      9,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}
