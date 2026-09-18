import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nudges [LifeArea.physical]'s own hero art (see assets/images) a little
/// toward the app's own navy/white palette — its native, highly-saturated
/// blue reads as too vivid next to it. A small hue rotate (the art's own
/// blue sits at ~216° on the hue wheel; the app's own navy
/// (`AppColors.night`/`nightBorder`) sits at ~224°) plus a moderate
/// desaturation — not the full colorize [kPhysicalHeroArtTint] in
/// sky_area_backdrop.dart applies for the sky (which replaces hue outright
/// for a much bigger jump, blue to gold). This is meant to still read as
/// the same art, just toned down, so both adjustments are deliberately
/// small.
Widget tonedPhysicalArt({required Widget child}) {
  return ColorFiltered(
    colorFilter: _physicalArtDesaturate,
    child: ColorFiltered(colorFilter: _physicalArtHueNudge, child: child),
  );
}

// Brought down from an earlier 12° — since the rotation is uniform across
// every pixel regardless of its own starting hue, any highlight already
// sitting above ~216° (this art has plenty, being a gradient-lit figure
// rather than one flat color) got pushed past pure blue (240°) into violet
// at the larger angle — confirmed by exactly the complaint that angle
// produced: "too purple in spots", spots being those brighter highlights.
// This still nudges the average toward the app's own ~224° navy, just
// without the same risk of individual pixels overshooting past blue.
const double _physicalArtHueNudgeDegrees = 6;

/// How much of the art's own saturation survives (0 = grayscale, 1 =
/// unchanged) — picked by eye against the app's own muted navy, which
/// itself sits around 0.5-0.6 saturation versus the art's brightest
/// highlights up near 0.9-1.0.
const double _physicalArtSaturation = 0.55;

final ColorFilter _physicalArtHueNudge = _hueRotateFilter(
  _physicalArtHueNudgeDegrees,
);
final ColorFilter _physicalArtDesaturate = _saturateFilter(
  _physicalArtSaturation,
);

/// A [ColorFilter] that rotates every pixel's hue by [degrees] on the
/// standard 360° hue wheel, holding luminance/saturation constant — the SVG
/// filter spec's own `feColorMatrix type="hueRotate"` formula (a
/// luma-preserving rotation around the gray axis: R/G/B luminance weights
/// 0.213/0.715/0.072). Accurate for a small rotation like this one — the
/// distortion that formula is prone to only shows up on a *large* rotation
/// of a highly-saturated color (see [kPhysicalHeroArtTint]'s own doc
/// comment in sky_area_backdrop.dart for where that bit), not a nudge this
/// size.
ColorFilter _hueRotateFilter(double degrees) {
  final radians = degrees * math.pi / 180;
  final cosA = math.cos(radians);
  final sinA = math.sin(radians);

  return ColorFilter.matrix([
    0.213 + cosA * 0.787 - sinA * 0.213,
    0.715 - cosA * 0.715 - sinA * 0.715,
    0.072 - cosA * 0.072 + sinA * 0.928,
    0,
    0,
    0.213 - cosA * 0.213 + sinA * 0.143,
    0.715 + cosA * 0.285 + sinA * 0.140,
    0.072 - cosA * 0.072 - sinA * 0.283,
    0,
    0,
    0.213 - cosA * 0.213 - sinA * 0.787,
    0.715 - cosA * 0.715 + sinA * 0.715,
    0.072 + cosA * 0.928 + sinA * 0.072,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// A [ColorFilter] that scales every pixel's saturation by [factor] (0 =
/// grayscale, 1 = unchanged), holding hue/luminance in place — the SVG
/// filter spec's own `feColorMatrix type="saturate"` formula, blending each
/// channel toward the pixel's own luminance by `1 - factor`.
ColorFilter _saturateFilter(double factor) {
  const lumR = 0.213, lumG = 0.715, lumB = 0.072;
  final s = factor;

  return ColorFilter.matrix([
    lumR + (1 - lumR) * s, lumG * (1 - s), lumB * (1 - s), 0, 0, //
    lumR * (1 - s), lumG + (1 - lumG) * s, lumB * (1 - s), 0, 0, //
    lumR * (1 - s), lumG * (1 - s), lumB + (1 - lumB) * s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}
