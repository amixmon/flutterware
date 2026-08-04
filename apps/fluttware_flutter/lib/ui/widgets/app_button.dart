import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, outlined, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.busy = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool busy;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final callback = busy ? null : onPressed;
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (!busy && trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 20),
        ],
      ],
    );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton.tonal(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.text => TextButton(onPressed: callback, child: content),
      AppButtonVariant.danger => FilledButton(
        onPressed: callback,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
        child: content,
      ),
    };

    return SizedBox(
      width: expanded ? double.infinity : null,
      height: AppSizes.buttonHeight,
      child: button,
    );
  }
}
