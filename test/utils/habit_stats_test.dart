import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/utils/habit_stats.dart';

Habit habit({
  HabitFrequency frequency = HabitFrequency.daily,
  int target = 1,
  DateTime? createdAt,
  bool dead = false,
  DateTime? deadDate,
}) => Habit(
  id: 1,
  projectId: 1,
  title: 'Read',
  createdAt: createdAt ?? DateTime(2026, 1, 1),
  frequency: frequency,
  targetPerPeriod: target,
  dead: dead,
  deadDate: deadDate,
);

List<HabitCompletion> logs(Map<DateTime, int> values) {
  var id = 0;
  return [
    for (final entry in values.entries)
      for (var i = 0; i < entry.value; i++)
        HabitCompletion(id: ++id, habitId: 1, date: entry.key),
  ];
}

void main() {
  group('daily habit statistics', () {
    test('computes current and longest streak independently', () {
      final dates = logs({
        DateTime(2026, 1, 1): 1,
        DateTime(2026, 1, 2): 1,
        DateTime(2026, 1, 3): 1,
        DateTime(2026, 1, 5): 1,
        DateTime(2026, 1, 6): 1,
      });
      final summary = habitStatsSummary(
        habit(),
        dates,
        now: DateTime(2026, 1, 6),
        range: HabitStatsRange.days7,
      );

      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 3);
    });

    test('requires the full daily target and caps over-completion', () {
      final summary = habitStatsSummary(
        habit(target: 2, createdAt: DateTime(2026, 1, 8)),
        logs({
          DateTime(2026, 1, 8): 1,
          DateTime(2026, 1, 9): 2,
          DateTime(2026, 1, 10): 4,
        }),
        now: DateTime(2026, 1, 10),
        range: HabitStatsRange.days7,
      );

      expect(summary.completionRate, closeTo(2 / 3, .0001));
      expect(summary.totalCompletions, 7);
      expect(summary.progressByDay[DateTime(2026, 1, 8)], .5);
      expect(summary.progressByDay[DateTime(2026, 1, 10)], 1);
    });

    test('clamps the range to creation and death dates', () {
      final summary = habitStatsSummary(
        habit(
          createdAt: DateTime(2026, 1, 8),
          dead: true,
          deadDate: DateTime(2026, 1, 10),
        ),
        logs({
          DateTime(2026, 1, 7): 1,
          DateTime(2026, 1, 8): 1,
          DateTime(2026, 1, 11): 1,
        }),
        now: DateTime(2026, 1, 15),
      );

      expect(summary.trend.map((point) => point.date), [
        DateTime(2026, 1, 8),
        DateTime(2026, 1, 9),
        DateTime(2026, 1, 10),
      ]);
      expect(summary.totalCompletions, 1);
      expect(summary.currentStreak, 0);
    });
  });

  group('weekly habit statistics', () {
    test('uses completed weeks for streaks', () {
      final weekly = habit(frequency: HabitFrequency.weekly, target: 2);
      final values = logs({
        DateTime(2026, 1, 5): 1,
        DateTime(2026, 1, 7): 1,
        DateTime(2026, 1, 12): 1,
        DateTime(2026, 1, 15): 1,
      });
      final summary = habitStatsSummary(
        weekly,
        values,
        now: DateTime(2026, 1, 16),
        range: HabitStatsRange.days30,
      );

      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 2);
    });

    test('current partial week only expects opportunities elapsed so far', () {
      final weekly = habit(
        frequency: HabitFrequency.weekly,
        target: 3,
        createdAt: DateTime(2026, 1, 5),
      );
      final summary = habitStatsSummary(
        weekly,
        logs({DateTime(2026, 1, 5): 1}),
        now: DateTime(2026, 1, 6),
        range: HabitStatsRange.days7,
      );

      expect(summary.completionRate, .5);
    });
  });

  test('weekday insights wait for a full week and identify both extremes', () {
    final tooNew = habitStatsSummary(
      habit(createdAt: DateTime(2026, 1, 5)),
      const [],
      now: DateTime(2026, 1, 9),
    );
    expect(tooNew.bestWeekday, isNull);

    final enough = habitStatsSummary(
      habit(createdAt: DateTime(2026, 1, 5)),
      logs({DateTime(2026, 1, 7): 1}),
      now: DateTime(2026, 1, 11),
    );
    expect(enough.bestWeekday?.weekday, DateTime.wednesday);
    expect(enough.weakestWeekday?.rate, 0);
  });
}
