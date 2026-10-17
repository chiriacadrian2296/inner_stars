import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'constellation_field.dart';
import 'sky_clock.dart';

const double _shootingStarSpeed = 2 * math.pi / 1200;
const double _shootingStarBearing = 2.2;

/// The moving head's current world position, shared by its painter, Galaxy
/// hit testing and the camera that follows it after selection.
Offset shootingStarWorldPosition(Offset anchor, double seconds) =>
    offsetWorldPosition(
      anchor,
      seconds * _shootingStarSpeed - 0.35,
      _shootingStarBearing,
    );

/// The Galaxy's moving shooting star: a tappable wish carried along a great
/// circle near [anchor]. Hit testing and camera tracking use
/// [shootingStarWorldPosition], the same position this painter renders.
///
/// Unlike the background's comets (cold, thin, gone in under two seconds,
/// pure scenery), a shooting star is the user's own: so it follows the
/// Galaxy's "gold + rays = yours" rule — its head is a real lit star, drawn
/// in the same visual language as the user's stars — and it lasts,
/// gliding calmly in a straight line across the sky, past [anchor].
///
/// Its tail is a wake of stardust in the sky's own language: crisp little
/// stars like the background's (a solid core in a small glow), left behind
/// where the head passed, each staying put while it drifts slightly aside,
/// shrinks and fades — gold near the head, warm white further back — a few
/// with the web cursor's tiny cross sparkle. A hair-thin line joins the
/// head to the freshest stretch of it.
class SkyShootingStar extends StatelessWidget {
  const SkyShootingStar({
    super.key,
    required this.anchor,
    required this.camera,
    required this.zoom,
    required this.clock,
    required this.flareProgram,
  });

  /// The world position (azimuth, elevation in turns) its path passes.
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

  /// How fast it travels, in radians of sky a second: one full way round
  /// the sky in 20 minutes — calm, but clearly moving.
  static const _speed = _shootingStarSpeed;

  /// Which way its straight path crosses [anchor].
  static const _bearing = _shootingStarBearing;

  /// How much of its path (radians of sky) the wake stretches over.
  static const _wakeAngle = 0.12;

  /// One grain of stardust is left every this much of the path, a few at
  /// a time (see [_grainsPerStep]).
  static const _grainStep = 0.0016;
  static const _grainsPerStep = 3;

  static const _gold = Color(0xFFF2B84B);
  static const _warmWhite = Color(0xFFFFF4DE);

  /// Its path: a straight line across the sky — a great circle through
  /// [anchor] — [distance] radians along it from [anchor] (negative before
  /// it), going round the whole sky and back.
  Offset _pointAt(double distance) =>
      offsetWorldPosition(anchor, distance, _bearing);

  /// A stable 0..1 random number for grain [index], [salt] picking which.
  static double _hash(int index, int salt) {
    final x = math.sin(index * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.seconds;
    // Starting a little before [anchor], so it soon passes by it.
    final headAngle = time * _speed - 0.35;
    final head = worldToScreen(_pointAt(headAngle), camera, zoom, size);
    if (head == null) return;

    // Same on-screen size a constellation's own stars are drawn at.
    final starSize =
        kSkyConstellationAngularSpan *
        zoom *
        size.height *
        head.perspectiveScale;

    // Nothing to draw while no part of the star and its wake is on screen
    // (most of the time): a few points along the wake give its extent.
    var extent = Rect.fromCircle(
      center: head.position,
      radius: starSize * 0.45,
    );
    for (var i = 1; i <= 4; i++) {
      final point = worldToScreen(
        _pointAt(headAngle - _wakeAngle * i / 4),
        camera,
        zoom,
        size,
      );
      if (point == null) continue;
      extent = extent.expandToInclude(
        Rect.fromCircle(
          center: point.position,
          radius: _spread(starSize, i / 4) * 2 + starSize * 0.05,
        ),
      );
    }
    if (!extent.overlaps(Offset.zero & size)) return;

    // How close the camera is: 0 from afar, 1 close in. Up close the
    // wake gains a soft glow under its grains and round its thread, so it
    // keeps the misty look it has from far away instead of breaking up
    // into separate dots.
    final closeness = ((zoomPercent(zoom) - 55) / 40).clamp(0.0, 1.0);
    _paintWakeGlow(canvas, size, headAngle, starSize, closeness);
    _paintBeam(canvas, size, headAngle, starSize);
    _paintThread(canvas, size, headAngle, starSize);
    _paintStardust(canvas, size, headAngle, time, starSize, closeness);
    _paintHead(canvas, head.position, starSize, time);
  }

  /// A soft gold beam pouring out of the star toward its tail: widest at
  /// the head, narrowing and fading over the first stretch, so the wake
  /// visibly comes out of the star instead of starting after a gap of sky.
  void _paintBeam(Canvas canvas, Size size, double headAngle, double starSize) {
    const samples = 12;
    const reach = 0.22;
    Offset? previous;
    for (var i = 0; i <= samples; i++) {
      final k = i / samples;
      final projected = worldToScreen(
        _pointAt(headAngle - _wakeAngle * reach * k),
        camera,
        zoom,
        size,
      );
      if (projected == null) return;
      final point = projected.position;
      if (previous != null) {
        final width = starSize * (0.032 - 0.024 * k) * _neck(0.22 * k);
        canvas.drawLine(
          previous,
          point,
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.5)
            ..color = _gold.withValues(
              alpha: 0.5 * math.pow(1 - k, 1.6).toDouble(),
            ),
        );
      }
      previous = point;
    }
  }

