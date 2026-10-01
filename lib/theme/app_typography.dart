import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// Semantic type roles for the standard gold/night interface.
///
/// Immersive area-management and Nightlight screens may provide their own
/// ThemeData; every other screen should choose a role here instead of
/// inventing a font size at the call site.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.immersivePageTitle,
    required this.utilityPageTitle,
    required this.sectionHeading,
    required this.compactSectionLabel,
    required this.body,
    required this.supporting,
    required this.controlLabel,
    required this.microLabel,
  });

  factory AppTypography.fromColors(AppColors colors) => AppTypography(
    immersivePageTitle: TextStyle(
      color: colors.text,
      fontFamily: kFontStarTitle,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      height: 1.08,
    ),
    utilityPageTitle: TextStyle(
      color: colors.text,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    sectionHeading: TextStyle(
      color: colors.text,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    compactSectionLabel: TextStyle(
      color: colors.muted,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
    body: TextStyle(color: colors.text, fontSize: 15, height: 1.5),
    supporting: TextStyle(color: colors.muted, fontSize: 14, height: 1.45),
    controlLabel: TextStyle(
      color: colors.text,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
    microLabel: TextStyle(
      color: colors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  final TextStyle immersivePageTitle;
  final TextStyle utilityPageTitle;
  final TextStyle sectionHeading;
  final TextStyle compactSectionLabel;
  final TextStyle body;
  final TextStyle supporting;
  final TextStyle controlLabel;
  final TextStyle microLabel;

  @override
  AppTypography copyWith({
    TextStyle? immersivePageTitle,
    TextStyle? utilityPageTitle,
    TextStyle? sectionHeading,
    TextStyle? compactSectionLabel,
    TextStyle? body,
    TextStyle? supporting,
    TextStyle? controlLabel,
    TextStyle? microLabel,
  }) => AppTypography(
    immersivePageTitle: immersivePageTitle ?? this.immersivePageTitle,
    utilityPageTitle: utilityPageTitle ?? this.utilityPageTitle,
    sectionHeading: sectionHeading ?? this.sectionHeading,
    compactSectionLabel: compactSectionLabel ?? this.compactSectionLabel,
    body: body ?? this.body,
    supporting: supporting ?? this.supporting,
    controlLabel: controlLabel ?? this.controlLabel,
    microLabel: microLabel ?? this.microLabel,
  );

  @override
  AppTypography lerp(covariant AppTypography? other, double t) {
    if (other == null) return this;
    return AppTypography(
      immersivePageTitle: TextStyle.lerp(
        immersivePageTitle,
        other.immersivePageTitle,
        t,
      )!,
      utilityPageTitle: TextStyle.lerp(
        utilityPageTitle,
        other.utilityPageTitle,
        t,
      )!,
      sectionHeading: TextStyle.lerp(sectionHeading, other.sectionHeading, t)!,
      compactSectionLabel: TextStyle.lerp(
        compactSectionLabel,
        other.compactSectionLabel,
        t,
      )!,
      body: TextStyle.lerp(body, other.body, t)!,
      supporting: TextStyle.lerp(supporting, other.supporting, t)!,
      controlLabel: TextStyle.lerp(controlLabel, other.controlLabel, t)!,
      microLabel: TextStyle.lerp(microLabel, other.microLabel, t)!,
    );
  }
}

extension AppTypographyContext on BuildContext {
  AppTypography get typography => Theme.of(this).extension<AppTypography>()!;
}
