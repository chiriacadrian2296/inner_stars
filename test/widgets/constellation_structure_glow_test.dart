import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_structure_glow.dart';

void main() {
  testWidgets('structural light stays outside discs and solid line strokes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const ConstellationStructureGlowPainter(
        segments: [(Offset(10, 20), Offset(110, 20))],
        discs: [(Offset(60, 70), 18)],
        strokeWidth: 4,
        color: Colors.white,
      ).paint(canvas, const Size(120, 120));
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 120);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => bytes.getUint8((y * 120 + x) * 4 + 3);
      expect(alpha(60, 70), 0);
      expect(alpha(76, 70), 0); // Inside the circular rim, close to its edge.
      expect(alpha(84, 70), greaterThan(0)); // Outside the disc.
      expect(alpha(60, 20), 0); // The sharp stroke is painted separately.
      expect(alpha(60, 25), greaterThan(0)); // Light beside the line.
      image.dispose();
      picture.dispose();
    });
  });
}
