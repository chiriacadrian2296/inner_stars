import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/constellation_editor_painter.dart';

void main() {
  group('normalizeEditorPoints', () {
    test('scales to fit the longest axis, centered at (0.5, 0.5)', () {
      final result = normalizeEditorPoints(const [
        Offset(0, 0),
        Offset(100, 0),
        Offset(0, 50),
      ]);

      // The long axis (x, 0..100) should span [pad, 1-pad].
      final xs = result.map((p) => p.dx);
      expect(xs.reduce((a, b) => a < b ? a : b), closeTo(0.1, 1e-9));
      expect(xs.reduce((a, b) => a > b ? a : b), closeTo(0.9, 1e-9));
      for (final p in result) {
        expect(p.dx, inInclusiveRange(0.0, 1.0));
        expect(p.dy, inInclusiveRange(0.0, 1.0));
      }
    });

    test('a single point lands exactly at the center', () {
      final result = normalizeEditorPoints(const [Offset(37, 42)]);

      expect(result, [const Offset(0.5, 0.5)]);
    });

    test('every point coincident does not divide by zero', () {
      final result = normalizeEditorPoints(const [
        Offset(10, 10),
        Offset(10, 10),
        Offset(10, 10),
      ]);

      expect(result, everyElement(const Offset(0.5, 0.5)));
    });

    test('an empty list stays empty', () {
      expect(normalizeEditorPoints(const []), isEmpty);
    });
  });

  group('snapToGrid', () {
    test('rounds to the nearest grid vertex', () {
      expect(snapToGrid(const Offset(11, 4), 10), const Offset(10, 0));
      expect(snapToGrid(const Offset(16, 26), 10), const Offset(20, 30));
    });

    test('a point already on the grid is unchanged', () {
      expect(snapToGrid(const Offset(30, 40), 10), const Offset(30, 40));
    });

    test('spacing of zero or less is a no-op, not a division by zero', () {
      expect(snapToGrid(const Offset(11, 4), 0), const Offset(11, 4));
      expect(snapToGrid(const Offset(11, 4), -5), const Offset(11, 4));
    });
  });

  group('hitTestEditorPoint', () {
    const points = [Offset(0, 0), Offset(100, 100), Offset(200, 200)];

    test('finds the nearest point within hitRadius', () {
      expect(hitTestEditorPoint(const Offset(3, 3), points), 0);
    });

    test('returns null when nothing is within hitRadius', () {
      expect(
        hitTestEditorPoint(const Offset(50, 50), points, hitRadius: 10),
        isNull,
      );
    });
  });

  group('removeEditorPoint', () {
    const points = [Offset(0, 0), Offset(1, 1), Offset(2, 2), Offset(3, 3)];

    test('removes the point and drops edges referencing it', () {
      const edges = [(0, 1), (1, 2), (2, 3)];

      final (newPoints, newEdges) = removeEditorPoint(points, edges, 1);

      expect(newPoints, [
        const Offset(0, 0),
        const Offset(2, 2),
        const Offset(3, 3),
      ]);
      // Edge (0,1) and (1,2) both referenced index 1 and are dropped;
      // (2,3) survives, reindexed down to (1,2).
      expect(newEdges, [(1, 2)]);
    });

    test('reindexes edges on both endpoints above the removed index', () {
      const edges = [(0, 3)];

      final (newPoints, newEdges) = removeEditorPoint(points, edges, 1);

      expect(newPoints, hasLength(3));
      expect(newEdges, [(0, 2)]);
    });
  });
}
