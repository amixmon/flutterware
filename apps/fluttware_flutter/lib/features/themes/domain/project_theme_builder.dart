import 'package:flutter/material.dart';

import '../../projects/domain/project_configuration.dart';

abstract final class ProjectThemeBuilder {
  static Brightness brightnessFor(
    ProjectThemeSettings settings,
    Brightness platformBrightness,
  ) => switch (settings.mode) {
    ProjectThemeMode.system => platformBrightness,
    ProjectThemeMode.light => Brightness.light,
    ProjectThemeMode.dark => Brightness.dark,
  };

  static ThemeData build(ProjectThemeSettings settings, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Color(settings.seedColor),
      brightness: brightness,
    );
    final componentShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(settings.cornerRadius),
    );
    final buttonStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(componentShape),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: settings.fontFamily,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: settings.cardElevation,
        shape: componentShape,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: settings.inputFilled,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(settings.cornerRadius),
        ),
      ),
      dialogTheme: DialogThemeData(shape: componentShape),
    );
  }
}