  /// A thin crisp line from the head back over the first half of the wake,
  /// tapering and fading as it goes. Sized with the sky (see [_paintStardust])
  /// so it looks the same from near and far.
  void _paintThread(
    Canvas canvas,
    Size size,
    double headAngle,
    double starSize,
  ) {
    const samples = 24;
    Offset? previous;
    for (var i = 0; i <= samples; i++) {
      final k = i / samples;
      final projected = worldToScreen(
        _pointAt(headAngle - _wakeAngle * 0.55 * k),
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
            ..strokeWidth = starSize * 0.0075 * (1 - 0.7 * k) * _neck(0.55 * k)
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.plus
            ..color = _gold.withValues(
              alpha: 0.8 * math.pow(1 - k, 1.5).toDouble(),
            ),
        );
      }
      previous = point;
    }
  }

  /// How full the wake is at [age]: only a tenth right at the star,
  /// opening to full width over the first stretch — a slim neck, so the
  /// star itself stays clearly visible instead of being covered.
  static double _neck(double age) {
    final t = (age / 0.15).clamp(0.0, 1.0);
    return 0.1 + 0.9 * t * t * (3 - 2 * t);
  }

  /// How far a grain of age [age] (0 fresh .. 1 gone) has drifted from the
  /// path: slim near the head, scattering more and more toward the end.
  static double _spread(double starSize, double age) =>
      starSize * 0.035 * (0.3 + 1.2 * age + 3.0 * age * age);

  /// Up close only ([closeness] > 0): a soft glow along the wake, as wide
  /// as the grains are spread, and a brighter one round the thread.
  void _paintWakeGlow(
    Canvas canvas,
    Size size,
    double headAngle,
    double starSize,
    double closeness,
  ) {
    if (closeness <= 0) return;
    const samples = 20;
    Offset? previous;
    for (var i = 0; i <= samples; i++) {
      final age = i / samples;
      final projected = worldToScreen(
        _pointAt(headAngle - _wakeAngle * age),
        camera,
        zoom,
        size,
      );
      if (projected == null) return;
      final point = projected.position;
      if (previous != null) {
        // At close follow zoom the angular width can project to well over a
        // hundred pixels. A blur that wide is disproportionately expensive
        // on the GPU while adding almost no visible softness past this cap.
        final width = math.min(
          (_spread(starSize, age) * 2 + starSize * 0.01) * _neck(age),
          56.0,
        );
        final color = Color.lerp(_gold, _warmWhite, age)!;
        canvas.drawLine(
          previous,
          point,
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.min(width * 0.45, 18),
            )
            ..color = color.withValues(
              alpha: 0.13 * closeness * math.pow(1 - age, 1.3).toDouble(),
            ),
        );
        if (age <= 0.55) {
          final k = age / 0.55;
          final threadWidth = starSize * 0.03 * (1 - 0.7 * k) * _neck(age);
          canvas.drawLine(
            previous,
            point,
            Paint()
              ..blendMode = BlendMode.plus
              ..strokeCap = StrokeCap.round
              ..strokeWidth = threadWidth
              ..maskFilter = MaskFilter.blur(
                BlurStyle.normal,
                threadWidth * 0.6,
              )
              ..color = _gold.withValues(
                alpha: 0.3 * closeness * math.pow(1 - k, 1.5).toDouble(),
              ),
          );
        }
      }
      previous = point;
    }
  }

  /// The wake: grains left at fixed points of the path as the head passes,
  /// each aging from the moment it was left — only ever behind the head.
  /// Everything is sized with the sky ([starSize]), never with minimum
  /// pixel sizes, so from far away the wake keeps the same delicate look
  /// instead of thickening up.
  void _paintStardust(
    Canvas canvas,
    Size size,
    double headAngle,
    double time,
    double starSize,
    double closeness,
  ) {
    final newestStep = (headAngle / _grainStep).floor();
    final steps = (_wakeAngle / _grainStep).ceil();
    final visibleBounds = (Offset.zero & size).inflate(16);
    for (var s = 0; s < steps; s++) {
      final step = newestStep - s;
      final bornAt = step * _grainStep;
      if ((headAngle - bornAt) / _wakeAngle >= 1) continue;
      // This stretch of the path, projected once for all its grains.
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
      // The first stretch behind the head gets extra, finer grains, so the
      // beam has a grain to it and no gap of sky shows through.
      final stepAge = (headAngle - bornAt) / _wakeAngle;
      final grains = _grainsPerStep + (stepAge < 0.2 ? 4 : 0);
      for (var g = 0; g < grains; g++) {
        final fine = g >= _grainsPerStep;
        // The usual grains keep their own numbers (and so their look); the
        // fine ones get numbers of their own.
        final index = fine ? 1000000 + step * 8 + g : step * _grainsPerStep + g;
        final share = _hash(index, 1);
        // Never at or ahead of the head: a small gap behind it first.
        final spotAngle = bornAt + _grainStep * share;
        final age = (headAngle - spotAngle) / _wakeAngle;
        // Born right behind the head (never ahead of it): the slim neck
        // keeps them small and close to the line there.
        if (age < 0.004 || age >= 1) continue;
        final at = from.position + along * share;

        // Drifting aside as it ages: slim near the head, scattering behind.
        final side = _hash(index, 2) * 2 - 1;
        final spread = _spread(starSize, age) * (fine ? 0.6 : 1.0) * _neck(age);
        final center = at + normal * side * spread;
        // Canvas clipping prevents off-screen pixels from appearing but does
        // not avoid recording all their additive circles and sparkle lines.
        // Up close most of the long wake is outside the viewport, so skip
        // those grains before allocating paints and issuing draw calls.
        if (!visibleBounds.contains(center)) continue;

        final twinkle =
            0.75 +
            0.25 * math.sin(time * (1.4 + _hash(index, 3) * 2.2) + index * 1.7);
        final fade = math.pow(1 - age, 1.4).toDouble();
        final alpha =
            (fade *
                    twinkle *
                    (0.55 + 0.45 * _hash(index, 4)) *
                    (fine ? 1 - age / 0.2 : 1.0))
                .clamp(0.0, 1.0);
        if (alpha < 0.02) continue;

        // Bigger and gold fresh, smaller and warm white as it ages.
        // Capped up close; no minimum, so it stays delicate from far away.
        final coreRadius = math.min(
          starSize *
              0.009 *
              (0.5 + _hash(index, 5)) *
              (1 - 0.6 * age) *
              (fine ? 0.5 : 1.0) *
              (0.3 + 0.7 * _neck(age)),
          2.6,
        );
        final color = Color.lerp(_gold, _warmWhite, age)!;

        // Near the head the halos shrink and dim with the neck.
        final neck = _neck(age);
        // A small soft glow from two faint rings of light (cheaper than a
        // blur, with a couple of hundred grains a frame) — a little wider
        // up close.
        for (final (scale, strength) in const [(2.8, 0.1), (1.7, 0.2)]) {
          canvas.drawCircle(
            center,
            coreRadius * scale * (1 + closeness * 0.8) * (0.4 + 0.6 * neck),
            Paint()
              ..blendMode = BlendMode.plus
              ..color = color.withValues(alpha: alpha * strength * neck),
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
            ..strokeWidth = coreRadius * 0.55
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
