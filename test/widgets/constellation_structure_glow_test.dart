import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_structure_glow.dart';

void main() {
  testWidgets('connection mask excludes whole discs including crossing '
      'segments', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintOutsideDiscs(
        canvas,
        const Rect.fromLTWH(0, 0, 120, 120),
        [(const Offset(30, 60), 14), (const Offset(90, 60), 14)],
        () => canvas.drawLine(
          const Offset(0, 60),
          const Offset(120, 60),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 4,
        ),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 120);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => bytes.getUint8((y * 120 + x) * 4 + 3);
      expect(alpha(30, 60), 0);
      expect(alpha(42, 60), 0);
      expect(alpha(90, 60), 0);
      expect(alpha(60, 60), greaterThan(0));
      image.dispose();
      picture.dispose();
    });
  });
  testWidgets('tooltip glow stays outside the white frame', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(20, 20);
      const ConstellationTooltipGlowPainter(
        frameWidth: 8,
        radius: 12,
      ).paint(canvas, const Size(80, 60));
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 100);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => bytes.getUint8((y * 120 + x) * 4 + 3);
      expect(alpha(60, 50), 0);
      expect(alpha(60, 22), 0);
      expect(alpha(60, 15), greaterThan(0));
      image.dispose();
      picture.dispose();
    });
  });
  testWidgets('focus preserves selected ring light and dims the other rings', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      const ConstellationStructureGlowPainter(
        segments: [],
        discs: [(Offset(30, 60), 14), (Offset(90, 60), 14)],
        strokeWidth: 4,
        color: Colors.white,
        focusedDiscIndex: 0,
        inactiveOpacity: 0.32,
      ).paint(Canvas(recorder), const Size(120, 120));
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 120);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => bytes.getUint8((y * 120 + x) * 4 + 3);
      expect(alpha(30, 60), 0);
      expect(alpha(90, 60), 0);
      expect(alpha(110, 60), greaterThan(0));
      expect(alpha(50, 60), greaterThan(alpha(110, 60) * 2));
      image.dispose();
      picture.dispose();
    });
  });
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
