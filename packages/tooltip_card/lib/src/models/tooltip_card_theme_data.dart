part of 'models.dart';

/// Theme extension for customizing TooltipCard appearance across the app.
///
/// The default factories follow the same surfaces, typography, 4px spacing,
/// radii, motion, and popover treatment as the GeniusLink design system in
/// `super_core` v1.2.0.
@immutable
class TooltipCardThemeData extends ThemeExtension<TooltipCardThemeData> {
  const TooltipCardThemeData({
    this.backgroundColor,
    this.beakColor,
    this.borderColor,
    this.borderWidth,
    this.elevation,
    this.shadows,
    this.borderRadius,
    this.padding,
    this.constraints,
    this.awaySpace,
    this.beakSize,
    this.beakInset,
    this.beakEnabled,
    this.hoverOpenDelay,
    this.hoverCloseDelay,
    this.showDuration,
    this.barrierColor,
    this.barrierBlur,
    this.titleStyle,
    this.subtitleStyle,
    this.contentTextStyle,
    this.iconColor,
    this.iconSize,
    this.actionSpacing,
    this.contentMaxWidth,
    this.contentPadding,
    this.contentSpacing,
  });

  // Appearance.
  final Color? backgroundColor;
  final Color? beakColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? elevation;
  final List<BoxShadow>? shadows;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double? awaySpace;

  // Beak.
  final bool? beakEnabled;
  final double? beakSize;
  final double? beakInset;

  // Timing.
  final Duration? hoverOpenDelay;
  final Duration? hoverCloseDelay;
  final Duration? showDuration;

  // Modal barrier.
  final Color? barrierColor;
  final double? barrierBlur;

  // TooltipCardContent styles.
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? contentTextStyle;
  final Color? iconColor;
  final double? iconSize;
  final double? actionSpacing;
  final double? contentMaxWidth;
  final EdgeInsetsGeometry? contentPadding;
  final double? contentSpacing;

  /// Creates a TooltipCard theme matching the `super_core` design system.
  ///
  /// [accentColor] should be the active palette primary color. For a dark theme,
  /// pass the palette's lighter dark-mode primary shade.
  factory TooltipCardThemeData.superCore({
    Brightness brightness = Brightness.light,
    Color? accentColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark
        ? TooltipCardDesignTokens.darkSurface
        : TooltipCardDesignTokens.lightSurface;
    final foregroundPrimary = isDark
        ? TooltipCardDesignTokens.darkForegroundPrimary
        : TooltipCardDesignTokens.lightForegroundPrimary;
    final foregroundTertiary = isDark
        ? TooltipCardDesignTokens.darkForegroundTertiary
        : TooltipCardDesignTokens.lightForegroundTertiary;

    return TooltipCardThemeData(
      backgroundColor: surface,
      beakColor: surface,
      borderColor: isDark
          ? TooltipCardDesignTokens.darkBorderStrong
          : TooltipCardDesignTokens.lightBorderStrong,
      borderWidth: TooltipCardConstants.defaultBorderWidth,
      elevation: TooltipCardConstants.defaultElevation,
      shadows: TooltipCardConstants.defaultShadows,
      borderRadius: TooltipCardConstants.defaultBorderRadius,
      padding: EdgeInsets.zero,
      awaySpace: TooltipCardSpacing.sm,
      beakEnabled: true,
      beakSize: TooltipCardConstants.defaultBeakSize,
      beakInset: TooltipCardConstants.defaultBeakInset,
      hoverOpenDelay: TooltipCardTiming.hoverOpenDelay,
      hoverCloseDelay: TooltipCardTiming.hoverCloseDelay,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.50 : 0.45),
      barrierBlur: 0,
      titleStyle: TextStyle(
        fontFamily: TooltipCardDesignTokens.bodyFont,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: foregroundPrimary,
      ),
      subtitleStyle: TextStyle(
        fontFamily: TooltipCardDesignTokens.bodyFont,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: foregroundTertiary,
      ),
      contentTextStyle: TextStyle(
        fontFamily: TooltipCardDesignTokens.bodyFont,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: foregroundPrimary,
      ),
      iconColor:
          accentColor ??
          (isDark
              ? TooltipCardDesignTokens.accentDark
              : TooltipCardDesignTokens.accent),
      iconSize: TooltipCardConstants.defaultIconSize,
      actionSpacing: TooltipCardSpacing.sm,
      contentMaxWidth: TooltipCardConstants.defaultMaxWidth,
      contentPadding: const EdgeInsets.all(TooltipCardSpacing.lg),
      contentSpacing: TooltipCardSpacing.md,
    );
  }

  /// Creates the standard light GeniusLink TooltipCard theme.
  factory TooltipCardThemeData.light({Color? primaryColor}) =>
      TooltipCardThemeData.superCore(
        brightness: Brightness.light,
        accentColor: primaryColor,
      );

  /// Creates the standard dark GeniusLink TooltipCard theme.
  factory TooltipCardThemeData.dark({Color? primaryColor}) =>
      TooltipCardThemeData.superCore(
        brightness: Brightness.dark,
        accentColor: primaryColor,
      );

  /// Legacy Fluent-inspired preset retained for source compatibility.
  factory TooltipCardThemeData.fluent({
    Brightness brightness = Brightness.light,
    Color? accentColor,
  }) {
    final base = TooltipCardThemeData.superCore(
      brightness: brightness,
      accentColor: accentColor,
    );
    return base.copyWith(
      borderRadius: BorderRadius.circular(
        TooltipCardDesignTokens.radiusCard,
      ),
      beakSize: TooltipCardSpacing.md,
      contentPadding: const EdgeInsets.all(TooltipCardSpacing.md),
      contentSpacing: TooltipCardSpacing.sm,
    );
  }

