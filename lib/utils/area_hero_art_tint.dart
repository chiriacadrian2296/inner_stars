import 'package:flutter/material.dart';

import 'area_hero_art.dart';

/// The same canonical gold as `AppColors.dark.gold`. Kept here as a constant
/// because the painter also needs a theme-independent constructor default.
const Color kAreaHeroArtTintHue = Color(0xFFF2B84B);

/// Applies one flat gold to the non-transparent emblem pixels. The temporary
/// Royal Symbols previews are already isolated on transparent canvases, so
/// this adds neither a background nor a gradient.
ColorFilter areaHeroArtTint(Color color) => ColorFilter.mode(
  color,
  kUseRoyalArtworkPreview ? BlendMode.srcIn : BlendMode.hue,
);
