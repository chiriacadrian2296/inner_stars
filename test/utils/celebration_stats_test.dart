import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/utils/celebration_stats.dart';

void main() {
  test(
    'counts completed actions, archived habits and repeated instances only',
    () {
      final now = DateTime(2026, 10, 11);
      Star star(int id, DateTime? date, {bool dead = false}) => Star(
        id: id,
        projectId: 1,
        slotSequence: id,
        title: 'Test',
        createdAt: now,
        achievedDate: date,
        intensity: date == null ? null : 3,
        dead: dead,
      );
      final stats = CelebrationStats(
        now: now,
        days: 7,
        stars: [
          star(1, DateTime(2026, 10, 5)),
          star(2, DateTime(2026, 10, 4)),
          star(3, null),
          star(4, now, dead: true),
          star(5, DateTime(2026, 10, 12)),
        ],
        habits: [
          Habit(
            id: 1,
            projectId: 2,
            title: 'Past habit',
            createdAt: now,
            dead: true,
          ),
        ],
        completions: [
          HabitCompletion(id: 1, habitId: 1, date: now),
          HabitCompletion(id: 2, habitId: 1, date: now),
          HabitCompletion(id: 3, habitId: 999, date: now),
        ],
      );
      expect(stats.starsCount, 1);
      expect(stats.gesturesCount, 2);
      expect(stats.total, 3);
      expect(stats.projectsCount, 2);
      expect(stats.cumulative.map((point) => point.total), [0, 1, 3]);
      expect(stats.cumulative.first.date, DateTime(2026, 10, 4));
      expect(stats.cumulative.last.date, now);
    },
  );
  test('accumulation retains empty-day plateaus and ends at today', () {
    final now = DateTime(2026, 10, 11);
    final habit = Habit(id: 1, projectId: 1, title: 'Habit', createdAt: now);
    final stats = CelebrationStats(
      stars: [],
      habits: [habit],
      now: now,
      completions: [
        HabitCompletion(id: 1, habitId: 1, date: DateTime(2025, 12, 31)),
        HabitCompletion(id: 2, habitId: 1, date: DateTime(2026, 10, 2)),
      ],
    );
    expect(stats.cumulative.map((point) => point.total), [0, 1, 2, 2]);
    expect(stats.cumulative.first.date, DateTime(2025, 12, 30));
    expect(stats.cumulative.last.date, now);
    final empty = CelebrationStats(
      stars: [],
      habits: [],
      completions: [],
      now: now,
      days: 7,
    );
    expect(empty.cumulative.map((point) => point.total), [0, 0]);
  });
}
