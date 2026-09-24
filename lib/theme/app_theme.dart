import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_motion.dart';
import 'app_style.dart';

/// The app's one and only theme — night sky, gold stars. There's no light
/// mode: a "daytime sky" doesn't fit an app about lighting stars against a
/// dark backdrop, so [AppColors] has never had more than the one palette
/// this builds from.
///
/// Every Material component the app actually uses is themed here rather
/// than styled per call site. That's deliberate: switches used to carry
/// four different color sets, filled buttons five different corner radii,
/// and dialogs a `backgroundColor` re-specified at each of nine sites.
/// Anything a screen still overrides locally should be a real exception,
/// not a default being restated.
ThemeData buildAppTheme({AppColors palette = AppColors.dark}) {
  const brightness = Brightness.dark;

  /// A filled gold button's glow, expressed the one way a [ButtonStyle]
  /// can express it: a colored elevation shadow. Same idea as [goldGlow],
  /// which the hand-built surfaces use.
  const litElevation = 6.0;

  OutlineInputBorder inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusField),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.night,
    // One shared-axis push/pop for every route; see [AppPageTransitionsBuilder].
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AppPageTransitionsBuilder(),
        TargetPlatform.iOS: AppPageTransitionsBuilder(),
        TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
        TargetPlatform.linux: AppPageTransitionsBuilder(),
        TargetPlatform.macOS: AppPageTransitionsBuilder(),
        TargetPlatform.windows: AppPageTransitionsBuilder(),
      },
    ),
    colorScheme: ColorScheme.dark(
      primary: palette.gold,
      onPrimary: palette.onGold,
      surface: palette.nightPanel,
      onSurface: palette.text,
      error: palette.danger,
    ),
    // Instrument Sans is the app's one default typeface — every widget that
    // doesn't ask for [kFontStarTitle], [kFontBranding] or [kFontMono] by
    // name (see app_fonts.dart) renders in this without having to say so.
    fontFamily: kFontBody,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: palette.text,
      displayColor: palette.text,
      fontFamily: kFontBody,
    ),
    // The empty/focused halves of the field rule (see [FieldState]); the
    // filled half needs to know whether there's text in the box, so it
    // lives in `AppTextField`, which is what screens actually use.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.nightPanel,
      hintStyle: TextStyle(color: palette.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: inputBorder(palette.nightBorder, kBorderWidth),
      enabledBorder: inputBorder(palette.nightBorder, kBorderWidth),
      focusedBorder: inputBorder(palette.gold, kBorderWidthActive),
    ),
    // On = lit: gold track, dark thumb, the same "filled with gold" the
    // rest of the app uses for an active control. Off = dark: no fill, a
    // muted outline and a muted thumb. Previously four call sites each
    // invented their own combination, including one that left Material 3's
    // defaults showing a near-white thumb on a near-white track.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.nightPanel
            : palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.gold
            : Colors.transparent,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.gold
            : palette.muted,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(kBorderWidth),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: palette.nightPanel,
        foregroundColor: palette.muted,
        selectedBackgroundColor: palette.gold,
        selectedForegroundColor: palette.onGold,
        side: BorderSide(color: palette.nightBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusField),
        ),
      ),
    ),
    // Filled actions are pills, everywhere. That shape is what separates
    // "this does something" from "this holds something" (fields and cards,
    // which are rounded rectangles) without needing a color difference to
    // carry it.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.gold,
        foregroundColor: palette.onGold,
        disabledBackgroundColor: palette.nightPanel,
        disabledForegroundColor: palette.muted,
        elevation: litElevation,
        shadowColor: palette.gold.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.gold,
        disabledForegroundColor: palette.muted,
        side: BorderSide(color: palette.gold, width: kBorderWidthActive),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.gold,
        disabledForegroundColor: palette.muted,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.gold,
      foregroundColor: palette.onGold,
      elevation: 0,
      shape: const CircleBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.nightPanel,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: palette.muted,
        fontSize: 14,
        height: 1.45,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.nightPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusCard)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.gold,
      inactiveTrackColor: palette.nightBorder,
      thumbColor: palette.gold,
      overlayColor: palette.gold.withValues(alpha: 0.15),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: palette.nightPanel,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: palette.nightBorder, thickness: 1),
    iconTheme: IconThemeData(color: palette.muted),
    // Material 3's default (teal, from an unset colorScheme.secondary) shows
    // through on the time picker's AM/PM and hour/minute toggles otherwise —
    // themed explicitly here so any time/date picker anywhere in the app
    // stays on-brand, not just the one screen that first surfaced it.
    timePickerTheme: TimePickerThemeData(
      backgroundColor: palette.nightPanel,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.gold.withValues(alpha: 0.2)
            : palette.night,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? palette.gold : palette.text,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.gold
            : palette.nightPanel,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.onGold
            : palette.muted,
      ),
      dayPeriodBorderSide: BorderSide(color: palette.nightBorder),
      dialHandColor: palette.gold,
      dialBackgroundColor: palette.night,
      dialTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.onGold
            : palette.text,
      ),
      entryModeIconColor: palette.muted,
    ),
    // Same reasoning as timePickerTheme above: keep the date picker (used
    // when backdating a star, and for the search date-range filter) on-brand
    // instead of Material 3's default teal.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: palette.nightPanel,
      headerBackgroundColor: palette.gold,
      headerForegroundColor: palette.onGold,
      // The connecting band `showDateRangePicker` paints behind an in-range
      // day (confirmed live: without this it defaults to
      // `colorScheme.secondaryContainer`, which `ColorScheme.dark()` leaves
      // at Material's own hardcoded teal since this app never sets it) — a
      // light wash of the same gold everything else here burns with.
      rangeSelectionBackgroundColor: palette.gold.withValues(alpha: 0.22),
      // Selected wins over "is today" — otherwise the day number renders
      // gold-on-gold (invisible) when today happens to be the selected day,
      // since the circle fill already switches to gold once selected.
      todayForegroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.onGold
            : palette.gold,
      ),
      todayBorder: BorderSide(color: palette.gold),
      dayForegroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.onGold
            : palette.text,
      ),
      dayBackgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.gold
            : Colors.transparent,
      ),
      yearForegroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.onGold
            : palette.text,
      ),
      yearBackgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.gold
            : Colors.transparent,
      ),
    ),
    extensions: [palette],
  );
}
