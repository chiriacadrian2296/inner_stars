import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'constellation_field.dart';
import 'sky_clock.dart';

/// STUDY (2026-10-14, shown in every build) — what a "shooting star" (a
/// timed wish, see `ShootingStarsScreen`) could look like in the Galaxy.
/// Nothing behind it yet: no data, no tap, one sample star near [anchor].
///
/// Unlike the background's comets (cold, thin, gone in under two seconds,
/// pure scenery), a shooting star is the user's own: so it follows the
/// Galaxy's "gold + rays = yours" rule — its head is a real lit star, drawn
/// with the very same flare shader as the user's stars — and it lasts,
/// gliding calmly on a long loop around [anchor].
///
/// Its tail is a wake of stardust in the sky's own language: crisp little
/// stars like the background's (a solid core in a small glow), left behind
/// where the head passed, each staying put while it drifts slightly aside,
/// shrinks and fades — gold near the head, warm white further back — a few
/// with the web cursor's tiny cross sparkle. A hair-thin line joins the
/// head to the freshest stretch of it.
class SkyShootingStarStudy extends StatelessWidget {
  const SkyShootingStarStudy({
    super.key,
    required this.anchor,
    required this.camera,
    required this.zoom,
    required this.clock,
    required this.flareProgram,
  });

  /// The world position (azimuth, elevation in turns) its loop circles.
  final Offset anchor;
  final SkyCamera camera;
  final double zoom;
  final SkyClock clock;
  final ui.FragmentProgram? flareProgram;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ShootingStarPainter(
          anchor: anchor,
          camera: camera,
          zoom: zoom,
          clock: clock,
          flareProgram: flareProgram,
        ),
      ),
    );
  }
}

class _ShootingStarPainter extends CustomPainter {
  _ShootingStarPainter({
    required this.anchor,
    required this.camera,
    required this.zoom,
    required this.clock,
    required this.flareProgram,
  }) : super(repaint: clock);

  final Offset anchor;
  final SkyCamera camera;
  final double zoom;
  final SkyClock clock;
  final ui.FragmentProgram? flareProgram;

  /// Seconds for one full loop around [anchor]: slow, but clearly moving.
  static const _loopPeriod = 480.0;

  /// How much of the loop (radians of its angle) the wake stretches over.
  static const _wakeAngle = 0.75;

  /// One grain of stardust is left every this much of the loop angle, a
  /// few at a time (see [_grainsPerStep]).
  static const _grainStep = 0.012;
  static const _grainsPerStep = 3;

  static const _gold = Color(0xFFF2B84B);
  static const _warmWhite = Color(0xFFFFF4DE);

  /// The loop: an ellipse around [anchor], at loop angle [angle].
  Offset _pointAt(double angle) =>
      offsetWorldPosition(anchor, 0.12 + 0.045 * math.cos(2 * angle), angle);

