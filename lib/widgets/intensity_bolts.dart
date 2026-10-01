import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The standard way a win's 1-5 intensity is shown: five bolts, filled up to
/// [intensity]. A bolt rather than a star — a star is what's *created* by a
/// win, so representing its own intensity with more (smaller) stars didn't
/// make much conceptual sense.
class IntensityBolts extends StatelessWidget {
  const IntensityBolts({
    super.key,
    required this.intensity,
    this.size = 14,
    this.spacing = 2,
    this.color,
    this.emphasizeLast = false,
    this.emphasizedScale = 1.35,
  });

  final int intensity;
  final double size;
  final double spacing;
  final Color? color;

  /// When true, the last lit bolt (at index [intensity]) renders a bit
  /// bigger and with a soft glow instead of looking identical to the other
  /// lit bolts — used on the add/edit star form, where that bolt is the one
  /// the slider is currently pointing at.
  final bool emphasizeLast;

  /// How much bigger than [size] that emphasized bolt gets. Overridable per
  /// call site rather than a single fixed multiplier — the add/edit star
  /// form wants it more prominent than the star card or reader do.
  final double emphasizedScale;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.colors.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) SizedBox(width: spacing),
          _bolt(i, resolvedColor),
        ],
      ],
    );
  }

  Widget _bolt(int i, Color resolvedColor) {
    final lit = i <= intensity;
    final isEmphasized = emphasizeLast && lit && i == intensity;
    final iconData = lit ? Icons.offline_bolt : Icons.offline_bolt_outlined;
    final iconSize = isEmphasized ? size * emphasizedScale : size;
    final icon = Icon(
      iconData,
      size: iconSize,
      color: lit ? resolvedColor : resolvedColor.withValues(alpha: 0.35),
    );
    if (!isEmphasized) return icon;
    // A blurred copy of the same glyph, behind the sharp one — its glow
    // follows the bolt's actual silhouette, hollow center included, instead
    // of a plain circular BoxShadow, which would glow right through that
    // hollow center as if the icon were a solid disc. The blur has to scale
    // with the icon's own size rather than use one fixed radius: a radius
    // that reads as a thin edge-glow on a big emphasized bolt (like the
    // add/edit form's) is big enough, relative to a small one (like the
    // star card's), to blur straight across its much smaller hollow center
    // and refill it — reintroducing the exact thing this is meant to avoid.
    final sigma = iconSize * 0.12;
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Icon(
            iconData,
            size: iconSize * 1.15,
            color: resolvedColor.withValues(alpha: 0.45),
          ),
        ),
        icon,
      ],
    );
  }
}
