import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'constellation_field.dart';

/// An alternative take on the same slot/job [SkyDecorations] fills (see
/// `NebulaScreen.build` — only one of the two is ever wired in at a time):
/// wispy, filamentary nebula clouds plus a scatter of colored sparkle
/// stars, modeled after a Hubble-style violet/magenta/blue reference photo
/// rather than [SkyDecorations]'s spiral-galaxy look. Structured
/// identically to [SkyDecorations]/`NebulaBackground` on purpose — same
/// ticker/shader-load/CustomPaint shape — so swapping which one is active
/// in the Stack is the only thing that ever needs to change.
class SkyWisps extends StatefulWidget {
  const SkyWisps({super.key, required this.camera, required this.zoom});

  final SkyCamera camera;
  final double zoom;

  @override
  State<SkyWisps> createState() => _SkyWispsState();
}

class _SkyWispsState extends State<SkyWisps>
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
      'shaders/sky_wisps.frag',
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
    // Nothing to draw yet — purely additive, so "not there yet" and
    // "fully transparent" look identical.
    if (shader == null) return const SizedBox.shrink();

    return CustomPaint(
      size: Size.infinite,
      painter: _SkyWispsPainter(
        shader: shader,
        time: _elapsed.inMicroseconds / Duration.microsecondsPerSecond,
        camera: widget.camera,
        zoom: widget.zoom,
      ),
    );
  }
}

class _SkyWispsPainter extends CustomPainter {
  const _SkyWispsPainter({
    required this.shader,
    required this.time,
    required this.camera,
    required this.zoom,
  });

  final ui.FragmentShader shader;
  final double time;
  final SkyCamera camera;
  final double zoom;

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
  }

  @override
  bool shouldRepaint(covariant _SkyWispsPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.camera != camera ||
      oldDelegate.zoom != zoom;
}
