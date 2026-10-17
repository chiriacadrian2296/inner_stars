import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_label_layout.dart';

void main() {
  for (final (name, rect, expanded) in [
    (
      'above',
      const Rect.fromLTWH(-40, -120, 80, 60),
      const Rect.fromLTWH(-40, -160, 80, 100),
    ),
    (
      'below',
      const Rect.fromLTWH(-40, 60, 80, 60),
      const Rect.fromLTWH(-40, 60, 80, 100),
    ),
    (
      'beside',
      const Rect.fromLTWH(60, -30, 80, 60),
      const Rect.fromLTWH(60, -50, 80, 100),
    ),
  ]) {
    test('drawer $name keeps its star-facing anchor on every frame', () {
      final placement = LabelPlacement(
        id: 0,
        rect: rect,
        lineStart: const Offset(0, -20),
        lineEnd: const Offset(0, -55),
        horizontal: false,
        candidate: 3,
      );
      final base = LabelLayout(
        placements: {0: placement},
        labelScale: 1,
        overlaps: 0,
      );
      for (final height in [65.0, 80.0, 100.0, 80.0, 65.0, 60.0]) {
        final resized = resizeConstellationLabels(
          base,
          {0: Size(80, height)},
          {0: Offset.zero},
        ).placements[0]!;
        expect(resized.rect.height, height);
        if (name == 'above') expect(resized.rect.bottom, rect.bottom);
        if (name == 'below') expect(resized.rect.top, rect.top);
        if (name == 'beside') expect(resized.rect.center.dy, rect.center.dy);
        expect(resized.lineStart, placement.lineStart);
        expect(resized.lineEnd, placement.lineEnd);
        expect(resized.candidate, 3);
      }
      expect(
        resizeConstellationLabels(
          base,
          {0: const Size(80, 100)},
          {0: Offset.zero},
        ).placements[0]!.rect,
        expanded,
      );
    });
  }
}
