import 'package:flutter/material.dart';

import '../models/life_area.dart';
import '../theme/app_colors.dart';

/// An area's artwork in the same square footprint as a Material icon.
/// Uses small resolution variants and decodes only the displayed pixel size.
class AreaIcon extends StatelessWidget {
  const AreaIcon({super.key, required this.area, this.size = 24, this.color});

  final LifeArea area;
  final double size;

  /// Defaults to the app's gold; override for muted/monochrome contexts.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
      1,
      192,
    );
    return Image.asset(
      'assets/images/area_icons/${area.name}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: pixels,
      cacheHeight: pixels,
      color: color ?? context.colors.gold,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
