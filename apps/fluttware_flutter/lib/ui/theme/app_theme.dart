import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  /// Flutterware blue, sampled from the central ribbon of the brand mark.
  static const seedColor = Color(0xFF168CF3);

  // Neutral surfaces and editor accents from VS Code's modern dark family.
  static const _darkBackground = Color(0xFF181818);
  static const _darkEditor = Color(0xFF111111);
  static const _darkPanel = Color(0xFF1F1F1F);
  static const _darkRaised = Color(0xFF252526);
  static const _darkControl = Color(0xFF313131);
  static const _darkForeground = Color(0xFFD4D4D4);
  static const _darkMuted = Color(0xFFA6A6A6);
  static const _darkBlue = Color(0xFF3794FF);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static SystemUiOverlayStyle systemOverlay(ColorScheme colors) {
    final dark = colors.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final seededColors = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    final colors = seededColors.copyWith(
      primary: dark ? _darkBlue : seededColors.primary,
      onPrimary: dark ? const Color(0xFFFFFFFF) : seededColors.onPrimary,
      primaryContainer: dark
          ? const Color(0xFF0E639C)
          : seededColors.primaryContainer,
      onPrimaryContainer: dark
          ? const Color(0xFFFFFFFF)
          : seededColors.onPrimaryContainer,
      secondary: dark ? const Color(0xFFDCDCAA) : seededColors.secondary,
      onSecondary: dark ? const Color(0xFF1F1F1F) : seededColors.onSecondary,
      secondaryContainer: dark
          ? const Color(0xFF37373D)
          : seededColors.secondaryContainer,
      onSecondaryContainer: dark
          ? const Color(0xFFE7E7E7)
          : seededColors.onSecondaryContainer,
      tertiary: dark ? const Color(0xFFCE9178) : seededColors.tertiary,
      error: dark ? const Color(0xFFF14C4C) : seededColors.error,
      surface: dark ? _darkBackground : const Color(0xFFF8FAFF),
      onSurface: dark ? _darkForeground : seededColors.onSurface,
      onSurfaceVariant: dark ? _darkMuted : seededColors.onSurfaceVariant,
      surfaceDim: dark ? _darkEditor : const Color(0xFFD8E2EE),
      surfaceBright: dark ? const Color(0xFF3C3C3C) : const Color(0xFFF8FAFF),
      surfaceContainerLowest: dark ? _darkEditor : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark ? _darkBackground : const Color(0xFFF1F5FB),
      surfaceContainer: dark ? _darkPanel : const Color(0xFFEBF1F8),
      surfaceContainerHigh: dark ? _darkRaised : const Color(0xFFE5EBF3),
      surfaceContainerHighest: dark ? _darkControl : const Color(0xFFDFE7F0),
      outline: dark ? const Color(0xFF626262) : seededColors.outline,
      outlineVariant: dark
          ? const Color(0xFF353535)
          : seededColors.outlineVariant,
      inverseSurface: dark
          ? const Color(0xFFE7E7E7)
          : seededColors.inverseSurface,
      onInverseSurface: dark
          ? const Color(0xFF1F1F1F)
          : seededColors.onInverseSurface,
      shadow: dark ? Colors.black : seededColors.shadow,
      scrim: dark ? Colors.black : seededColors.scrim,
    );
    final inactiveField = OutlineInputBorder(
      borderRadius: AppRadii.inputBorder,
      borderSide: BorderSide(color: colors.outlineVariant, width: 1),
    );
    final rippleOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return colors.primary.withValues(alpha: 0.14);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colors.primary.withValues(alpha: 0.08);
      }
      return null;
    });

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      splashFactory: InkRipple.splashFactory,
      splashColor: colors.primary.withValues(alpha: 0.14),
      highlightColor: colors.primary.withValues(alpha: 0.08),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlay(colors),
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
        border: inactiveField,
        enabledBorder: inactiveField,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .55),
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, AppSizes.buttonHeight),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, AppSizes.buttonHeight),
          elevation: 0,
          side: BorderSide(color: colors.outline),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.buttonHeight),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        indicatorColor: colors.secondaryContainer,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        indicatorColor: colors.primary,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        overlayColor: rippleOverlay,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.onSurfaceVariant),
          overlayColor: rippleOverlay,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.14),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.outline,
        ),
        overlayColor: rippleOverlay,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.secondaryContainer,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        modalBackgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.inputBorder),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        circularTrackColor: colors.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.inputBorder),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
