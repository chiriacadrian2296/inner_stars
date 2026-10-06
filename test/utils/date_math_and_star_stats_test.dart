import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/utils/date_math.dart';
import 'package:inner_stars/utils/habit_stats.dart';
import 'package:inner_stars/utils/habit_stats_snapshot.dart';
import 'package:inner_stars/utils/star_stats.dart';

void main() {
  group('date_math', () {
    test('addDays always lands on midnight, across both DST changes', () {
      for (final start in [DateTime(2026, 3, 27), DateTime(2026, 10, 24)]) {
        for (var n = -10; n <= 10; n++) {
          final d = addDays(start, n);
          expect(d.hour, 0);
          expect(d.minute, 0);
        }
      }
      expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
      expect(addDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
    });

    test('dayDiff counts calendar days across DST', () {
      expect(dayDiff(DateTime(2026, 3, 28), DateTime(2026, 3, 29)), 1);
      expect(dayDiff(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
      expect(dayDiff(DateTime(2026, 10, 24), DateTime(2026, 10, 25)), 1);
      expect(dayDiff(DateTime(2026, 10, 25), DateTime(2026, 10, 24)), -1);
      expect(dayDiff(DateTime(2026, 3, 1), DateTime(2026, 11, 1)), 245);
    });
  });

  group('star_stats streaks across DST', () {
    test('current streak spans the spring clock change', () {
      final counts = {
        for (final d in [28, 29, 30, 31]) DateTime(2026, 3, d): 1,
      };
      final range = currentStreakRange(counts, today: DateTime(2026, 3, 31));
      expect(range.length, 4);
      expect(range.start, DateTime(2026, 3, 28));
    });

    test('longest streak spans the autumn clock change', () {
      final counts = {
        for (final d in [24, 25, 26]) DateTime(2026, 10, d): 1,
        DateTime(2026, 10, 29): 1,
      };
      expect(longestStreak(counts), 3);
    });
  });

  group('HabitStatsSnapshot', () {
    test('lists unlit habits first and averages the rate', () {
      final now = DateTime(2026, 5, 20, 12);
      final lit = Habit(
        id: 1,
        title: 'a',
        projectId: 1,
        createdAt: DateTime(2026, 5, 10),
      );
      final dark = Habit(
        id: 2,
        title: 'b',
        projectId: 1,
        createdAt: DateTime(2026, 5, 10),
      );
      final snapshot = HabitStatsSnapshot.build(
        habits: [lit, dark],
        allCompletions: [
          for (final d in [18, 19, 20])
            HabitCompletion(id: d, habitId: 1, date: DateTime(2026, 5, d)),
        ],
        range: HabitStatsRange.days7,
        now: now,
      );
      expect(snapshot.entries.first.habit.id, 2);
      expect(snapshot.onTrackCount, 1);
      expect(snapshot.overallRate, greaterThan(0));
    });
  });

  group('StarFilter', () {
    final projects = {
      1: Project(
        id: 1,
        name: 'gym',
        area: LifeArea.physical,
        iconSlug: 'x',
        createdAt: DateTime(2026, 1, 1),
      ),
      2: Project(
        id: 2,
        name: 'work',
        area: LifeArea.professional,
        iconSlug: 'x',
        createdAt: DateTime(2026, 1, 1),
      ),
    };
    Star star(int id, int projectId, DateTime day) => Star(
      id: id,
      projectId: projectId,
      slotSequence: id,
      title: 't$id',
      createdAt: day,
      achievedDate: day,
      intensity: 2,
    );
    final stars = [
      star(1, 1, DateTime(2026, 5, 1, 23, 30)),
      star(2, 2, DateTime(2026, 5, 10)),
      star(3, 2, DateTime(2026, 5, 12)),
      star(4, 99, DateTime(2026, 5, 12)),
    ];

    test('default filter keeps everything, even orphaned stars', () {
      final filter = StarFilter.all();
      expect(filter.isActive, isFalse);
      expect(stars.where((s) => filter.matches(s, projects)).length, 4);
    });

    test('area filter drops other areas and orphans', () {
      final filter = StarFilter.all().copyWith(areas: {LifeArea.professional});
      final ids = stars
          .where((s) => filter.matches(s, projects))
          .map((s) => s.id);
      expect(ids, [2, 3]);
    });

    test('date range is inclusive of the whole end day', () {
      final filter = StarFilter.all().copyWith(
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 10),
      );
      final ids = stars
          .where((s) => filter.matches(s, projects))
          .map((s) => s.id);
      expect(ids, [1, 2]);
    });

    test('starCountsByArea sorts largest first and skips orphans', () {
      final counts = starCountsByArea(stars, projects);
      expect(counts.map((e) => e.key), [
        LifeArea.professional,
        LifeArea.physical,
      ]);
      expect(counts.first.value, 2);
    });
  });
}
