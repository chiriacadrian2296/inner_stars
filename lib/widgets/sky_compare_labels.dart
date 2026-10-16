import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'constellation_field.dart';

/// COMPARISON (2026-10-16), temporary: labels the galaxy and nebula looks
/// placed side by side in `shaders/nebula_particles.glsl`, so they can be
/// compared on the sky. Drop this file, its call in `sky_screen.dart` and the
/// shader's comparison blocks once a look is picked.
const bool kShowSkyCompareLabels = true;

/// Must match `galaxyCenter` in the shader.
const _galaxies = <(String, (double, double, double))>[
  ('G1 · Originale', (0.853, 0.502, -0.144)),
  ('G2 · Spirale (v1)', (-0.302, -0.499, -0.812)),
  ('G3 · Di taglio, grande', (-0.653, 0.620, -0.435)),
  ('G4 · Di taglio, media', (0.706, -0.612, 0.358)),
];

class SkyCompareLabels extends StatelessWidget {
  const SkyCompareLabels({super.key, required this.camera, required this.zoom});

  final SkyCamera camera;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CompareLabelsPainter(camera: camera, zoom: zoom),
      ),
    );
  }
}

typedef _Vec = (double, double, double);

_Vec _norm(_Vec v) {
  final l = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2 + v.$3 * v.$3);
  return (v.$1 / l, v.$2 / l, v.$3 / l);
}

_Vec _cross(_Vec a, _Vec b) => (
  a.$2 * b.$3 - a.$3 * b.$2,
  a.$3 * b.$1 - a.$1 * b.$3,
  a.$1 * b.$2 - a.$2 * b.$1,
);

/// Where the shader's area nebula `index` is centered: its supernova pushed
/// 0.36 rad toward a per-area bearing.
_Vec _nebulaCenter(int index) {
  final s = supernovaDirection(index, 8);
  final ref = s.$2.abs() < 0.99 ? (0.0, 1.0, 0.0) : (1.0, 0.0, 0.0);
  final a = _norm(_cross(ref, s));
  final b = _cross(s, a);
  final bearing = index * 2.4 + 0.7;
  final cb = math.cos(bearing), sb = math.sin(bearing);
  return _norm((
    s.$1 + (a.$1 * cb + b.$1 * sb) * 0.36,
    s.$2 + (a.$2 * cb + b.$2 * sb) * 0.36,
    s.$3 + (a.$3 * cb + b.$3 * sb) * 0.36,
  ));
}

Offset _world(_Vec d) => Offset(
  math.atan2(d.$3, d.$1) / (2 * math.pi),
  math.asin(d.$2.clamp(-1.0, 1.0)) / (2 * math.pi),
);

class _CompareLabelsPainter extends CustomPainter {
  _CompareLabelsPainter({required this.camera, required this.zoom});

  final SkyCamera camera;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final labels = <(String, _Vec)>[
      for (final (name, dir) in _galaxies) (name, dir),
      ('N1 · Nebulosa, ammasso (v1)', _nebulaCenter(0)),
      ('N2 · Nebulosa, filamenti (v2)', _nebulaCenter(1)),
    ];
    for (final (name, dir) in labels) {
      final projected = worldToScreen(_world(dir), camera, zoom, size);
      if (projected == null) continue;
      final at = projected.position;
      if (!(Offset.zero & size).inflate(80).contains(at)) continue;

      final text = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromCenter(
        center: at,
        width: text.width + 16,
        height: text.height + 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(10)),
        Paint()..color = const Color(0xAA05070D),
      );
      text.paint(canvas, box.topLeft + const Offset(8, 4));
    }
  }

  @override
  bool shouldRepaint(_CompareLabelsPainter old) =>
      old.camera != camera || old.zoom != zoom;
}
