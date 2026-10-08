import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_layout.dart';
import 'package:inner_stars/data/constellation_shape.dart';

void main() {
  // A short diagonal line across the middle: plenty of free room around it.
  const shape = ConstellationShape(
    points: [Offset(0.35, 0.35), Offset(0.5, 0.5), Offset(0.65, 0.65)],
    edges: [(0, 1), (1, 2)],
  );

  double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  test('a pulsar never lands near the shape or another pulsar', () {
    for (var seed = 1; seed <= 300; seed++) {
      final placed = <Offset>[];
      for (var i = 0; i < kMaxConstellationPulsars; i++) {
        final p = seededPulsarPosition(
          seed * 1000 + i,
          shape: shape,
          avoid: placed,
        );
        for (final (a, b) in shape.edges) {
          expect(
            distanceToSegment(p, shape.points[a], shape.points[b]),
            greaterThanOrEqualTo(kPulsarShapeClearance),
          );
        }
        placed.add(p);
      }
    }
  });

  test('a pulsar keeps its place when another one is added', () {
    final first = seededPulsarPosition(7, shape: shape);
    final again = seededPulsarPosition(7, shape: shape);
    expect(again, first);
  });
}
