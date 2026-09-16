import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'constellation_painter.dart' show sparklePath;

/// A field of small white twinkling sparkles scattered across whatever
/// bounds it's given — the Nightlight section's own background (see
/// `nightlight_gate_screen.dart`, `nightlight_explained_screen.dart`,
/// `nightlight_breathing_screen.dart`, and `admire_stars_screen.dart`),
/// meant to sit behind content over [AppColors.nightlightGradient].
///
/// Reuses [sparklePath] — the same shape a lit constellation star draws —
/// rather than inventing a new one, just in white instead of gold. Glow is a
/// soft [MaskFilter] blur underneath the crisp sparkle rather than
/// `constellation_flare.frag`'s shader: that shader is written for gold
/// stars keyed to a `StarPalette` and for a handful of explicit constellation
/// positions, not for a scattered, arbitrarily-sized 2D field of plain white
/// dots, so a flat-Dart glow is simpler here than adapting it.
class NightlightStarfield extends StatefulWidget {
  const NightlightStarfield({super.key, this.starCount = 80});

  final int starCount;

  @override
  State<NightlightStarfield> createState() => _NightlightStarfieldState();
}

class _NightlightStarfieldState extends State<NightlightStarfield>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  // Generated once (fixed seed, so reproducible rather than genuinely
  // random) and kept in fractional (0-1) coordinates, so the same layout
  // just stretches to whatever size this widget is given, rather than
  // reshuffling every time the surrounding layout changes.
  late final List<_NightlightStar> _stars = _generateStars(widget.starCount);

  static List<_NightlightStar> _generateStars(int count) {
    final random = math.Random(7);
    return List.generate(count, (_) {
      return _NightlightStar(
        position: Offset(random.nextDouble(), random.nextDouble()),
        radius: 1.1 + random.nextDouble() * 2.0,
        phase: random.nextDouble() * math.pi * 2,
        speed: 0.5 + random.nextDouble() * 1.2,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _NightlightStarfieldPainter(
          stars: _stars,
          time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
        ),
      ),
    );
  }
}

/// One scattered star's fixed properties.
class _NightlightStar {
  const _NightlightStar({
    required this.position,
    required this.radius,
    required this.phase,
    required this.speed,
  });

  /// Fractional (0-1) position within the painted area.
  final Offset position;
  final double radius;
  final double phase;
  final double speed;
}

class _NightlightStarfieldPainter extends CustomPainter {
  _NightlightStarfieldPainter({required this.stars, required this.time});

  final List<_NightlightStar> stars;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (final star in stars) {
      final center = Offset(
        star.position.dx * size.width,
        star.position.dy * size.height,
      );
      // Same 2-sine-product-style twinkle as `nebula_particles.frag`'s
      // `starLayer`, just evaluated in Dart per star instead of per shader
      // cell.
      final twinkle = 0.55 + 0.45 * math.sin(time * star.speed + star.phase);

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * twinkle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, star.radius * 1.8);
      canvas.drawCircle(center, star.radius * 1.6, glowPaint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.55 + 0.45 * twinkle);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawPath(sparklePath(star.radius), corePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NightlightStarfieldPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.stars != stars;
}
