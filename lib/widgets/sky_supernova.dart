import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/life_area.dart';
import 'constellation_field.dart';

/// Another alternative take on the same slot [SkyDecorations]/[SkyWisps]/
/// `SkyBlackHole` filled before it (see `NebulaScreen.build` — only one is
/// ever wired in at a time): 8 simple, lens-flare-style stars, one per
/// [LifeArea] — the shader (`shaders/sky_supernova.frag`) draws every
/// glow/ring/spike in the same shared gold, additively (`BlendMode.plus`,
/// like [SkyDecorations]/[SkyWisps] — a pure glow with nothing to
/// occlude); this widget's own [_SkySupernovaPainter] then draws each
/// area's own icon straight on top of that glow — a plain white fill, a
/// vivid gold-gradient border, and a slowly-rotating glow of the same
/// gradient (see [_paintOutlineIcon]) — with no attempt to occlude or cut
/// through the glow beneath it. A fragment shader has no way to rasterize
/// a font glyph on its own, so the icon happens here in Dart instead.
///
/// A whole family of "punch a hole in the glow, reveal NebulaBackground
/// through it" looks were tried here first — a dark navy icon as the hole
/// itself, a white icon floating inside a separate disc-shaped hole, a
/// hollow icon whose own interior was part of that hole — dropped
/// altogether (along with the disc-hole technique's own churn: a
/// per-star `saveLayer`/`BlendMode.dstOut` punch, then a single combined
/// spatial clip, then back, then an edge-of-screen containment guard on
/// top of that) once it added up to more moving parts than the payoff
/// justified, including a real bug (a disc straddling the screen's own
/// edge rendered solid black) and, after that fix, icons that vanished
/// near the screen edge instead of just sliding off it normally. Plain
/// icon-on-glow, this file's very first look, never had either problem.
class SkySupernova extends StatefulWidget {
  const SkySupernova({super.key, required this.camera, required this.zoom});

  final SkyCamera camera;
  final double zoom;

  @override
  State<SkySupernova> createState() => _SkySupernovaState();
}

class _SkySupernovaState extends State<SkySupernova>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed))
      ..start();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/sky_supernova.frag',
    );
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();

    return CustomPaint(
      size: Size.infinite,
      painter: _SkySupernovaPainter(
        shader: shader,
        time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
        camera: widget.camera,
        zoom: widget.zoom,
      ),
    );
  }
}

typedef _Vec3 = (double x, double y, double z);

