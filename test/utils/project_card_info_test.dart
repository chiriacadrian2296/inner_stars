import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/utils/habit_stats.dart';
import 'package:inner_stars/utils/project_card_info.dart';

void main() {
  const colors = AppColors.dark;
  const strings = StringsIt();
  final today = DateTime(2026, 1, 14); // a Wednesday
  final created = DateTime(2026, 1, 1);

  Star lit(int id, {int intensity = 3, String? photo, DateTime? on}) => Star(
    id: id,
    projectId: 1,
    slotSequence: id,
    title: 'Win $id',
    createdAt: created,
    achievedDate: on ?? DateTime(2026, 1, 5),
    intensity: intensity,
    photoPath: photo,
    media: [
      StarMedia(
        id: 'm$id',
        kind: StarMediaKind.voice,
        path: 'f$id',
        createdAt: created,
      ),
    ],
  );
  Star goal(int id, {DateTime? date}) => Star(
    id: id,
    projectId: 1,
    slotSequence: id,
    title: 'Goal $id',
    createdAt: created,
    targetDate: date,
  );

  Habit habit(int id, {bool dead = false}) => Habit(
    id: id,
    projectId: 1,
    title: 'Habit $id',
    createdAt: created,
    dead: dead,
  );

  Map<int, Map<DateTime, int>> counts(Map<int, List<DateTime>> byHabit) => {
    for (final entry in byHabit.entries)
      entry.key: habitCompletionCountsByDay([
        for (var i = 0; i < entry.value.length; i++)
          HabitCompletion(id: i + 1, habitId: entry.key, date: entry.value[i]),
      ]),
  };

  group('projectCardBadges', () {
    test('lists only the facts that exist', () {
      final badges = projectCardBadges(
        stars: [
          lit(1, intensity: 4, photo: 'p'),
          lit(2, intensity: 2),
          goal(3, date: DateTime(2026, 2, 1)),
          goal(4, date: DateTime(2026, 1, 20)),
          goal(5),
        ],
        habits: [habit(1), habit(2), habit(3, dead: true)],
        countsByHabit: counts({
          1: [today],
        }),
        slotCount: 8,
        colors: colors,
        strings: strings,
        now: today,
      );
      expect(badges.map((b) => b.semanticLabel), [
        strings.cardBadgeLitStars,
        strings.cardBadgeGoals,
        strings.cardBadgeEmptySlots,
        strings.cardBadgePulsarsToday,
        strings.cardBadgeNextDate,
        strings.cardBadgeEnergy,
        strings.cardBadgeMemories,
      ]);
      expect(badges.map((b) => b.value).take(4), ['2/15', '3', '3', '1/2']);
      expect(badges[5].value, '6'); // 4 + 2
      expect(badges[6].value, '3'); // one cover photo + two voice notes
    });

    test('a bare constellation shows just its lit count', () {
      final badges = projectCardBadges(
        stars: const [],
        habits: const [],
        countsByHabit: const {},
        slotCount: 0,
        colors: colors,
        strings: strings,
        now: today,
      );
      expect(badges.length, 1);
      expect(badges.single.value, '0/15');
    });
  });

  group('areaCardBadges', () {
    test('shows a written vision and moodboard only when they exist', () {
      List<String?> labels({required bool vision, required int moodboard}) =>
          areaCardBadges(
            constellationCount: 2,
            stars: [
              lit(1, on: today),
              lit(2),
              goal(3),
            ],
            habits: const [],
            countsByHabit: const {},
            reflectionsAnswered: 4,
            hasVision: vision,
            moodboardCount: moodboard,
            colors: colors,
            strings: strings,
            now: today,
          ).map((b) => b.semanticLabel).toList();

      final bare = labels(vision: false, moodboard: 0);
      expect(bare, isNot(contains(strings.cardBadgeVision)));
      expect(bare, isNot(contains(strings.cardBadgeMoodboard)));
      expect(bare, contains(strings.cardBadgeReflections));

      final full = labels(vision: true, moodboard: 5);
      expect(full, contains(strings.cardBadgeVision));
      expect(full, contains(strings.cardBadgeMoodboard));
    });

    test('counts lit stars out of all, and those lit this month', () {
      final badges = areaCardBadges(
        constellationCount: 1,
        stars: [
          lit(1, on: today),
          lit(2, on: DateTime(2025, 12, 30)),
          goal(3),
        ],
        habits: const [],
        countsByHabit: const {},
        reflectionsAnswered: 0,
        hasVision: false,
        moodboardCount: 0,
        colors: colors,
        strings: strings,
        now: today,
      );
      expect(badges[1].value, '2/3');
      expect(
        badges
            .firstWhere((b) => b.semanticLabel == strings.cardBadgeThisMonth)
            .value,
        '1',
      );
    });
  });
}
