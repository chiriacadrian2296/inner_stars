import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'constellation_painter.dart' show sparklePath;

/// The Nightlight breathing exercise's own centerpiece — a single large
/// white sparkle (the same shape [NightlightStarfield]'s scattered
/// background stars use, see `constellation_painter.dart`'s `sparklePath`)
/// that swells and brightens as [progress] rises and settles back as it
/// falls, standing in for a literal circle. A 2D illusion (a few layered,
/// blurred glow passes under one crisp core), not a real 3D render —
/// `nightlight_breathing_screen.dart` owns the actual breathing timing and
/// just feeds this widget a plain 0-1 [progress] each frame, so this widget
/// itself has no animation/timer of its own.
class NightlightStarGlow extends StatelessWidget {
  const NightlightStarGlow({
    super.key,
    required this.progress,
    this.size = 180,
  });

  /// 0 at the emptiest point of the cycle (fully exhaled), 1 at the fullest
  /// (fully inhaled, mid-hold).
  final double progress;

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _NightlightStarGlowPainter(progress: progress.clamp(0, 1)),
    );
  }
}

class _NightlightStarGlowPainter extends CustomPainter {
  _NightlightStarGlowPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    // Core sparkle radius: never fully vanishes (a bare pinprick at rest,
    // per the countdown/explanation screens still needing something to
    // look at before the first inhale), grows to about 70% of the
    // available space at the peak of a breath.
    final coreRadius = lerpDouble(maxRadius * 0.28, maxRadius * 0.7, progress)!;

    // Three layered blur passes, widest/faintest first — a single blur
    // reads as a flat smudge at this size, three gives it the softer,
    // deeper falloff an actual light source has.
    for (final layer in _glowLayers) {
      final radius = coreRadius * layer.radiusFactor;
      final alpha = layer.baseAlpha * (0.4 + 0.6 * progress);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          radius * layer.blurFactor,
        );
      canvas.drawCircle(center, radius, paint);
    }

    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 + 0.15 * progress);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawPath(sparklePath(coreRadius), corePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NightlightStarGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GlowLayer {
  const _GlowLayer({
    required this.radiusFactor,
    required this.baseAlpha,
    required this.blurFactor,
  });

  final double radiusFactor;
  final double baseAlpha;
  final double blurFactor;
}

const _glowLayers = [
  _GlowLayer(radiusFactor: 2.6, baseAlpha: 0.10, blurFactor: 0.9),
  _GlowLayer(radiusFactor: 1.8, baseAlpha: 0.18, blurFactor: 0.7),
  _GlowLayer(radiusFactor: 1.2, baseAlpha: 0.30, blurFactor: 0.5),
];
