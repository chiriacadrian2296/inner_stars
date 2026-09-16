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
/// others are fading out. On top of that, each also gets an occasional
/// quick extra flicker — the same fast, irregular pulse `sky_supernova.frag`
/// gives its own supernovas, in random order across the field.
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

  /// A jittered grid rather than plain uniform-random positions — pure
  /// random placement at this count reads as clumpy, with visible empty
  /// gaps and crowded clusters. Splitting the area into roughly
  /// `sqrt(count)` × `sqrt(count)` cells and placing one star at a random
  /// offset within each spreads them evenly while [_jitterFactor] keeps the
  /// grid itself from ever being visible.
  static const _jitterFactor = 0.85;

  static List<_NightlightStar> _generateStars(int count) {
    final random = math.Random(7);
    final cols = math.sqrt(count).ceil();
    final rows = (count / cols).ceil();
    final cellWidth = 1.0 / cols;
    final cellHeight = 1.0 / rows;

    // Shuffled rather than taken in raster order — `rows * cols` can exceed
    // `count`, and consuming cells in order would leave a visibly empty
    // block at the end of the grid instead of scattering the shortfall.
    final cells = [for (var i = 0; i < rows * cols; i++) i]..shuffle(random);

    return List.generate(count, (i) {
      final cell = cells[i];
      final col = cell % cols;
      final row = cell ~/ cols;
      final jitterX = (random.nextDouble() - 0.5) * cellWidth * _jitterFactor;
      final jitterY = (random.nextDouble() - 0.5) * cellHeight * _jitterFactor;
      return _NightlightStar(
        position: Offset(
          (col + 0.5) * cellWidth + jitterX,
          (row + 0.5) * cellHeight + jitterY,
        ),
        radius: 1.1 + random.nextDouble() * 2.0,
        phase: random.nextDouble() * math.pi * 2,
        // A full light-up-to-fade-out cycle takes roughly 6-18s — brisk
        // enough to read as lively rather than a slow, barely-there drift.
        speed: 0.35 + random.nextDouble() * 0.65,
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

      // A quick, irregular extra sparkle on top of the star's own slow
      // cycle — the same technique `sky_supernova.frag` uses for its
      // supernovas' own fast flicker: three sines at frequencies with no
      // common period, multiplied rather than added, so the product stays
      // near zero almost all the time and only spikes when all three
      // happen to crest together. Each star's own position/phase shift the
      // three terms independently, so these spikes land in effectively
      // random order across the field rather than in sync.
      final flickerRaw =
          math.sin(time * 2.7 + star.position.dx * 11.0) *
          math.sin(time * 1.3 + star.position.dy * 7.0) *
          math.sin(time * 0.41 + star.phase * 5.0);
      final flicker = math.pow(flickerRaw.clamp(0.0, 1.0), 4.0).toDouble();

      // Shrunk to a sliver and all but transparent at the bottom of the
      // slow cycle (reads as gone), noticeably bigger and fully lit at the
      // top — [flicker] then briefly boosts both further still, on point
      // rather than as a separate ring/circle shape.
      final radius =
          star.radius * (0.05 + 1.75 * cycle) * (1.0 + flicker * 0.6);
      final glowAlpha = (0.5 * cycle + flicker * 0.5).clamp(0.0, 1.0);
      final coreAlpha = (cycle + flicker * 0.4).clamp(0.0, 1.0);

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
