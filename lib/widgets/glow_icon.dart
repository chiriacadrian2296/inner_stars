import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// An icon with a soft halo of its own colour behind it: a blurred copy of the
/// glyph under the crisp one, so the glow follows the icon's real shape.
///
/// [glow] scales the halo (0 draws just the icon). The halo spills past the
/// icon's box without taking any room, so it can sit in a tight row.
class GlowIcon extends StatelessWidget {
  const GlowIcon(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
    this.glow = 1,
  });

  final IconData icon;
  final double size;
  final Color color;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final crisp = Icon(icon, size: size, color: color);
    if (glow <= 0) return crisp;
    final sigma = size * 0.3 * glow;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
          child: Icon(icon, size: size, color: color.withValues(alpha: 0.9)),
        ),
        crisp,
      ],
    );
  }
}
