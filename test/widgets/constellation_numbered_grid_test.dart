import 'dart:ui';

import 'package:flutter/painting.dart' show AxisDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_label_layout.dart';

void main() {
  test(
    'numbered cards read by rows below the whole shape without overlaps',
    () {
      for (final columns in [1, 2, 3]) {
        final layout = layoutNumberedCardGrid(
          constellationBounds: const Rect.fromLTWH(0, 0, 400, 300),
          cardSizes: List.generate(9, (i) => Size(200, i.isEven ? 100 : 120)),
          columns: columns,
          scale: 1,
        );
        final cards = layout.placements.values.toList();
        expect(cards, hasLength(9));
        expect(cards.first.rect.top, 340);
        for (var i = 0; i < cards.length; i++) {
          expect(cards[i].id, i);
          for (var j = i + 1; j < cards.length; j++) {
            expect(cards[i].rect.overlaps(cards[j].rect), isFalse);
          }
          if (i % columns != 0) {
            expect(cards[i].rect.top, cards[i - 1].rect.top);
            expect(cards[i].rect.left, greaterThan(cards[i - 1].rect.right));
          }
        }
      }
    },
  );

  test(
    'lower rows follow drawer growth continuously and return when closed',
    () {
      LabelLayout grid(double extra) => layoutNumberedCardGrid(
        constellationBounds: const Rect.fromLTWH(0, 0, 400, 300),
        cardSizes: [
          Size(200, 100 + extra),
          const Size(200, 100),
          const Size(200, 100),
        ],
        columns: 2,
        scale: 1,
      );
      final closed = grid(0);
      for (final extra in [10.0, 25.0, 50.0, 25.0, 10.0, 0.0]) {
        final current = grid(extra);
        expect(current.placements[0]!.rect.top, closed.placements[0]!.rect.top);
        expect(current.placements[1]!.rect, closed.placements[1]!.rect);
        expect(
          current.placements[2]!.rect.top,
          closed.placements[2]!.rect.top + extra,
        );
      }
    },
  );

  test('side columns alternate cards and stay outside the shape', () {
    final layout = layoutNumberedSideColumns(
      constellationBounds: const Rect.fromLTWH(100, 50, 400, 300),
      cardSizes: List.generate(6, (i) => Size(180, 90 + i * 5)),
      scale: 1,
      maxColumnHeight: 500,
    );

    for (var id = 0; id < 6; id++) {
      final rect = layout.placements[id]!.rect;
      if (id.isEven) {
        expect(rect.right, lessThan(100));
      } else {
        expect(rect.left, greaterThan(500));
      }
      for (var other = id + 1; other < 6; other++) {
        expect(rect.overlaps(layout.placements[other]!.rect), isFalse);
      }
    }
  });

  test('side layout adds outward columns when vertical room is short', () {
    final layout = layoutNumberedSideColumns(
      constellationBounds: const Rect.fromLTWH(300, 0, 400, 300),
      cardSizes: List.filled(10, const Size(180, 100)),
      scale: 1,
      maxColumnHeight: 230,
    );

    final firstLeft = layout.placements[0]!.rect;
    final thirdLeft = layout.placements[4]!.rect;
    final firstRight = layout.placements[1]!.rect;
    final thirdRight = layout.placements[5]!.rect;
    expect(thirdLeft.right, lessThan(firstLeft.left));
    expect(thirdRight.left, greaterThan(firstRight.right));
  });

  test('an odd final card sits below while side columns stay symmetric', () {
    final constellation = const Rect.fromLTWH(300, 100, 400, 300);
    final layout = layoutNumberedSideColumns(
      constellationBounds: constellation,
      cardSizes: List.filled(9, const Size(180, 100)),
      scale: 1,
      maxColumnHeight: 230,
    );

    final leftIds = [0, 2, 4, 6];
    final rightIds = [1, 3, 5, 7];
    expect(leftIds, hasLength(rightIds.length));
    for (var i = 0; i < leftIds.length; i++) {
      final left = layout.placements[leftIds[i]]!.rect;
      final right = layout.placements[rightIds[i]]!.rect;
      expect(left.center.dy, right.center.dy);
      expect(
        constellation.center.dx - left.center.dx,
        closeTo(right.center.dx - constellation.center.dx, 0.01),
      );
    }
    final extra = layout.placements[8]!.rect;
    expect(extra.center.dx, constellation.center.dx);
    expect(extra.top, greaterThan(constellation.bottom));
  });

  test('every side column is centered on the constellation', () {
    final layout = layoutNumberedSideColumns(
      constellationBounds: const Rect.fromLTWH(300, 100, 400, 300),
      cardSizes: List.filled(10, const Size(180, 100)),
      scale: 1,
      maxColumnHeight: 230,
    );

    for (final ids in [
      [0, 2],
      [1, 3],
      [4, 6],
      [5, 7],
      [8],
      [9],
    ]) {
      final column = ids.map((id) => layout.placements[id]!.rect);
      final bounds = column.reduce((a, b) => a.expandToInclude(b));
      expect(bounds.center.dy, closeTo(250, 0.01));
    }
  });

  group('star number tabs', () {
    Map<int, AxisDirection> sides(List<Offset> centers) => chooseStarTabSides(
      stars: [
        for (var i = 0; i < centers.length; i++)
          (id: i, center: centers[i], radius: 20),
      ],
      across: (_) => 30,
      out: 24,
    );

    test('sit above their stars when nothing covers them', () {
      expect(sides(const [Offset(0, 0), Offset(200, 0)]), {
        0: AxisDirection.up,
        1: AxisDirection.up,
      });
    });

    test('move below when a star sits just above', () {
      // Star 0 lies right where star 1's top tab would go.
      final result = sides(const [Offset(100, 40), Offset(100, 100)]);
      expect(result[1], AxisDirection.down);
      expect(result[0], AxisDirection.up);
    });

    test('take a side when stars sit above and below', () {
      final result = sides(const [
        Offset(100, 40),
        Offset(100, 100),
        Offset(100, 160),
      ]);
      expect(result[1], AxisDirection.left);
    });

    test('never overlap a tab placed before them', () {
      final centers = const [Offset(100, 100), Offset(130, 100)];
      final result = sides(centers);
      final rects = [
        for (var i = 0; i < 2; i++)
          starTabRect(centers[i], 20, result[i]!, across: 30, out: 24),
      ];
      final overlap = rects[0].intersect(rects[1]);
      expect(overlap.width <= 0 || overlap.height <= 0, isTrue);
    });
  });

  test('a growing card redistributes only its own side column', () {
    LabelLayout layout(double extra) => layoutNumberedSideColumns(
      constellationBounds: const Rect.fromLTWH(300, 100, 400, 300),
      cardSizes: [
        Size(180, 100 + extra),
        ...List.filled(7, const Size(180, 100)),
      ],
      scale: 1,
      maxColumnHeight: 230,
    );
    final closed = layout(0);
    final open = layout(40);

    expect(
      open.placements[0]!.rect.top,
      closeTo(closed.placements[0]!.rect.top - 20, 0.01),
    );
    expect(
      open.placements[2]!.rect.top,
      closeTo(closed.placements[2]!.rect.top + 20, 0.01),
    );
    for (final id in [1, 3, 4, 5, 6, 7]) {
      expect(open.placements[id]!.rect, closed.placements[id]!.rect);
    }
  });
}
