import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_layout.dart';
import 'package:inner_stars/data/constellation_shape.dart';

void main() {
  group('buildConstellationLayout', () {
    test(
      'a shape with no edges at all does not crash when count exceeds its '
      'own points — stops growing at the shape\'s own points instead of '
      'indexing into an empty edge list',
      () {
        const shape = ConstellationShape(
          points: [Offset(0.2, 0.2), Offset(0.8, 0.8)],
          edges: [],
        );

        final layout = buildConstellationLayout(shape, 10);

        expect(layout.points, shape.points);
        expect(layout.edges, isEmpty);
      },
    );

    test('count within the shape\'s own points just slices them, edges untouched', () {
      const shape = ConstellationShape(
        points: [Offset(0.1, 0.1), Offset(0.5, 0.5), Offset(0.9, 0.9)],
        edges: [(0, 1), (1, 2)],
      );

      final layout = buildConstellationLayout(shape, 2);

      expect(layout.points, [const Offset(0.1, 0.1), const Offset(0.5, 0.5)]);
      expect(layout.edges, shape.edges);
    });

    test('growing past the shape\'s own points splits the longest edge repeatedly', () {
      const shape = ConstellationShape(
        points: [Offset(0, 0), Offset(1, 0)],
        edges: [(0, 1)],
      );

      final layout = buildConstellationLayout(shape, 3);

      expect(layout.points.length, 3);
      expect(layout.points[2], const Offset(0.5, 0));
      expect(layout.edges, [(0, 2), (2, 1)]);
    });

    test('an empty shape (no points) returns an empty layout, not a crash', () {
      const shape = ConstellationShape(points: [], edges: []);

      final layout = buildConstellationLayout(shape, 5);

      expect(layout.points, isEmpty);
      expect(layout.edges, isEmpty);
    });

    test('count of zero or less returns an empty layout regardless of the shape', () {
      const shape = ConstellationShape(
        points: [Offset(0.1, 0.1), Offset(0.9, 0.9)],
        edges: [(0, 1)],
      );

      expect(buildConstellationLayout(shape, 0).points, isEmpty);
      expect(buildConstellationLayout(shape, -1).points, isEmpty);
    });
  });
}
