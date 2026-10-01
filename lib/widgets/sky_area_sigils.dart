import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/life_area.dart';
import 'constellation_field.dart';

/// An ornate circular "seal" behind each supernova — one or two outer
/// rings, an inner motif (see [_InnerMotif]) slowly turning inside them —
/// sparkle icons and connecting arcs/curves, all as one rotating group —
/// and a cross reaching out to the outer ring with petal accents at its
/// tips — a mandala/sigil reference the user shared, one per [LifeArea].
/// Each area gets its own slightly different recipe (see [_SigilRecipe])
/// so the 8 read as the same family but aren't identical, and each is
/// tinted a slightly different shade of gold (see
/// [_SkyAreaSigilsPainter._sigilColor]) so they're still tellable apart at
/// a glance even zoomed out too far for any one icon to read yet. Purely
/// decorative — no hit-testing of its own; `NebulaScreen`'s existing
/// `hitTestSupernovas` already covers taps on this same spot. Painted
/// *before* [SkySupernova] in `NebulaScreen`'s Stack (see
/// `sky_supernova.dart`), so that widget's own glow/icon sit on top of
/// this one, not the other way round.
///
/// Every sigil is rotated to match its own supernova's light rays (see
/// `sky_supernova.frag`'s `axisA`/`axisB`, replicated here in
/// [_axisAFor]) rather than plain screen up/down — the shader builds each
/// star's spikes in a frame anchored to that star's own position on the
/// sphere, not the camera, so without this a sigil drawn in flat screen
/// space would sit rotated some arbitrary amount away from its own star's
/// spikes depending on where the camera happens to be looking.
class SkyAreaSigils extends StatefulWidget {
  const SkyAreaSigils({super.key, required this.camera, required this.zoom});

  final SkyCamera camera;
  final double zoom;

  @override
  State<SkyAreaSigils> createState() => _SkyAreaSigilsState();
}

class _SkyAreaSigilsState extends State<SkyAreaSigils>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

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
    return CustomPaint(
      size: Size.infinite,
      painter: _SkyAreaSigilsPainter(
        camera: widget.camera,
        zoom: widget.zoom,
        time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      ),
    );
  }
}

typedef _Vec3 = (double x, double y, double z);

