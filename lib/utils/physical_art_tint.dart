import 'package:flutter/material.dart';

/// A fully-saturated color at hue 48° — between the app's own
/// [kConstellationGold]/`_kLabelGold` (both ~39-42°, see
/// constellation_field.dart) and true yellow (60°), leaning further toward
/// yellow than either. Only its hue matters (see [kPhysicalHeroArtTint]'s
/// own doc comment for why), so its own saturation/lightness were picked
/// simply for a clean, legible hex rather than for any visual effect of
/// their own.
const Color kPhysicalArtTintHue = Color(0xFFFFCC00);

/// Recolors [LifeArea.physical]'s own hero art (see assets/images) — a
/// mostly-monochrome blue-on-black nebula — into the app's own gold family,
/// via `BlendMode.hue` (Skia's non-separable "Hue" blend, the same one the
/// CSS/PDF spec define: `SetLum(SetSat(source, Sat(backdrop)), Lum(backdrop))`).
/// That formula only ever reads [kPhysicalArtTintHue]'s *hue* — its own
/// saturation and luminosity are discarded and replaced by each backdrop
/// (image) pixel's own, which is exactly what's wanted: every pixel keeps
/// its own brightness/contrast (so the nebula's own highlights/shadows
/// survive), only its hue changes.
///
/// Replaces an earlier attempt built from a hand-rolled rotation-matrix
/// hue-rotate (the SVG `feColorMatrix type="hueRotate"` formula, rotating
/// by a computed delta angle) — mathematically a rotation in linear RGB
/// space around the luma axis, not a true HSL hue swap, and for a rotation
/// this large (the art's own blue sits at ~216°, most of the way around
/// the wheel from gold) it visibly overshot toward orange on this image's
/// saturated blues. `BlendMode.hue` has no such error: it lands exactly on
/// the chosen hue for every pixel, natively, with no approximation.
const ColorFilter kPhysicalHeroArtTint = ColorFilter.mode(
  kPhysicalArtTintHue,
  BlendMode.hue,
);
