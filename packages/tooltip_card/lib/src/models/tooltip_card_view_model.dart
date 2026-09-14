part of 'models.dart';

/// Constructor-specific fallback values used after explicit and themed values.
@immutable
class TooltipCardDefaults {
  const TooltipCardDefaults.builder()
    : hoverOpenDelay = TooltipCardTiming.hoverOpenDelay,
      hoverCloseDelay = TooltipCardTiming.hoverCloseDelay,
      awaySpace = TooltipCardSpacing.sm,
      elevation = TooltipCardConstants.defaultElevation,
      shadows = TooltipCardConstants.defaultShadows,
      borderRadius = TooltipCardConstants.defaultBorderRadius,
      borderWidth = TooltipCardConstants.defaultBorderWidth,
      padding = EdgeInsets.zero,
      barrierBlur = 0,
      beakEnabled = true,
      beakSize = TooltipCardConstants.defaultBeakSize,
      beakInset = TooltipCardConstants.defaultBeakInset;

  const TooltipCardDefaults.content()
    : hoverOpenDelay = const Duration(milliseconds: 300),
      hoverCloseDelay = const Duration(milliseconds: 300),
      awaySpace = TooltipCardSpacing.sm,
      elevation = TooltipCardConstants.defaultElevation,
      shadows = TooltipCardConstants.defaultShadows,
      borderRadius = TooltipCardConstants.defaultBorderRadius,
      borderWidth = TooltipCardConstants.defaultBorderWidth,
      padding = EdgeInsets.zero,
      barrierBlur = 0,
      beakEnabled = true,
      beakSize = TooltipCardConstants.defaultBeakSize,
      beakInset = TooltipCardConstants.defaultBeakInset;

  final Duration hoverOpenDelay;
  final Duration hoverCloseDelay;
  final double awaySpace;
  final double elevation;
  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final double barrierBlur;
  final bool beakEnabled;
  final double beakSize;
  final double beakInset;
}

/// Immutable presentation model consumed by TooltipCard views.
///
/// Resolution order is explicit widget value -> [TooltipCardThemeData] ->
/// ambient Material theme -> GeniusLink-compatible library default.
@immutable
class TooltipCardViewModel {
  const TooltipCardViewModel({
    required this.backgroundColor,
    required this.beakColor,
    required this.borderColor,
    required this.borderWidth,
    required this.elevation,
    required this.shadows,
    required this.borderRadius,
    required this.padding,
    required this.constraints,
    required this.awaySpace,
    required this.beakEnabled,
    required this.beakSize,
    required this.beakInset,
    required this.hoverOpenDelay,
    required this.hoverCloseDelay,
    required this.showDuration,
    required this.barrierColor,
    required this.barrierBlur,
  });

  factory TooltipCardViewModel.resolve({
    required ThemeData materialTheme,
    TooltipCardDefaults defaults = const TooltipCardDefaults.builder(),
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
  }) {
    final tooltipTheme = materialTheme.extension<TooltipCardThemeData>();
    final colorScheme = materialTheme.colorScheme;
    final resolvedBackground =
        backgroundColor ?? tooltipTheme?.backgroundColor ?? colorScheme.surface;
    final isDark = materialTheme.brightness == Brightness.dark;
    final defaultBorder = isDark
        ? colorScheme.outline
        : colorScheme.outlineVariant;
    final defaultBarrier = colorScheme.scrim.withValues(
      alpha: isDark ? 0.50 : 0.45,
    );

    return TooltipCardViewModel(
      backgroundColor: resolvedBackground,
      beakColor: beakColor ?? tooltipTheme?.beakColor ?? resolvedBackground,
      borderColor:
          borderColor ?? tooltipTheme?.borderColor ?? defaultBorder,
      borderWidth:
          borderWidth ?? tooltipTheme?.borderWidth ?? defaults.borderWidth,
      elevation: elevation ?? tooltipTheme?.elevation ?? defaults.elevation,
      shadows: shadows ?? tooltipTheme?.shadows ?? defaults.shadows,
      borderRadius:
          borderRadius ?? tooltipTheme?.borderRadius ?? defaults.borderRadius,
      padding: padding ?? tooltipTheme?.padding ?? defaults.padding,
      constraints: constraints ?? tooltipTheme?.constraints,
      awaySpace: awaySpace ?? tooltipTheme?.awaySpace ?? defaults.awaySpace,
      beakEnabled:
          beakEnabled ?? tooltipTheme?.beakEnabled ?? defaults.beakEnabled,
      beakSize: beakSize ?? tooltipTheme?.beakSize ?? defaults.beakSize,
      beakInset: beakInset ?? tooltipTheme?.beakInset ?? defaults.beakInset,
      hoverOpenDelay:
          hoverOpenDelay ??
          tooltipTheme?.hoverOpenDelay ??
          defaults.hoverOpenDelay,
      hoverCloseDelay:
          hoverCloseDelay ??
          tooltipTheme?.hoverCloseDelay ??
          defaults.hoverCloseDelay,
      showDuration: showDuration ?? tooltipTheme?.showDuration,
      barrierColor:
          barrierColor ?? tooltipTheme?.barrierColor ?? defaultBarrier,
      barrierBlur:
          barrierBlur ?? tooltipTheme?.barrierBlur ?? defaults.barrierBlur,
    );
  }

  final Color backgroundColor;
  final Color beakColor;
  final Color borderColor;
  final double borderWidth;
  final double elevation;
  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;
  final double awaySpace;
  final bool beakEnabled;
  final double beakSize;
  final double beakInset;
  final Duration hoverOpenDelay;
  final Duration hoverCloseDelay;
  final Duration? showDuration;
  final Color barrierColor;
  final double barrierBlur;
}