  /// A stable 0..1 random number for grain [index], [salt] picking which.
  static double _hash(int index, int salt) {
    final x = math.sin(index * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.seconds;
    final headAngle = time / _loopPeriod * 2 * math.pi + 0.5;
    final head = worldToScreen(_pointAt(headAngle), camera, zoom, size);
    if (head == null) return;

    // Same on-screen size a constellation's own stars are drawn at.
    final starSize =
        kSkyConstellationAngularSpan *
        zoom *
        size.height *
        head.perspectiveScale;

    _paintThread(canvas, size, headAngle);
    _paintStardust(canvas, size, headAngle, time, starSize);
    _paintHead(canvas, head.position, starSize, time);
  }

  /// A hair-thin crisp line from the head back over the freshest stretch
  /// of the wake, fading out quickly.
  void _paintThread(Canvas canvas, Size size, double headAngle) {
    const samples = 14;
    Offset? previous;
    for (var i = 0; i <= samples; i++) {
      final k = i / samples;
      final projected = worldToScreen(
        _pointAt(headAngle - _wakeAngle * 0.3 * k),
        camera,
        zoom,
        size,
      );
      if (projected == null) return;
      final point = projected.position;
      if (previous != null) {
        canvas.drawLine(
          previous,
          point,
          Paint()
            ..strokeWidth = 1
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..color = _gold.withValues(
              alpha: 0.55 * math.pow(1 - k, 2).toDouble(),
            ),
        );
      }
      previous = point;
    }
  }

  /// The wake: grains left at fixed points of the loop as the head passes,
  /// each aging from the moment it was left.
  void _paintStardust(
    Canvas canvas,
    Size size,
    double headAngle,
    double time,
    double starSize,
  ) {
    final newestStep = (headAngle / _grainStep).floor();
    final steps = (_wakeAngle / _grainStep).ceil();
    for (var s = 0; s < steps; s++) {
      final step = newestStep - s;
      final bornAt = step * _grainStep;
      final age = (headAngle - bornAt) / _wakeAngle;
      if (age < 0 || age >= 1) continue;
      // This stretch of the loop, projected once for all its grains.
      final from = worldToScreen(_pointAt(bornAt), camera, zoom, size);
      final to = worldToScreen(
        _pointAt(bornAt + _grainStep),
        camera,
        zoom,
        size,
      );
      if (from == null || to == null) continue;
      final along = to.position - from.position;
      final length = along.distance;
      if (length == 0) continue;
      final normal = Offset(-along.dy, along.dx) / length;
      for (var g = 0; g < _grainsPerStep; g++) {
        final index = step * _grainsPerStep + g;
        final at = from.position + along * _hash(index, 1);

        // Drifting slowly aside as it ages: the wake widens behind.
        final side = _hash(index, 2) * 2 - 1;
        final spread = starSize * 0.05 * (0.4 + 2.6 * age);
        final center = at + normal * side * spread;

        final twinkle =
            0.75 +
            0.25 * math.sin(time * (1.4 + _hash(index, 3) * 2.2) + index * 1.7);
        final fade = math.pow(1 - age, 1.4).toDouble();
        final alpha = (fade * twinkle * (0.55 + 0.45 * _hash(index, 4))).clamp(
          0.0,
          1.0,
        );
        if (alpha < 0.02) continue;

        // Bigger and gold fresh, smaller and warm white as it ages.
        final coreRadius =
            (starSize * 0.009 * (0.5 + _hash(index, 5)) * (1 - 0.6 * age))
                .clamp(0.7, 2.6);
        final color = Color.lerp(_gold, _warmWhite, age)!;

        // A small soft glow from two faint rings of light (cheaper than a
        // blur, with a couple of hundred grains a frame).
        for (final (scale, strength) in const [(2.8, 0.1), (1.7, 0.2)]) {
          canvas.drawCircle(
            center,
            coreRadius * scale,
            Paint()
              ..blendMode = BlendMode.plus
              ..color = color.withValues(alpha: alpha * strength),
          );
        }
        canvas.drawCircle(
          center,
          coreRadius,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = color.withValues(alpha: alpha),
        );
        // A few with the cursor sparkle's tiny cross.
        if (_hash(index, 6) < 0.18) {
          final arm = coreRadius * 2.8 * (0.6 + 0.4 * twinkle);
          final line = Paint()
            ..blendMode = BlendMode.plus
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: alpha * 0.8);
          canvas.drawLine(
            center.translate(-arm, 0),
            center.translate(arm, 0),
            line,
          );
          canvas.drawLine(
            center.translate(0, -arm),
            center.translate(0, arm),
            line,
          );
        }
      }
    }
  }

  /// The head: a real lit star, from the same shader as the user's own.
  void _paintHead(
    Canvas canvas,
    Offset position,
    double starSize,
    double time,
  ) {
    final program = flareProgram;
    if (program == null) return;
    final shader = program.fragmentShader();
    final flareRadius = starSize * 0.42;
    shader
      ..setFloat(0, time)
      ..setFloat(1, flareRadius)
      ..setFloat(2, 0) // The lit look.
      ..setFloat(3, _gold.r)
      ..setFloat(4, _gold.g)
      ..setFloat(5, _gold.b);
    // 16 positions, 16 seeds, 16 orbit counts — only the first is used.
    final uniforms = Float32List(16 * 2 + 16 * 2 + 16)..fillRange(0, 32, -1);
    uniforms[0] = position.dx;
    uniforms[1] = position.dy;
    uniforms[32] = 0.37;
    uniforms[33] = 0.61;
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(6 + i, uniforms[i]);
    }
    canvas.drawRect(
      Rect.fromCircle(center: position, radius: flareRadius),
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(_ShootingStarPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom ||
      oldDelegate.anchor != anchor ||
      oldDelegate.flareProgram != flareProgram;
}
