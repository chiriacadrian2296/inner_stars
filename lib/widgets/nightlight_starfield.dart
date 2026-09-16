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
///
/// Each star runs its own slow, independent cycle (own [_NightlightStar.speed]
/// and [_NightlightStar.phase]) between nearly invisible — shrunk down and
/// faded out, at the bottom of its cycle — and bigger and brighter than its
/// base size at the top, rather than a fixed-size twinkle. Since every star's
/// cycle is offset differently, at any moment some are lighting up while
/// others are fading out.
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
        // Slow — a full light-up-to-fade-out cycle takes roughly 20-50s —
        // so this reads as individual stars gently living and dying rather
        // than a fast twinkle.
        speed: 0.13 + random.nextDouble() * 0.3,
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
      // 0 at the bottom of this star's own cycle, 1 at the top — same
      // sine-based shape `nebula_particles.frag`'s `starLayer` uses for its
      // twinkle, just driving size and brightness together here instead of
      // brightness alone.
      final cycle = 0.5 + 0.5 * math.sin(time * star.speed + star.phase);

      // Shrunk to a sliver and all but transparent at the bottom of the
      // cycle (reads as gone), noticeably bigger and fully lit at the top.
      final radius = star.radius * (0.05 + 1.75 * cycle);
      final glowAlpha = 0.5 * cycle;
      final coreAlpha = cycle;

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: glowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.8);
      canvas.drawCircle(center, radius * 1.6, glowPaint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: coreAlpha);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawPath(sparklePath(radius), corePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NightlightStarfieldPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.stars != stars;
}
