import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_layout.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/debug/seed_data.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/star_media.dart';
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

    Future<int> seed() => seedSampleData(
      starRepository: stars,
      projectRepository: projects,
      habitRepository: habits,
      habitCompletionRepository: completions,
      languageCode: 'en',
    );

    await seed();
    final today = dateOnly(DateTime.now());
    final lit = stars.getAll().where((s) => s.isLit).toList();

    // Most victories have useful placeholder copy for exercising longer
    // reader/card layouts, while a minority still covers the empty state.
    final withDescriptions = lit.where((s) => s.description != null).toList();
    expect(withDescriptions.length, greaterThan(lit.length * .7));
    expect(withDescriptions.length, lessThan(lit.length));

    // Most sample victories exercise photo layouts, while a minority still
    // covers the no-photo state.
    final withPhotos = lit.where((s) => s.photoPath != null).toList();
    expect(withPhotos.length, greaterThan(lit.length * .7));
    expect(withPhotos.length, lessThan(lit.length));
    expect(
      withPhotos.every(
        (s) => s.photoPath!.startsWith('https://picsum.photos/seed/'),
      ),
      isTrue,
    );

    // Only a handful of immediately visible victories demonstrate the
    // secondary-photo gallery.
    final withSecondaryPhotos = lit.where((s) => s.media.isNotEmpty).toList();
    expect(withSecondaryPhotos, isNotEmpty);
    expect(withSecondaryPhotos.length, lessThan(lit.length * .15));
    expect(
      withSecondaryPhotos.every(
        (s) =>
            dayDiff(dateOnly(s.achievedDate!), today) <= 1 &&
            s.media.length == 2 &&
            s.media.every(
              (m) =>
                  m.kind == StarMediaKind.photo &&
                  m.path!.startsWith(
                    'https://picsum.photos/seed/inner-stars-extra-',
                  ),
            ),
      ),
      isTrue,
    );

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
    expect(byArea.first.value, greaterThan(byArea.last.value * 2));

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

    // Constellations come in every density, none past the cap.
    final perProject = [
      for (final p in projects.getAll()) stars.getAllForProject(p.id).length,
    ];
    expect(perProject.every((n) => n <= kMaxConstellationStars), isTrue);
    expect(perProject.where((n) => n == kMaxConstellationStars), isNotEmpty);
    expect(perProject.where((n) => n <= 6), isNotEmpty);
    expect(perProject.where((n) => n > 6 && n < 30), isNotEmpty);
    expect(
      habits.getAll().every(
        (h) =>
            habits.getAllForProject(h.projectId).length <=
            kMaxConstellationPulsars,
      ),
      isTrue,
    );

    // A second run is idempotent: every project is already at its target,
    // and the history habits aren't duplicated.
    final starCount = stars.getAll().length;
    final habitCount = habits.getAll().length;
    expect(await seed(), 0);
    expect(habits.getAll().length, habitCount);
    expect(stars.getAll().length, starCount);
  });
}
