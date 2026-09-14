part of 'models.dart';

/// TooltipCard tokens aligned with the GeniusLink design system from
/// `super_core` v1.2.0.
///
/// The package intentionally keeps these small, framework-only tokens local so
/// it remains publishable without forcing applications to depend on
/// `super_core`. Applications that install `SuperMaterialThemeData` are picked
/// up automatically through the ambient [ThemeData] and [ColorScheme].
abstract final class TooltipCardDesignTokens {
  // Brand and semantic colors.
  static const Color accent = Color(0xFF4A7CFF);
  static const Color accentDark = Color(0xFFA3B9FF);
  static const Color success = Color(0xFF1DB88A);
  static const Color warning = Color(0xFFF97316);
  static const Color danger = Color(0xFFEF4444);

  // Additional built-in SuperPalette shades used by examples and templates.
  static const Color purple100 = Color(0xFFE9E4FF);
  static const Color purple500 = Color(0xFF7C5CFC);
  static const Color purple700 = Color(0xFF5535D4);
  static const Color green400 = Color(0xFF2ED0A1);
  static const Color gray300 = Color(0xFFC2C6D6);
  static const Color gray400 = Color(0xFF8D90A0);
  static const Color gray500 = Color(0xFF64748B);
  static const Color golden700 = Color(0xFFB45309);

  // Light surfaces.
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInputBackground = Color(0xFFF1F3F8);
  static const Color lightHover = Color(0xFFEEF1F7);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderStrong = Color(0xFFC2C6D6);
  static const Color lightForegroundPrimary = Color(0xFF0F172A);
  static const Color lightForegroundSecondary = Color(0xFF424754);
  static const Color lightForegroundTertiary = Color(0xFF64748B);
  static const Color lightForegroundDisabled = Color(0xFFAEB4C2);

  // Dark surfaces.
  static const Color darkBackground = Color(0xFF111318);
  static const Color darkSurface = Color(0xFF1E2025);
  static const Color darkSurfaceRaised = Color(0xFF292D38);
  static const Color darkInputBackground = Color(0xFF33353A);
  static const Color darkHover = Color(0xFF2F3540);
  static const Color darkBorder = Color(0x6643464F);
  static const Color darkBorderStrong = Color(0xFF434654);
  static const Color darkForegroundPrimary = Color(0xFFE2E2E9);
  static const Color darkForegroundSecondary = Color(0xFFC3C6D7);
  static const Color darkForegroundTertiary = Color(0xFF8D90A0);
  static const Color darkForegroundDisabled = Color(0xFF5A5D68);

  // Typography.
  static const String displayFont = 'Manrope';
  static const String bodyFont = 'Inter';
  static const String monoFont = 'JetBrainsMono';
  static const String arabicFont = 'NotoNaskhArabic';

  // Radii.
  static const double radiusControl = 4;
  static const double radiusMedium = 6;
  static const double radiusCard = 8;
  static const double radiusPill = 12;

  // Motion.
  static const Duration durationFast = Duration(milliseconds: 100);
  static const Duration durationBase = Duration(milliseconds: 150);
  static const Duration durationExpand = Duration(milliseconds: 200);
  static const Curve curveStandard = Cubic(0.4, 0, 0.2, 1);
  static const Curve curveOut = Cubic(0, 0, 0.2, 1);

  /// Overlay/popover shadow used by menus, flyouts, and TooltipCard panels.
  static const List<BoxShadow> popoverShadow = [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 10),
    ),
  ];
}

/// Spacing tokens using the GeniusLink 4px base unit.
abstract final class TooltipCardSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 40;
}

/// Animation timing constants.
abstract final class TooltipCardTiming {
  static const Duration fast = TooltipCardDesignTokens.durationFast;
  static const Duration enterDuration = TooltipCardDesignTokens.durationExpand;
  static const Duration exitDuration = TooltipCardDesignTokens.durationBase;
  static const Duration hoverOpenDelay = Duration(milliseconds: 500);
  static const Duration hoverCloseDelay = Duration(milliseconds: 250);
}

/// Animation curves aligned with the Super design-system motion language.
abstract final class TooltipCardCurves {
  static const Curve fade = TooltipCardDesignTokens.curveOut;
  static const Curve fadeOut = TooltipCardDesignTokens.curveStandard;
  static const Curve scaleIn = TooltipCardDesignTokens.curveOut;
  static const Curve scaleOut = TooltipCardDesignTokens.curveStandard;
  static const Curve slideIn = TooltipCardDesignTokens.curveOut;
  static const Curve slideOut = TooltipCardDesignTokens.curveStandard;

  // Expressive animations remain available, but standard TooltipCard motion
  // uses the restrained curves above.
  static const Curve bounce = Curves.bounceOut;
  static const Curve bounceIn = Curves.easeOutBack;
  static const Curve elastic = Curves.elasticOut;
  static const Curve elasticIn = Curves.easeOutBack;
  static const Curve zoom = Curves.easeOutBack;
  static const Curve zoomOut = Curves.easeInBack;
}

/// Sizing and layout constants.
abstract final class TooltipCardConstants {
  static const double defaultMaxWidth = 360;

  /// SuperCore popovers use a custom shadow rather than Material elevation.
  static const double defaultElevation = 0;

  static const double positionEpsilon = 0.5;
  static const double shadowOpacity = 0.35;
  static const double defaultBeakSize = 8;
  static const double defaultBeakInset = 16;
  static const double defaultBorderWidth = 1;
  static const double defaultIconSize = 20;

  static const BorderRadius defaultBorderRadius = BorderRadius.all(
    Radius.circular(TooltipCardDesignTokens.radiusCard),
  );

  static const List<BoxShadow> defaultShadows =
      TooltipCardDesignTokens.popoverShadow;
}