  @override
  TooltipCardThemeData copyWith({
    Color? backgroundColor,
    Color? beakColor,
    Color? borderColor,
    double? borderWidth,
    double? elevation,
    List<BoxShadow>? shadows,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    BoxConstraints? constraints,
    double? awaySpace,
    bool? beakEnabled,
    double? beakSize,
    double? beakInset,
    Duration? hoverOpenDelay,
    Duration? hoverCloseDelay,
    Duration? showDuration,
    Color? barrierColor,
    double? barrierBlur,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? contentTextStyle,
    Color? iconColor,
    double? iconSize,
    double? actionSpacing,
    double? contentMaxWidth,
    EdgeInsetsGeometry? contentPadding,
    double? contentSpacing,
  }) {
    return TooltipCardThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      beakColor: beakColor ?? this.beakColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      elevation: elevation ?? this.elevation,
      shadows: shadows ?? this.shadows,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      constraints: constraints ?? this.constraints,
      awaySpace: awaySpace ?? this.awaySpace,
      beakEnabled: beakEnabled ?? this.beakEnabled,
      beakSize: beakSize ?? this.beakSize,
      beakInset: beakInset ?? this.beakInset,
      hoverOpenDelay: hoverOpenDelay ?? this.hoverOpenDelay,
      hoverCloseDelay: hoverCloseDelay ?? this.hoverCloseDelay,
      showDuration: showDuration ?? this.showDuration,
      barrierColor: barrierColor ?? this.barrierColor,
      barrierBlur: barrierBlur ?? this.barrierBlur,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      contentTextStyle: contentTextStyle ?? this.contentTextStyle,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
      actionSpacing: actionSpacing ?? this.actionSpacing,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      contentPadding: contentPadding ?? this.contentPadding,
      contentSpacing: contentSpacing ?? this.contentSpacing,
    );
  }

  @override
  TooltipCardThemeData lerp(TooltipCardThemeData? other, double t) {
    if (other == null) return this;
    return TooltipCardThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      beakColor: Color.lerp(beakColor, other.beakColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t),
      elevation: lerpDouble(elevation, other.elevation, t),
      shadows: _lerpShadows(shadows, other.shadows, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      constraints: BoxConstraints.lerp(constraints, other.constraints, t),
      awaySpace: lerpDouble(awaySpace, other.awaySpace, t),
      beakEnabled: t < 0.5 ? beakEnabled : other.beakEnabled,
      beakSize: lerpDouble(beakSize, other.beakSize, t),
      beakInset: lerpDouble(beakInset, other.beakInset, t),
      hoverOpenDelay: t < 0.5 ? hoverOpenDelay : other.hoverOpenDelay,
      hoverCloseDelay: t < 0.5 ? hoverCloseDelay : other.hoverCloseDelay,
      showDuration: t < 0.5 ? showDuration : other.showDuration,
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t),
      barrierBlur: lerpDouble(barrierBlur, other.barrierBlur, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      contentTextStyle: TextStyle.lerp(
        contentTextStyle,
        other.contentTextStyle,
        t,
      ),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      actionSpacing: lerpDouble(actionSpacing, other.actionSpacing, t),
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t),
      contentPadding: EdgeInsetsGeometry.lerp(
        contentPadding,
        other.contentPadding,
        t,
      ),
      contentSpacing: lerpDouble(contentSpacing, other.contentSpacing, t),
    );
  }

  static List<BoxShadow>? _lerpShadows(
    List<BoxShadow>? a,
    List<BoxShadow>? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return BoxShadow.lerpList(a ?? const [], b ?? const [], t);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TooltipCardThemeData &&
        other.backgroundColor == backgroundColor &&
        other.beakColor == beakColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.elevation == elevation &&
        listEquals(other.shadows, shadows) &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.constraints == constraints &&
        other.awaySpace == awaySpace &&
        other.beakEnabled == beakEnabled &&
        other.beakSize == beakSize &&
        other.beakInset == beakInset &&
        other.hoverOpenDelay == hoverOpenDelay &&
        other.hoverCloseDelay == hoverCloseDelay &&
        other.showDuration == showDuration &&
        other.barrierColor == barrierColor &&
        other.barrierBlur == barrierBlur &&
        other.titleStyle == titleStyle &&
        other.subtitleStyle == subtitleStyle &&
        other.contentTextStyle == contentTextStyle &&
        other.iconColor == iconColor &&
        other.iconSize == iconSize &&
        other.actionSpacing == actionSpacing &&
        other.contentMaxWidth == contentMaxWidth &&
        other.contentPadding == contentPadding &&
        other.contentSpacing == contentSpacing;
  }

  @override
  int get hashCode => Object.hashAll([
    backgroundColor,
    beakColor,
    borderColor,
    borderWidth,
    elevation,
    Object.hashAll(shadows ?? const []),
    borderRadius,
    padding,
    constraints,
    awaySpace,
    beakEnabled,
    beakSize,
    beakInset,
    hoverOpenDelay,
    hoverCloseDelay,
    showDuration,
    barrierColor,
    barrierBlur,
    titleStyle,
    subtitleStyle,
    contentTextStyle,
    iconColor,
    iconSize,
    actionSpacing,
    contentMaxWidth,
    contentPadding,
    contentSpacing,
  ]);

  @override
  String toString() =>
      'TooltipCardThemeData('
      'backgroundColor: $backgroundColor, '
      'borderColor: $borderColor, '
      'borderRadius: $borderRadius'
      ')';
}

extension TooltipCardThemeDataExtension on BuildContext {
  TooltipCardThemeData? get tooltipCardTheme =>
      Theme.of(this).extension<TooltipCardThemeData>();
}
