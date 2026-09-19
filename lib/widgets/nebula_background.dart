import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import 'constellation_field.dart';

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
    this.showGrid = false,
  });

  final SkyCamera camera;
  final double zoom;

  /// Debug aid: overlays meridian/parallel lines on the sky sphere so
  /// pole proximity and field of view can be gauged by eye — see
  /// `NebulaScreen`'s own toggle for this.
  final bool showGrid;

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground>
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
      'shaders/nebula_particles.frag',
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
        time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
        camera: widget.camera,
        zoom: widget.zoom,
        showGrid: widget.showGrid,
      ),
    );
  }
}

class _NebulaPainter extends CustomPainter {
  const _NebulaPainter({
    required this.shader,
    required this.time,
    required this.camera,
    required this.zoom,
    required this.showGrid,
  });

  final ui.FragmentShader shader;
  final double time;
  final SkyCamera camera;
  final double zoom;
  final bool showGrid;

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
      ..setFloat(12, zoom)
      ..setFloat(13, showGrid ? 1.0 : 0.0);
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
      oldDelegate.time != time ||
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom ||
      oldDelegate.showGrid != showGrid;
}
