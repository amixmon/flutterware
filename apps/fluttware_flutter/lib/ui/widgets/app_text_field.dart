import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.autocorrect = true,
    this.enabled = true,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool autocorrect;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enabled: enabled,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(onPressed: onSuffixPressed, icon: Icon(suffixIcon)),
      ),
    );
  }
}
