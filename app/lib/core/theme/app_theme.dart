import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Builds the single dark, minimal, accent-driven theme. Typography falls back
/// gracefully if the Inter font is not yet cached.
ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppTokens.background,
    colorScheme: const ColorScheme.dark(
      primary: AppTokens.accent,
      secondary: AppTokens.accent,
      surface: AppTokens.surface,
      error: AppTokens.danger,
    ),
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppTokens.textPrimary,
    displayColor: AppTokens.textPrimary,
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppTokens.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppTokens.hairline,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppTokens.surfaceElevated,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppTokens.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusInner),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppTokens.surface,
      modalBackgroundColor: AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppTokens.accent,
      selectionColor: AppTokens.accentSoft,
      selectionHandleColor: AppTokens.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTokens.surfaceElevated,
      hintStyle: const TextStyle(color: AppTokens.textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusInner),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusInner),
        borderSide: const BorderSide(color: AppTokens.accent, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppTokens.accent
            : AppTokens.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppTokens.accentSoft
            : AppTokens.surfaceInteractive,
      ),
    ),
  );
}
