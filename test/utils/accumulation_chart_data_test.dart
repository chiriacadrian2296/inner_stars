import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/utils/accumulation_chart_data.dart';
import 'package:inner_stars/utils/celebration_stats.dart';

void main() {
  test('rounded steps cover small and large totals', () {
    expect([0, 1, 7, 24, 123, 10001].map(accumulationTickStep), [
      1,
      1,
      2,
      10,
      50,
      5000,
    ]);
  });
  test('exact lookup retains totals in gaps and clamps to the date range', () {
    final points = [
      CelebrationPoint(DateTime(2026, 10, 1), 0),
      CelebrationPoint(DateTime(2026, 10, 2), 3),
      CelebrationPoint(DateTime(2026, 10, 10), 9),
    ];
    expect(accumulationAtDay(points, chartDay(DateTime(2026, 10, 6))).total, 3);
    expect(
      accumulationAtDay(points, chartDay(DateTime(2026, 10, 10))).total,
      9,
    );
    expect(accumulationAtDay(points, chartDay(DateTime(2026, 9, 1))).total, 0);
    expect(
      accumulationAtDay(points, chartDay(DateTime(2026, 11, 1))).date,
      DateTime(2026, 10, 10),
    );
    final curve = accumulationCurvePoints(points);
    expect(curve.map((point) => point.total), [0, 3, 9]);
  });
  test('calendar ticks cover short ranges, month starts and rounded years', () {
    final weeks = accumulationDateTicks(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
      5,
    );
    expect(weeks.length, greaterThan(1));
    expect(weeks.length, greaterThanOrEqualTo(6));
    final days = accumulationDateTicks(
      DateTime(2026, 10, 4),
      DateTime(2026, 10, 11),
      2,
    );
    expect(days.map((date) => date.day), [5, 6, 7, 8, 9, 10, 11]);
    final months = accumulationDateTicks(
      DateTime(2026, 1, 1),
      DateTime(2026, 12, 31),
      5,
    );
    expect(months.every((date) => date.day == 1), isTrue);
    final years = accumulationDateTicks(
      DateTime(2010, 1, 1),
      DateTime(2026, 12, 31),
      5,
    );
    expect(
      years.every(
        (date) => date.year % 5 == 0 && date.month == 1 && date.day == 1,
      ),
      isTrue,
    );
  });
  test(
    'shared tangents keep long-range curves monotone and preserve plateaus',
    () {
      final points = [
        CelebrationPoint(DateTime(2025, 1, 1), 0),
        CelebrationPoint(DateTime(2025, 1, 2), 20),
        CelebrationPoint(DateTime(2025, 6, 1), 25),
        CelebrationPoint(DateTime(2025, 6, 2), 300),
        CelebrationPoint(DateTime(2025, 7, 1), 300),
        CelebrationPoint(DateTime(2026, 1, 1), 500),
      ];
      final tangents = accumulationTangents(points);
      var previous = 0.0;
      for (
        var day = chartDay(points.first.date);
        day <= chartDay(points.last.date);
        day++
      ) {
        final value = accumulationCurveValue(points, tangents, day);
        expect(value, greaterThanOrEqualTo(previous - 1e-9));
        expect(value, lessThanOrEqualTo(500));
        previous = value;
      }
      expect(
        accumulationCurveValue(
          points,
          tangents,
          chartDay(DateTime(2025, 6, 15)),
        ),
        300,
      );
      for (final point in points) {
        expect(
          accumulationCurveValue(points, tangents, chartDay(point.date)),
          closeTo(point.total, 1e-9),
        );
      }
    },
  );
}
