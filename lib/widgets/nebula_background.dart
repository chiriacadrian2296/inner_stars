import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/life_area.dart';
import '../theme/app_colors.dart';
import 'constellation_field.dart';
import 'sky_clock.dart';

/// A fullscreen animated nebula/starfield, rendered entirely on the GPU by
/// `shaders/nebula_particles.frag` — no image assets, no 3D engine, just a
/// procedural fragment shader repainted every frame. Purely presentational:
/// [camera]/[zoom] are owned by the caller (see `NebulaScreen`), which also
/// drives a scattered field of constellations over the same camera — both
/// need to move together, so there's one shared source of truth for the
/// gesture rather than this widget tracking its own.
class NebulaBackground extends StatefulWidget {
  const NebulaBackground({
    super.key,
    required this.camera,
    required this.zoom,
    required this.clock,
    this.showGrid = false,
    this.supernovaLight = 0,
  });

  /// Drives the shader's animation — see [SkyClock].
  final SkyClock clock;
  final SkyCamera camera;
  final double zoom;

  /// Debug aid: overlays meridian/parallel lines on the sky sphere so
  /// pole proximity and field of view can be gauged by eye — see
  /// `NebulaScreen`'s own toggle for this.
  final bool showGrid;

  /// How strongly the supernovas light the nebula around them (0 for not
  /// at all — e.g. while they are hidden).
  final double supernovaLight;

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/nebula_particles.frag',
    );
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shader = _shader;
    if (shader == null) {
      // Plain fallback while the shader compiles/loads — a flash of the
      // wrong color would be more jarring than a beat of solid night.
      return ColoredBox(color: colors.night);
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _NebulaPainter(
        shader: shader,
        clock: widget.clock,
        camera: widget.camera,
        zoom: widget.zoom,
        showGrid: widget.showGrid,
        supernovaLight: widget.supernovaLight,
      ),
    );
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({
    required this.shader,
    required this.clock,
    required this.camera,
    required this.zoom,
    required this.showGrid,
    required this.supernovaLight,
  }) : super(repaint: clock);

  final ui.FragmentShader shader;
  final SkyClock clock;
  final SkyCamera camera;
  final double zoom;
  final bool showGrid;
  final double supernovaLight;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, clock.seconds)
      ..setFloat(3, camera.forward.$1)
      ..setFloat(4, camera.forward.$2)
      ..setFloat(5, camera.forward.$3)
      ..setFloat(6, camera.right.$1)
      ..setFloat(7, camera.right.$2)
      ..setFloat(8, camera.right.$3)
      ..setFloat(9, camera.up.$1)
      ..setFloat(10, camera.up.$2)
      ..setFloat(11, camera.up.$3)
      ..setFloat(12, zoom)
      ..setFloat(13, showGrid ? 1.0 : 0.0)
      ..setFloat(14, supernovaLight);
    // Where each area's supernova sits, so the nebula can glow around it.
    for (var i = 0; i < LifeArea.values.length; i++) {
      final (x, y, z) = supernovaVisualDirection(LifeArea.values[i]);
      shader
        ..setFloat(15 + i * 3, x)
        ..setFloat(16 + i * 3, y)
        ..setFloat(17 + i * 3, z);
    }
    // Screen (rather than the plain opaque fill this always used to be) —
    // a 2026-09-19 test: SkyAreaBackdrop was moved to sit *behind* this
    // layer in NebulaScreen's own Stack, to see whether it reads as more
    // blended with the sky's own stars/nebula that way instead of sitting
    // on top of them. This shader always outputs alpha 1.0 (fully opaque)
    // for every pixel — normal `BlendMode.srcOver` would have painted
    // straight over whatever SkyAreaBackdrop drew underneath it,
    // completely hiding it, so some non-opaque blend is required for that
    // to show at all. Screen (`1 - (1-src)*(1-dst)`) rather than
    // `BlendMode.plus` (`src+dst`, tried first): both let light through,
    // but plus clips straight to white the moment two bright layers
    // overlap, while screen's multiplicative falloff keeps bright-on-bright
    // areas glowing rather than blowing out — asked for explicitly, "un
    // blending mode che da più influenza alla luce" than the flat-clipping
    // additive did. Since this is normally the very first thing painted
    // (nothing behind it to begin with, most of the time), switching its
    // blend mode changes nothing about its own everyday look.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.supernovaLight != supernovaLight;
}
