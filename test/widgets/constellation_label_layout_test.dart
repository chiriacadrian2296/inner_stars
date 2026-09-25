import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_label_layout.dart';
import 'package:inner_stars/widgets/constellation_map/pulsar_spacing.dart';
import 'package:inner_stars/widgets/constellation_painter.dart';

// A ring of ten stars around a center one, at a given zoom — roughly what a
// project's constellation looks like on a phone.
List<MapNode> _ringNodes(double zoom, {int count = 10}) {
  return [
    for (var i = 0; i < count; i++)
      MapNode(
        id: i,
        center: Offset(
          180 + 120 * zoom * math.cos(2 * math.pi * i / count),
          320 + 150 * zoom * math.sin(2 * math.pi * i / count),
        ),
        radius: 24,
      ),
    MapNode(id: count, center: const Offset(180, 320), radius: 24),
  ];
}

void main() {
  group('layoutConstellationLabels', () {
    for (final zoom in [0.7, 1.0, 1.6, 2.4]) {
      test('places every label clear of labels and buttons at zoom $zoom', () {
        final nodes = _ringNodes(zoom);
        final layout = layoutConstellationLabels(
          nodes: nodes,
          labelSize: (id, scale) => Size(96 * scale, 30 * scale),
          anchor: const Offset(180, 320),
          edges: [
            for (var i = 0; i < 10; i++)
              (nodes[i].center, nodes[(i + 1) % 10].center),
          ],
        );

        expect(layout.placements.length, nodes.length);
        expect(layout.overlaps, 0);
        final rects = [for (final p in layout.placements.values) p.rect];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse);
          }
          for (final node in nodes) {
            final nearest = Offset(
              node.center.dx.clamp(rects[i].left, rects[i].right),
              node.center.dy.clamp(rects[i].top, rects[i].bottom),
            );
            expect((nearest - node.center).distance, greaterThanOrEqualTo(node.radius));
          }
        }
      });
    }

    test('gives no label to a star that has no size', () {
      final layout = layoutConstellationLabels(
        nodes: _ringNodes(1),
        labelSize: (id, scale) => id.isEven ? null : const Size(80, 28),
      );
      expect(layout.placements.keys.every((id) => id.isOdd), isTrue);
    });

    test('handles no stars, and a lone star', () {
      expect(
        layoutConstellationLabels(
          nodes: const [],
          labelSize: (id, scale) => const Size(80, 28),
        ).placements,
        isEmpty,
      );
      final layout = layoutConstellationLabels(
        nodes: const [MapNode(id: 0, center: Offset(100, 100), radius: 20)],
        labelSize: (id, scale) => const Size(80, 28),
      );
      expect(layout.placements.length, 1);
      expect(layout.overlaps, 0);
    });

    test('shrinks labels when they cannot all fit at full size', () {
      // Six stars packed into a 60px cluster with wide labels.
      final nodes = [
        for (var i = 0; i < 6; i++)
          MapNode(
            id: i,
            center: Offset(100 + (i % 3) * 20, 100 + (i ~/ 3) * 20),
            radius: 8,
          ),
      ];
      final layout = layoutConstellationLabels(
        nodes: nodes,
        labelSize: (id, scale) => Size(110 * scale, 30 * scale),
      );
      expect(layout.placements.length, 6);
      expect(layout.labelScale, lessThanOrEqualTo(1));
    });

    test('is deterministic', () {
      LabelLayout run() => layoutConstellationLabels(
        nodes: _ringNodes(1.2),
        labelSize: (id, scale) => Size(90 * scale, 28 * scale),
        anchor: const Offset(180, 320),
      );
      final a = run();
      final b = run();
      for (final id in a.placements.keys) {
        expect(a.placements[id]!.rect, b.placements[id]!.rect);
      }
    });

    test('keeps the previous choice when nothing changed', () {
      final first = layoutConstellationLabels(
        nodes: _ringNodes(1),
        labelSize: (id, scale) => const Size(90, 28),
        anchor: const Offset(180, 320),
      );
      final second = layoutConstellationLabels(
        nodes: _ringNodes(1),
        labelSize: (id, scale) => const Size(90, 28),
        anchor: const Offset(180, 320),
        previous: {
          for (final e in first.placements.entries) e.key: e.value.candidate,
        },
      );
      for (final id in first.placements.keys) {
        expect(second.placements[id]!.candidate, first.placements[id]!.candidate);
      }
    });

    test('the leader starts and ends clear of the star and the label', () {
      final layout = layoutConstellationLabels(
        nodes: const [MapNode(id: 0, center: Offset(200, 200), radius: 20)],
        labelSize: (id, scale) => const Size(80, 28),
      );
      final placement = layout.placements[0]!;
      expect(
        (placement.lineStart - const Offset(200, 200)).distance,
        greaterThan(20),
      );
      expect(placement.rect.contains(placement.lineEnd), isFalse);
      final bounds = placement.path.getBounds().inflate(1);
      expect(bounds.contains(placement.lineStart), isTrue);
      expect(bounds.contains(placement.lineEnd), isTrue);
    });
  });

  group('spreadScatteredStars', () {
    ConstellationStar star(int id, Offset position, {int? slot}) =>
        ConstellationStar(
          entityId: id,
          position: position,
          kind: slot == null ? StarKind.pulsar : StarKind.lit,
          lit: true,
          label: 'x$id',
          slotSequence: slot,
        );

    test('pushes a pulsar off a slotted star and leaves the slotted star', () {
      final stars = [
        star(1, const Offset(0.5, 0.5), slot: 1),
        star(2, const Offset(0.5, 0.5)),
        star(3, const Offset(0.505, 0.5)),
      ];
      final out = spreadScatteredStars(
        stars,
        canvasSize: const Size(1000, 1000),
        minSeparation: 100,
      );
      expect(out[0].position, const Offset(0.5, 0.5));
      Offset px(ConstellationStar s) => s.position * 1000;
      expect((px(out[1]) - px(out[0])).distance, greaterThanOrEqualTo(99));
      expect((px(out[2]) - px(out[0])).distance, greaterThanOrEqualTo(99));
      expect((px(out[1]) - px(out[2])).distance, greaterThanOrEqualTo(99));
      expect(out[1].label, 'x2');
    });

    test('leaves already-clear stars untouched', () {
      final stars = [
        star(1, const Offset(0.1, 0.1), slot: 1),
        star(2, const Offset(0.9, 0.9)),
      ];
      final out = spreadScatteredStars(
        stars,
        canvasSize: const Size(1000, 1000),
        minSeparation: 100,
      );
      expect(identical(out, stars), isTrue);
    });
  });
}