double _dot3(_Vec3 a, _Vec3 b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

/// The forward (3D-direction -> screen) half of the same stereographic
/// projection `constellation_field.dart`'s own `worldToScreen`/the sky
/// shaders' inverse-stereographic `main()` use — see either of those for
/// the full derivation. Takes a raw direction rather than an
/// (azimuthTurns, elevationTurns) pair (unlike `worldToScreen`, which this
/// widget can't reuse directly since [_supernovaDirection] returns a raw
/// unit vector, not an azimuth/elevation pair) but is otherwise the exact
/// same formula, so the result lines up with the shader's own placement of
/// the star exactly. Returns the projected point plus the projection's own
/// scale factor (bigger toward the field of view's edges), which is what
/// [_SkySupernovaPainter] sizes each icon by — the same reason a
/// constellation's own icons grow/shrink with projection distance.
(Offset, double)? _projectDirection(
  _Vec3 dir,
  SkyCamera camera,
  double zoom,
  Size size,
) {
  final z = _dot3(dir, camera.forward);
  if (z < -0.5) return null;
  final scale = 2 / (1 + z);
  final x = _dot3(dir, camera.right) * scale;
  final y = _dot3(dir, camera.up) * scale;
  return (
    Offset(
      size.width / 2 + x * zoom * size.height,
      size.height / 2 - y * zoom * size.height,
    ),
    scale,
  );
}

/// The per-area glyph [_SkySupernovaPainter._paintOutlineIcon] draws on top
/// of each supernova's own glow — a plain white fill, gold gradient
/// border, slowly-rotating glow — screen-aligned rather than rotated with
/// the sky (it sits on top of everything and stays upright no matter how
/// the camera rolls). Parked 2026-09-18 at the user's request; left in
/// place, gated behind this flag rather than deleted, so turning it back
/// on is a one-line flip. See the project's "TRB" (to-remember box)
/// memory for the standing list of things parked this way.
const bool _kShowSupernovaIcons = false;

class _SkySupernovaPainter extends CustomPainter {
  const _SkySupernovaPainter({
    required this.shader,
    required this.time,
    required this.camera,
    required this.zoom,
  });

  final ui.FragmentShader shader;
  final double time;
  final SkyCamera camera;
  final double zoom;

  // Roughly the on-sky radius of each star's own bright core (see
  // sky_supernova.frag's starMetric/core) — the icon is sized to sit just
  // inside it, the same way the app's own icon keeps its glyph within the
  // gold field behind it rather than overrunning it.
  static const _iconWorldRadius = 0.0048;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, camera.forward.$1)
      ..setFloat(4, camera.forward.$2)
      ..setFloat(5, camera.forward.$3)
      ..setFloat(6, camera.right.$1)
      ..setFloat(7, camera.right.$2)
      ..setFloat(8, camera.right.$3)
      ..setFloat(9, camera.up.$1)
      ..setFloat(10, camera.up.$2)
      ..setFloat(11, camera.up.$3)
      ..setFloat(12, zoom);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );

    // An area near the edge of the sky view projects to a center point
    // outside this canvas's own bounds — expected, since only part of its
    // icon (or the blurred glow around it — see _paintOutlineIcon's own
    // maskFilter, which reaches further out than the glyph itself) should
    // be visible there. Without an explicit clip, that overflow paints
    // straight through into whatever sits beside this pane in the wider
    // layout (the desktop/web sidebar) instead of just disappearing
    // off-screen — see `ConstellationFieldPainter.paint`'s own identical
    // clip, added for the exact same reason on that layer.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (_kShowSupernovaIcons) {
      final areas = LifeArea.values;
      for (var i = 0; i < areas.length; i++) {
        final projected = _projectDirection(
          supernovaDirection(i, areas.length),
          camera,
          zoom,
          size,
        );
        if (projected == null) continue;
        final (center, scale) = projected;
        final diameter = _iconWorldRadius * 2 * zoom * size.height * scale;
        _paintOutlineIcon(canvas, center, diameter, areas[i].icon);
      }
    }
    canvas.restore();
  }

  /// A shared color stop pair for the border and its glow — started from
  /// colors sampled straight off the star's own rendered pixels (its ring
  /// and the pale edge of its rays), nudged a little warmer/redder and a
  /// little more saturated from there (asked for explicitly, "un po' di
  /// tutto" — small nudges on both ends, not a big color shift).
  static const _borderGradientColors = [Color(0xFFFFEFA0), Color(0xFFF0C078)];

  /// The icon's own silhouette: a plain white fill, a vivid blue gradient
  /// border, and that same gradient again — blurred, for a short glow —
  /// slowly orbiting the icon rather than sitting fixed like the border
  /// itself. All three via `TextStyle.foreground` (the stroke/fill-text
  /// technique — `TextStyle` has no stroke+fill+blur of its own, but a
  /// `Paint` with those set, dropped into `foreground`, reproduces each).
  void _paintOutlineIcon(Canvas canvas, Offset center, double diameter, IconData icon) {
    final text = String.fromCharCode(icon.codePoint);
    // Border thinned further (was diameter * 0.03) and the glow pulled
    // shortened again (was diameter * 0.14, then 0.11).
    final borderWidth = diameter * 0.022;
    final glowWidth = diameter * 0.08;

    // The glow's gradient is the same two colors as the border's own, just
    // spun around [center] by an angle that grows with [time] — a rotating
    // gradient rather than a rotating shape, so the glow itself doesn't
    // need to move, only which end of it is "light" and which is "dark".
    // A faster spin (was 0.6) for a shorter, quicker-feeling cycle.
    final glowAngle = time * 2.2;
    final glowAxis = Offset(math.cos(glowAngle), math.sin(glowAngle)) * (diameter / 2);
    final glowShader = ui.Gradient.linear(
      center - glowAxis,
      center + glowAxis,
      _borderGradientColors,
    );

    final glowPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: diameter,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = glowWidth
            ..shader = glowShader
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, diameter * 0.04),
        ),
      )
      ..layout();

    final fillPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: diameter,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();

    // The border's own gradient stays fixed top-to-bottom (only the glow
    // behind it rotates) — approximated over [center] ± diameter/2 rather
    // than the glyph's own laid-out bounds, since `Gradient.linear` needs
    // its endpoints before `TextPainter.layout()` has run.
    final borderShader = ui.Gradient.linear(
      Offset(center.dx, center.dy - diameter / 2),
      Offset(center.dx, center.dy + diameter / 2),
      _borderGradientColors,
    );

    final outlinePainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: diameter,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth
            ..shader = borderShader,
        ),
      )
      ..layout();

    final topLeft = center - Offset(outlinePainter.width / 2, outlinePainter.height / 2);
    glowPainter.paint(canvas, topLeft);
    fillPainter.paint(canvas, topLeft);
    outlinePainter.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(covariant _SkySupernovaPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom;
}
