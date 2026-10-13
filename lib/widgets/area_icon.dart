import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/life_area.dart';
import '../theme/app_colors.dart';

/// An area's artwork in the same square footprint as a Material icon.
/// Uses clean vector shapes drawn for small UI sizes.
class AreaIcon extends StatelessWidget {
  const AreaIcon({super.key, required this.area, this.size = 24, this.color});

  final LifeArea area;
  final double size;

  /// Defaults to the app's gold; override for muted/monochrome contexts.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/area_icons/${area.name}.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        color ?? context.colors.gold,
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
  }
}
