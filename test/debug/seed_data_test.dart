import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/debug/seed_data.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/utils/date_math.dart';
import 'package:inner_stars/utils/habit_stats.dart';
import 'package:inner_stars/utils/star_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('seed gives the Statistics page history to work with, once', () async {
    SharedPreferences.setMockInitialValues({});
    final stars = await StarRepository.create();
    final projects = await ProjectRepository.create();
    final habits = await HabitRepository.create();
    final completions = await HabitCompletionRepository.create();

    Future<void> seed() => seedSampleData(
      starRepository: stars,
      projectRepository: projects,
      habitRepository: habits,
      habitCompletionRepository: completions,
      languageCode: 'en',
    );

    await seed();
    final today = dateOnly(DateTime.now());
    final lit = stars.getAll().where((s) => s.isLit).toList();

    // Months of history, not just the last 30 days.
    final oldest = lit
        .map((s) => dateOnly(s.achievedDate!))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    expect(dayDiff(oldest, today), greaterThan(120));

    // The old 14-day streak beats the live one.
    final counts = starCountsByDay(lit);
    expect(longestStreak(counts), greaterThanOrEqualTo(14));
    expect(currentStreak(counts), lessThan(longestStreak(counts)));

    // Uneven areas.
    final byArea = starCountsByArea(lit, {
      for (final p in projects.getAll()) p.id: p,
    });
    expect(byArea.length, greaterThan(4));
    expect(byArea.first.value, greaterThan(byArea.last.value * 3));

    // Habit variety: weekly, multi-per-day, dead, brand new, unlit.
    final all = habits.getAll();
    expect(all.any((h) => h.frequency == HabitFrequency.weekly), isTrue);
    expect(all.any((h) => h.targetPerPeriod > 1), isTrue);
    expect(all.any((h) => h.dead), isTrue);
    final journaling = all.firstWhere((h) => h.title == 'Journaling');
    expect(
      isHabitLit(
        journaling,
        habitCompletionCountsByDay(completions.getAllForHabit(journaling.id)),
      ),
      isFalse,
    );
    final evening = all.firstWhere((h) => h.title == 'Evening walk');
    final summary = habitStatsSummary(
      evening,
      completions.getAllForHabit(evening.id),
      range: HabitStatsRange.days90,
    );
    expect(summary.trend.length, 90);
    expect(summary.bestWeekday, isNotNull);

    // Second run adds more recent wins but no second copy of the history
    // or of the history habits.
    final starCount = stars.getAll().length;
    final habitCount = habits.getAll().length;
    await seed();
    expect(habits.getAll().length, habitCount);
    expect(
      stars.getAll().length - starCount,
      projects.getAll().length * winsPerSeedTap,
    );
  });
}
