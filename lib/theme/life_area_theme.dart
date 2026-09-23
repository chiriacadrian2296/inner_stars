import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// Rebuild every component from the area palette, including focus states.
/// Changing only ColorScheme leaves the app's explicit gold overrides intact.
ThemeData buildLifeAreaTheme() {
  final theme = buildAppTheme(
    palette: AppColors.dark.copyWith(
      night: Colors.black,
      gold: Colors.white,
      onGold: const Color(0xFF0D1220),
      accentDim: Colors.white24,
    ),
  );
  const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  return theme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: theme.colorScheme.copyWith(
      secondary: Colors.white,
      onSecondary: const Color(0xFF0D1220),
      tertiary: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionColor: Colors.white24,
      selectionHandleColor: Colors.white,
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      backgroundColor: Colors.black,
    ),
    sliderTheme: theme.sliderTheme.copyWith(
      valueIndicatorColor: Colors.white,
      valueIndicatorTextStyle: const TextStyle(color: Color(0xFF0D1220)),
      activeTickMarkColor: const Color(0xFF0D1220),
      inactiveTickMarkColor: Colors.white54,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: theme.elevatedButtonTheme.style!.copyWith(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFF141D30)),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        side: const WidgetStatePropertyAll(BorderSide(color: Colors.white)),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(padding),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: theme.outlinedButtonTheme.style!.copyWith(
        padding: const WidgetStatePropertyAll(padding),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style!.copyWith(
        padding: const WidgetStatePropertyAll(padding),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      ),
    ),
  );
}
