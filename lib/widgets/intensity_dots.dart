import 'package:flutter/material.dart';

/// A win's 1-5 intensity as five small dots, filled up to [intensity] — the
/// quiet counterpart of `IntensityBolts`, for places too small for five
/// bolts (a star's round button on the constellation view). A null
/// [intensity] leaves every dot dim.
class IntensityDots extends StatelessWidget {
  const IntensityDots({
    super.key,
    required this.intensity,
    required this.color,
    this.dotSize = 3,
    this.spacing = 2,
  });

  final int? intensity;
  final Color color;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final filled = intensity ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) SizedBox(width: spacing),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= filled ? color : color.withValues(alpha: 0.22),
            ),
          ),
        ],
      ],
    );
  }
}