double _dot(_Vec3 a, _Vec3 b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

_Vec3 _cross(_Vec3 a, _Vec3 b) => (
  a.$2 * b.$3 - a.$3 * b.$2,
  a.$3 * b.$1 - a.$1 * b.$3,
  a.$1 * b.$2 - a.$2 * b.$1,
);

_Vec3 _add(_Vec3 a, _Vec3 b) => (a.$1 + b.$1, a.$2 + b.$2, a.$3 + b.$3);

_Vec3 _scaled(_Vec3 a, double s) => (a.$1 * s, a.$2 * s, a.$3 * s);

_Vec3 _normalized(_Vec3 v) {
  final length = math.sqrt(_dot(v, v));
  return (v.$1 / length, v.$2 / length, v.$3 / length);
}

/// The exact same local frame `sky_supernova.frag`'s `supernova()` builds
/// for [center] (that star's own position, from [supernovaDirection]) —
/// `axisA`/`axisB` are what the shader's spikes/cross actually run along
/// (its `uv.x`/`uv.y`), so replicating this construction here, rather than
/// just using the camera's own right/up, is what lets [SkyAreaSigils]
/// line its own cross up with the star's.
_Vec3 _axisAFor(_Vec3 center) {
  final reference = center.$2.abs() < 0.99 ? (0.0, 1.0, 0.0) : (1.0, 0.0, 0.0);
  return _normalized(_cross(reference, center));
}

/// Forward (3D-direction -> screen) projection — identical to
/// `sky_supernova.dart`'s own private `_projectDirection` (see that file's
/// doc comment for why this can't just reuse `worldToScreen`, which wants
/// an (azimuth, elevation) pair rather than a raw direction). Duplicated
/// rather than shared since both are small and self-contained, and a
/// shared helper would need its own file/export just for these two call
/// sites — not worth it for the few lines saved.
(Offset, double)? _projectDirection(
  _Vec3 dir,
  SkyCamera camera,
  double zoom,
  Size size,
) {
  final z = _dot(dir, camera.forward);
  if (z < -0.5) return null;
  final scale = 2 / (1 + z);
  final x = _dot(dir, camera.right) * scale;
  final y = _dot(dir, camera.up) * scale;
  return (
    Offset(
      size.width / 2 + x * zoom * size.height,
      size.height / 2 - y * zoom * size.height,
    ),
    scale,
  );
}

/// What fills the space between the center and the inner ring — two
/// different families of shape, so sigils can look structurally different
/// from each other rather than resized/recolored variants of one shape.
/// Both carry their own sparkle icons directly (see
/// [_SigilRecipe.accentIcon]) as part of the *same* rotating group, rather
/// than a separate, static ring of icons sitting still while only the
/// shape underneath turned.
enum _InnerMotif {
  /// A few curved "S"-shaped arms spiraling out from near the center,
  /// each with a couple of sparkles trailing along its own length.
  spiral,

  /// [_SkyAreaSigilsPainter.motifElementCount] sparkles evenly spaced on
  /// a ring, threaded together by a scalloped connecting arc — a beaded
  /// necklace rather than a plain circle of icons.
  starRing,
}

/// A hand-picked set of choices per area — same family (rings, inner
/// motif, cross, petals) as every other sigil, but genuinely not
/// identical: how many concentric rings, which [_InnerMotif] fills the
/// middle and how many elements it has, how big the cross's own petal
/// accents are, which sparkle icon this one uses throughout, and whether
/// there's a core ring. [_all] is a literal table rather than a formula so
/// the *combination* stays deliberate — different motifs, element counts,
/// and icons — instead of however a modular-arithmetic pattern happens to
/// fall out (which risked two areas landing on the same combination).
class _SigilRecipe {
  const _SigilRecipe({
    required this.ringCount,
    required this.innerMotif,
    required this.motifElementCount,
    required this.petalSizeFactor,
    required this.hasCoreRing,
    required this.accentIcon,
  });

  final int ringCount;
  final _InnerMotif innerMotif;
  final int motifElementCount;
  final double petalSizeFactor;
  final bool hasCoreRing;
  final IconData accentIcon;

  static const List<_SigilRecipe> _all = [
    _SigilRecipe(
      ringCount: 2,
      innerMotif: _InnerMotif.spiral,
      motifElementCount: 3,
      petalSizeFactor: 0.85,
      hasCoreRing: false,
      accentIcon: Icons.star,
    ),
    _SigilRecipe(
      ringCount: 1,
      innerMotif: _InnerMotif.spiral,
      motifElementCount: 3,
      petalSizeFactor: 0.90,
      hasCoreRing: true,
      accentIcon: Icons.auto_awesome,
    ),
    _SigilRecipe(
      ringCount: 2,
      innerMotif: _InnerMotif.starRing,
      motifElementCount: 7,
      petalSizeFactor: 0.95,
      hasCoreRing: false,
      accentIcon: Icons.grade,
    ),
    _SigilRecipe(
      ringCount: 1,
      innerMotif: _InnerMotif.starRing,
      motifElementCount: 5,
      petalSizeFactor: 1.00,
      hasCoreRing: true,
      accentIcon: Icons.star_border,
    ),
    _SigilRecipe(
      ringCount: 2,
      innerMotif: _InnerMotif.spiral,
      motifElementCount: 4,
      petalSizeFactor: 0.85,
      hasCoreRing: false,
      accentIcon: Icons.star,
    ),
    _SigilRecipe(
      ringCount: 1,
      innerMotif: _InnerMotif.starRing,
      motifElementCount: 6,
      petalSizeFactor: 0.90,
      hasCoreRing: false,
      accentIcon: Icons.auto_awesome,
    ),
    _SigilRecipe(
      ringCount: 2,
      innerMotif: _InnerMotif.starRing,
      motifElementCount: 8,
      petalSizeFactor: 0.95,
      hasCoreRing: true,
      accentIcon: Icons.grade,
    ),
    _SigilRecipe(
      ringCount: 1,
      innerMotif: _InnerMotif.spiral,
      motifElementCount: 2,
      petalSizeFactor: 1.00,
      hasCoreRing: true,
      accentIcon: Icons.star_border,
    ),
  ];

  factory _SigilRecipe.forArea(int index) => _all[index];
}

class _SkyAreaSigilsPainter extends CustomPainter {
  const _SkyAreaSigilsPainter({
    required this.camera,
    required this.zoom,
    required this.time,
  });

  final SkyCamera camera;
  final double zoom;
  final double time;

  // A bit bigger than an earlier pass (0.030) — still deliberately well
  // inside the supernova's own visible ring/glow, picked by eye rather
  // than derived from the shader's own falloff math. Used at the *peak*
  // of the pulse, not the resting size — see [_pulseAmplitude].
  static const _sigilPeakWorldRadius = 0.038;
  static const _pulseAmplitude = 0.018;
  static const _sigilWorldRadius =
      _sigilPeakWorldRadius / (1 + _pulseAmplitude);

  // The supernova's own visible ring's *center* line (see
  // `hitTestSupernovas`' own derivation in constellation_field.dart:
  // ringRadius 0.09, in that shader's local uv space, times the 0.45
  // uv-to-angle scale). [_paintAnchorRing] draws a fixed (non-pulsing,
  // non-rotating) ring exactly here, unlike every other element in this
  // file, which all move with [_sigilWorldRadius]'s own pulse/rotation.
  static const _lightRingCenterWorldRadius = 0.0405;

  // How far apart (in world-direction terms) the two points used to
  // measure a star's own axisA on screen are — see [_rotationAngleFor].
  // Small enough to stay a good local-linear approximation, nowhere near
  // small enough to hit floating-point precision limits.
  static const _epsilon = 0.01;

  // Full turn every ~90 seconds — slow enough to read as alive without
  // drawing the eye away from anything else on screen. Now drives the
  // inner motif's icons too, not just the shape underneath them — see
  // [_InnerMotif]'s own doc comment on why that matters.
  static const _innerRotationSpeed = 2 * math.pi / 90;

  @override
  void paint(Canvas canvas, Size size) {
    // Same edge-of-view clip [SkySupernova]/[ConstellationFieldPainter]
    // both already do, for the same reason: without it, a sigil near the
    // screen edge paints straight through into whatever sits beside this
    // pane (the desktop/web sidebar) instead of just sliding off-screen.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final areas = LifeArea.values;
    for (var i = 0; i < areas.length; i++) {
      final center = supernovaDirection(i, areas.length);
      final projected = _projectDirection(center, camera, zoom, size);
      if (projected == null) continue;
      final (screenCenter, scale) = projected;

      // Fixed anchor ring first, underneath and unaffected by the pulsing/
      // rotating sigil drawn on top of it — see
      // [_lightRingCenterWorldRadius]'s own comment.
      final anchorRadius =
          _lightRingCenterWorldRadius * zoom * size.height * scale;
      _paintAnchorRing(canvas, screenCenter, anchorRadius, i);

      final axisA = _axisAFor(center);
      final rotation = _rotationAngleFor(center, axisA, screenCenter, size);

      final diameter = _sigilWorldRadius * 2 * zoom * size.height * scale;
      // A breathing pulse, offset per area (by its own index) so the 8
      // don't all swell and shrink in lockstep. Capped at
      // [_pulseAmplitude] — see [_sigilWorldRadius]'s own comment on why
      // that keeps the outer ring from ever reaching past the supernova's
      // own light ring, only up to it.
      final pulse = 1.0 + _pulseAmplitude * math.sin(time * 1.1 + i * 0.9);

      canvas.save();
      canvas.translate(screenCenter.dx, screenCenter.dy);
      canvas.rotate(rotation);
      canvas.scale(pulse);
      _paintSigil(canvas, diameter / 2, i);
      canvas.restore();
    }
    canvas.restore();
  }

  /// The on-screen angle [axisA] itself projects to, relative to
  /// [screenCenter] — found by projecting a point [_epsilon] further
  /// along [axisA] from [center] and measuring the angle to *that* point,
  /// the same small-offset technique
  /// `constellation_field.dart`'s own `_projectConstellationTransform`
  /// uses for the analogous problem (orienting a constellation's shape to
  /// the camera). Falls back to no rotation if that second point happens
  /// to project behind the camera (practically never, since it's barely
  /// off from [center] itself).
  double _rotationAngleFor(
    _Vec3 center,
    _Vec3 axisA,
    Offset screenCenter,
    Size size,
  ) {
    final offsetDir = _normalized(_add(center, _scaled(axisA, _epsilon)));
    final offsetProjected = _projectDirection(offsetDir, camera, zoom, size);
    if (offsetProjected == null) return 0.0;
    final delta = offsetProjected.$1 - screenCenter;
    return math.atan2(delta.dy, delta.dx);
  }

  /// A fixed ring pinned to the supernova's own light ring, unaffected by
  /// the sigil's own pulse/rotation — see [_lightRingCenterWorldRadius].
  /// Slightly thicker and softly glowing (a blurred pass underneath a
  /// crisper one on top) compared to the sigil's own plain rings, so it
  /// reads as the one fixed anchor everything else moves around.
  void _paintAnchorRing(
    Canvas canvas,
    Offset center,
    double radius,
    int areaIndex,
  ) {
    if (radius <= 0) return;
    final color = _sigilColor(areaIndex);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.06)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        math.max(1.0, radius * 0.05),
      );
    canvas.drawCircle(center, radius, glowPaint);
    final crispPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, radius * 0.028);
    canvas.drawCircle(center, radius, crispPaint);
  }

  /// Draws one sigil in its own local space — already translated to its
  /// center and rotated so local +x is that star's own axisA (see
  /// [_rotationAngleFor]) and local +y is axisB, matching
  /// `sky_supernova.frag`'s spike directions exactly (stereographic
  /// projection is conformal — angle-preserving everywhere — so axisA and
  /// axisB really do stay exactly perpendicular on screen, making a
  /// single rotation of the whole local frame valid rather than an
  /// approximation).
  void _paintSigil(Canvas canvas, double radius, int areaIndex) {
    final recipe = _SigilRecipe.forArea(areaIndex);
    final color = _sigilColor(areaIndex);
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, radius * 0.018)
      ..strokeCap = StrokeCap.round;
    // A fainter, thinner stroke for the extra ornamentation (the core
    // ring, and the motifs' own connecting arcs) — present without
    // competing with the main rings/cross for attention.
    final fineStrokePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, radius * 0.012)
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = color.withValues(alpha: 0.8);
    final accentColor = color.withValues(alpha: 0.8);

    // One or two concentric rings (see [_SigilRecipe.ringCount]) — the
    // innermost one is what the inner motif sits within, so there's never
    // an ambiguous sliver of overlap between them.
    final innerRingRadius = recipe.ringCount == 2 ? radius * 0.86 : radius;
    canvas.drawCircle(Offset.zero, radius, strokePaint);
    if (recipe.ringCount == 2) {
      canvas.drawCircle(Offset.zero, innerRingRadius, strokePaint);
    }

    // A thin core ring purely for extra depth — only on areas whose
    // recipe calls for it (see [_SigilRecipe.hasCoreRing]).
    if (recipe.hasCoreRing) {
      canvas.drawCircle(Offset.zero, radius * 0.46, fineStrokePaint);
    }

    // The inner motif — see [_InnerMotif] — carries its own icons as part
    // of the same rotating group, so nothing in the middle sits still
    // while the rest turns around it.
    final innerRotation = time * _innerRotationSpeed;
    switch (recipe.innerMotif) {
      case _InnerMotif.spiral:
        _paintSpiral(
          canvas,
          innerRingRadius,
          innerRotation,
          recipe,
          strokePaint,
          accentColor,
        );
      case _InnerMotif.starRing:
        _paintStarRing(
          canvas,
          innerRingRadius,
          innerRotation,
          recipe,
          fineStrokePaint,
          accentColor,
        );
    }

    // A cross reaching from the center out to the outer ring exactly,
    // along local +x/+y/-x/-y (axisA/axisB and their opposites) — this is
    // the part that has to stay locked to the star's own spikes, so it's
    // never touched by [innerRotation].
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(Offset.zero, dir * radius, strokePaint);
      final petalHalf = radius * 0.07 * recipe.petalSizeFactor;
      _paintPetal(canvas, dir * radius, angle, petalHalf, fillPaint);
    }

    // Center sparkle — SkySupernova's own icon/glow paints right on top
    // of this same point.
    canvas.drawCircle(Offset.zero, radius * 0.045, fillPaint);
  }

  /// [_SigilRecipe.motifElementCount] curved "S"-shaped arms spiraling out
  /// from near the center to [maxRadius] (sampled as a polyline — smooth
  /// enough at this on-screen size without needing true Bezier segments),
  /// each carrying two sparkle icons trailing along its own length.
  void _paintSpiral(
    Canvas canvas,
    double maxRadius,
    double innerRotation,
    _SigilRecipe recipe,
    Paint strokePaint,
    Color accentColor,
  ) {
    final armCount = recipe.motifElementCount;
    const turns = 0.6;
    const steps = 20;
    for (var arm = 0; arm < armCount; arm++) {
      final startAngle = innerRotation + arm * (2 * math.pi / armCount);
      final path = Path();
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final r = maxRadius * t;
        final angle = startAngle + t * turns * 2 * math.pi;
        final point = Offset(math.cos(angle), math.sin(angle)) * r;
        if (s == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, strokePaint);

      for (final t in [0.55, 1.0]) {
        final r = maxRadius * t;
        final angle = startAngle + t * turns * 2 * math.pi;
        final point = Offset(math.cos(angle), math.sin(angle)) * r;
        _paintIcon(
          canvas,
          point,
          maxRadius * 0.15,
          recipe.accentIcon,
          accentColor,
        );
      }
    }
  }

  /// [_SigilRecipe.motifElementCount] sparkle icons evenly spaced on a
  /// ring, threaded together by a scalloped connecting arc (a quadratic
  /// Bezier dipping slightly inward between each pair) — a beaded
  /// necklace rather than a plain circle of icons floating separately.
  void _paintStarRing(
    Canvas canvas,
    double maxRadius,
    double innerRotation,
    _SigilRecipe recipe,
    Paint fineStrokePaint,
    Color accentColor,
  ) {
    final count = recipe.motifElementCount;
    // Farther out than an earlier pass (0.62) — too close to the center,
    // the icons were getting partly covered by SkySupernova's own glow
    // painted on top of this at that same central point.
    final ringRadius = maxRadius * 0.8;

    final path = Path();
    for (var i = 0; i <= count; i++) {
      final angle = innerRotation + i * (2 * math.pi / count);
      final point = Offset(math.cos(angle), math.sin(angle)) * ringRadius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        final midAngle = angle - math.pi / count;
        final control =
            Offset(math.cos(midAngle), math.sin(midAngle)) *
            (ringRadius * 0.75);
        path.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
      }
    }
    canvas.drawPath(path, fineStrokePaint);

    for (var i = 0; i < count; i++) {
      final angle = innerRotation + i * (2 * math.pi / count);
      final point = Offset(math.cos(angle), math.sin(angle)) * ringRadius;
      _paintIcon(
        canvas,
        point,
        maxRadius * 0.17,
        recipe.accentIcon,
        accentColor,
      );
    }
  }

  /// A small icon glyph centered at [center] — the same stroke/fill-text
  /// technique `sky_supernova.dart`'s own `_paintOutlineIcon` uses to
  /// render a Material [IconData] onto a canvas, just plain-filled here
  /// rather than outlined/glowing, since these are meant to read as small
  /// scattered sparkles rather than another focal point.
  void _paintIcon(
    Canvas canvas,
    Offset center,
    double size,
    IconData icon,
    Color color,
  ) {
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  /// A small petal/leaf shape stretched along [angle] (its "outward"
  /// direction) rather than a plain diamond — reads as a tip pointing
  /// away from the sigil's own center, the way the reference image's own
  /// accents do, and its two side points sit exactly on the circle/line
  /// [center] was already placed on, so it never pokes out one side more
  /// than the other by some arbitrary, accidental-looking amount.
  void _paintPetal(
    Canvas canvas,
    Offset center,
    double angle,
    double halfLength,
    Paint paint,
  ) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final perp = Offset(-dir.dy, dir.dx);
    final halfWidth = halfLength * 0.55;
    final path = Path()
      ..moveTo(center.dx + dir.dx * halfLength, center.dy + dir.dy * halfLength)
      ..lineTo(center.dx + perp.dx * halfWidth, center.dy + perp.dy * halfWidth)
      ..lineTo(center.dx - dir.dx * halfLength, center.dy - dir.dy * halfLength)
      ..lineTo(center.dx - perp.dx * halfWidth, center.dy - perp.dy * halfWidth)
      ..close();
    canvas.drawPath(path, paint);
  }

  /// A distinct shade of gold per area — a small hue swing around
  /// [kConstellationGold], not a full rainbow, so all 8 still read as "the
  /// same gold family of stars" (matching `sky_supernova.frag`'s own
  /// deliberate choice to share one gold across every supernova) while
  /// still being tellable apart at a glance.
  Color _sigilColor(int index) {
    final hsl = HSLColor.fromColor(kConstellationGold);
    final hueShift = (index - (LifeArea.values.length - 1) / 2) * 7.0;
    return hsl.withHue((hsl.hue + hueShift) % 360).toColor();
  }

  @override
  bool shouldRepaint(covariant _SkyAreaSigilsPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom ||
      oldDelegate.time != time;
}
