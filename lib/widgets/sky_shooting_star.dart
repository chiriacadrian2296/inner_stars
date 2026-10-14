import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'constellation_field.dart';
import 'sky_clock.dart';

/// STUDY (2026-10-14) — what a "shooting star" (a timed wish, see
/// `ShootingStarsScreen`) could look like in the Galaxy. Nothing behind it
/// yet: no data, no tap, one sample star near [anchor].
///
/// Unlike the background's comets (cold, thin, gone in under two seconds,
/// pure scenery), a shooting star is the user's own: so it follows the
/// Galaxy's "gold + rays = yours" rule — its head is a real lit star, drawn
/// with the very same flare shader as the user's stars — and it lasts: it
/// crosses its arc over a whole hour, barely moving, trailing a long gold
/// tail with sparks drifting off it.
class SkyShootingStarStudy extends StatelessWidget {
  const SkyShootingStarStudy({
    super.key,
    required this.anchor,
    required this.camera,
    required this.zoom,
    required this.clock,
    required this.flareProgram,
  });

  /// The world position (azimuth, elevation in turns) its arc passes by.
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

  /// How long one crossing takes — the wish's whole time.
  static const _lifetime = 3600.0;

  /// How much of the arc the tail covers behind the head.
  static const _tailShare = 0.32;

  static const _gold = Color(0xFFF2B84B);
  static const _core = Color(0xFFFFF8E6);

  /// The arc: from one side of [anchor] to the other, a little above it.
  Offset _pointAt(double progress) {
    final start = offsetWorldPosition(anchor, 0.11, 2.5);
    final end = offsetWorldPosition(anchor, 0.11, 2.5 + math.pi * 0.85);
    return Offset.lerp(start, end, progress)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.seconds;
    final progress = (time % _lifetime) / _lifetime;
    final head = worldToScreen(_pointAt(progress), camera, zoom, size);
    if (head == null) return;

    // The tail, sampled back along the arc from the head.
    const samples = 28;
    final points = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final projected = worldToScreen(
        _pointAt(progress - _tailShare * i / samples),
        camera,
        zoom,
        size,
      );
      if (projected == null) break;
      points.add(projected.position);
    }
    // Same on-screen size a constellation's own stars are drawn at.
    final starSize =
        kSkyConstellationAngularSpan *
        zoom *
        size.height *
        head.perspectiveScale;
    final width = (starSize * 0.05).clamp(1.5, 14.0);

    // A soft glow, then a brighter thinner core, both tapering to nothing.
    for (var pass = 0; pass < 2; pass++) {
      final glow = pass == 0;
      for (var i = 0; i < points.length - 1; i++) {
        final fade = 1 - i / (points.length - 1);
        final paint = Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (glow ? width * 2.6 : width * 0.7) * fade
          ..color = (glow ? _gold : _core).withValues(
            alpha: (glow ? 0.35 : 0.75) * math.pow(fade, 1.6).toDouble(),
          );
        if (glow) {
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.9);
        }
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    // Sparks drifting off the tail, each twinkling at its own pace.
    final random = math.Random(7);
    for (var s = 0; s < 18; s++) {
      final along = random.nextDouble();
      final index = (along * (points.length - 1)).floor();
      if (index >= points.length - 1) continue;
      final a = points[index];
      final b = points[index + 1];
      final direction = b - a;
      final length = direction.distance;
      if (length == 0) continue;
      final normal = Offset(-direction.dy, direction.dx) / length;
      final phase = random.nextDouble() * math.pi * 2;
      final speed = 1.2 + random.nextDouble() * 2.4;
      final drift =
          (random.nextDouble() - 0.5) * width * 5 +
          math.sin(time * 0.7 + phase) * width * 0.8;
      final twinkle = 0.5 + 0.5 * math.sin(time * speed + phase);
      final fade = 1 - along;
      canvas.drawCircle(
        Offset.lerp(a, b, random.nextDouble())! + normal * drift,
        (width * 0.35 * (0.6 + twinkle * 0.6)).clamp(0.8, 4.0),
        Paint()
          ..blendMode = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.25)
          ..color = Color.lerp(
            _gold,
            _core,
            twinkle,
          )!.withValues(alpha: 0.85 * twinkle * fade),
      );
    }

    // The head: a real lit star, from the same shader as the user's own.
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
    uniforms[0] = head.position.dx;
    uniforms[1] = head.position.dy;
    uniforms[32] = 0.37;
    uniforms[33] = 0.61;
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(6 + i, uniforms[i]);
    }
    canvas.drawRect(
      Rect.fromCircle(center: head.position, radius: flareRadius),
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
