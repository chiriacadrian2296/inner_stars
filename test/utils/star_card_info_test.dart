import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/utils/habit_stats.dart';
import 'package:inner_stars/utils/star_card_info.dart';

void main() {
  const colors = AppColors.dark;
  const strings = StringsIt();
  final created = DateTime(2026, 1, 1);

  StarMedia media(StarMediaKind kind, String id) => StarMedia(
    id: id,
    kind: kind,
    path: kind == StarMediaKind.link ? null : 'file-$id',
    url: kind == StarMediaKind.link ? 'https://example.com' : null,
    createdAt: created,
  );

  group('starCardBadges', () {
    test('a victory lists intensity and every attachment count', () {
      final star = Star(
        id: 1,
        projectId: 1,
        slotSequence: 1,
        title: 'Run',
        description: 'A long run',
        createdAt: created,
        achievedDate: created,
        intensity: 4,
        media: [
          media(StarMediaKind.voice, 'a'),
          media(StarMediaKind.voice, 'b'),
          media(StarMediaKind.photo, 'c'),
          media(StarMediaKind.link, 'd'),
        ],
      );
      final badges = starCardBadges(star, colors, strings);
      expect(badges.map((b) => b.value), ['4', '2', '1', '1']);
      // The count shows even when it is 1.
      expect(badges.last.value, '1');
      // Essentials first; attachments are secondary.
      expect(badges.first.secondary, isFalse);
      expect(badges.skip(1).every((b) => b.secondary), isTrue);
    });

    test('a goal shows its date icon gold with a date, blue without', () {
      Star goal({DateTime? date}) => Star(
        id: 2,
        projectId: 1,
        slotSequence: 2,
        title: 'Goal',
        createdAt: created,
        targetDate: date,
      );
      expect(
        starCardBadges(goal(), colors, strings).first.iconColor,
        colors.starUnlit,
      );
      expect(
        starCardBadges(
          goal(date: DateTime(2026, 5, 1)),
          colors,
          strings,
        ).first.iconColor,
        colors.gold,
      );
      // A goal never lists attachments.
      expect(starCardBadges(goal(), colors, strings).length, 1);
    });
  });

  group('habitCardBadges', () {
    final today = DateTime(2026, 1, 14); // a Wednesday
    Map<DateTime, int> counts(List<DateTime> days) =>
        habitCompletionCountsByDay([
          for (var i = 0; i < days.length; i++)
            HabitCompletion(id: i + 1, habitId: 1, date: days[i]),
        ]);

    test(
      'a weekly habit shows the week count, gold only once today is marked',
      () {
        final habit = Habit(
          id: 1,
          projectId: 1,
          title: 'Swim',
          createdAt: created,
          frequency: HabitFrequency.weekly,
          targetPerPeriod: 3,
        );
        var badges = habitCardBadges(
          habit,
          counts([DateTime(2026, 1, 12)]),
          colors,
          strings,
          now: today,
        );
        final before = badges.firstWhere((b) => b.value == '1/3');
        expect(before.iconColor, colors.starUnlit);

        badges = habitCardBadges(
          habit,
          counts([DateTime(2026, 1, 12), today]),
          colors,
          strings,
          now: today,
        );
        final after = badges.firstWhere((b) => b.value == '2/3');
        expect(after.iconColor, colors.gold);
      },
    );

    test('a counting daily habit shows today\'s repetitions', () {
      final habit = Habit(
        id: 1,
        projectId: 1,
        title: 'Water',
        createdAt: created,
        targetPerPeriod: 3,
      );
      final badges = habitCardBadges(
        habit,
        counts([today]),
        colors,
        strings,
        now: today,
      );
      expect(badges.any((b) => b.value == '1/3'), isTrue);
    });

    test('a plain daily habit shows no progress, a dead one no streak', () {
      final plain = Habit(
        id: 1,
        projectId: 1,
        title: 'Read',
        createdAt: created,
      );
      final badges = habitCardBadges(plain, {}, colors, strings, now: today);
      expect(badges.map((b) => b.value), ['0', '3']);

      final dead = Habit(
        id: 1,
        projectId: 1,
        title: 'Read',
        description: 'Old',
        createdAt: created,
        dead: true,
      );
      final deadBadges = habitCardBadges(dead, {}, colors, strings, now: today);
      expect(deadBadges.map((b) => b.value), ['3']);
    });
  });
}
