import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/utils/badge_schema.dart';
import 'package:inner_stars/utils/habit_stats.dart';
import 'package:inner_stars/utils/project_card_info.dart';
import 'package:inner_stars/utils/star_card_info.dart';

void main() {
  const colors = AppColors.dark;
  const strings = StringsIt();
  final created = DateTime(2026, 1, 1);
  final today = DateTime(2026, 1, 14); // a Wednesday

  StarMedia media(StarMediaKind kind, String id) => StarMedia(
    id: id,
    kind: kind,
    path: kind == StarMediaKind.link ? null : 'file-$id',
    url: kind == StarMediaKind.link ? 'https://example.com' : null,
    createdAt: created,
  );

  Star victory({int intensity = 4, List<StarMedia> extras = const []}) => Star(
    id: 1,
    projectId: 1,
    slotSequence: 1,
    title: 'Run',
    createdAt: created,
    achievedDate: DateTime(2026, 1, 5),
    intensity: intensity,
    media: extras,
  );
  Star goal({DateTime? date}) => Star(
    id: 2,
    projectId: 1,
    slotSequence: 2,
    title: 'Goal',
    createdAt: created,
    targetDate: date,
  );

  Map<DateTime, int> counts(List<DateTime> days) => habitCompletionCountsByDay([
    for (var i = 0; i < days.length; i++)
      HabitCompletion(id: i + 1, habitId: 1, date: days[i]),
  ]);

  List<List<BadgeSlot>> slots(CardBadges badges) => [
    for (final row in badges.rows) [for (final badge in row) badge.slot],
  ];

  group('victory', () {
    test('always has the same four attachments, zeros when empty', () {
      final bare = starCardBadges(victory(), colors, strings);
      final full = starCardBadges(
        victory(
          extras: [
            media(StarMediaKind.voice, 'a'),
            media(StarMediaKind.voice, 'b'),
            media(StarMediaKind.photo, 'c'),
            media(StarMediaKind.video, 'd'),
            media(StarMediaKind.link, 'e'),
          ],
        ),
        colors,
        strings,
      );
      expect(slots(bare), kBadgeRows[BadgeCardKind.victory]);
      expect(slots(full), kBadgeRows[BadgeCardKind.victory]);
      expect(bare.rows.single.map((b) => b.value), ['0', '0', '0', '0']);
      expect(full.rows.single.map((b) => b.value), ['2', '1', '1', '1']);
      // A zero mutes the value, never the icon.
      expect(bare.rows.single[0].valueColor, colors.muted);
      expect(full.rows.single[0].valueColor, colors.text);
      expect(bare.rows.single[0].iconColor, colors.gold);
      expect(full.rows.single[0].iconColor, colors.gold);
    });

    test('the intensity is apart from the row, above the first text', () {
      final badges = starCardBadges(victory(), colors, strings);
      expect(badges.intensity!.slot, BadgeSlot.intensity);
      expect(badges.intensity!.value, '4');
    });
  });

  group('goal and dead star', () {
    test(
      'a goal is one date badge, gold with a date, blue and a dash without',
      () {
        final dated = starCardBadges(
          goal(date: DateTime(2026, 5, 1)),
          colors,
          strings,
        );
        final undated = starCardBadges(goal(), colors, strings);
        expect(slots(dated), kBadgeRows[BadgeCardKind.goal]);
        expect(slots(undated), kBadgeRows[BadgeCardKind.goal]);
        expect(dated.intensity, isNull);
        expect(dated.rows.single.single.iconColor, colors.gold);
        expect(undated.rows.single.single.iconColor, colors.starUnlit);
        expect(undated.rows.single.single.value, '—');
      },
    );

    test('a dead star is one date badge', () {
      final dead = Star(
        id: 3,
        projectId: 1,
        slotSequence: 3,
        title: 'Gone',
        createdAt: created,
        dead: true,
      );
      final rows = starCardBadges(dead, colors, strings);
      expect(slots(rows), kBadgeRows[BadgeCardKind.deadStar]);
      expect(rows.intensity, isNull);
      expect(rows.rows.single.single.value, '—');
    });
  });

  group('habit', () {
    Habit habit({
      HabitFrequency frequency = HabitFrequency.daily,
      int target = 1,
      bool dead = false,
    }) => Habit(
      id: 1,
      projectId: 1,
      title: 'Swim',
      createdAt: created,
      frequency: frequency,
      targetPerPeriod: target,
      dead: dead,
    );

    test('always has progress and streak, and the intensity apart', () {
      for (final h in [
        habit(),
        habit(target: 3),
        habit(frequency: HabitFrequency.weekly, target: 3),
        habit(dead: true),
      ]) {
        final rows = habitCardBadges(
          h,
          counts([today]),
          colors,
          strings,
          now: today,
        );
        expect(slots(rows), kBadgeRows[BadgeCardKind.habit]);
        expect(rows.intensity, isNotNull);
      }
    });

    test('a weekly habit shows the week count, gold once today is marked', () {
      final weekly = habit(frequency: HabitFrequency.weekly, target: 3);
      final before = habitCardBadges(
        weekly,
        counts([DateTime(2026, 1, 12)]),
        colors,
        strings,
        now: today,
      ).rows.single.first;
      expect(before.value, '1/3');
      expect(before.iconColor, colors.starUnlit);

      final after = habitCardBadges(
        weekly,
        counts([DateTime(2026, 1, 12), today]),
        colors,
        strings,
        now: today,
      ).rows.single.first;
      expect(after.value, '2/3');
      expect(after.iconColor, colors.gold);
    });

    test('a daily habit shows today\'s repetitions, plain ones 0/1 or 1/1', () {
      String progress(Habit h, List<DateTime> days) => habitCardBadges(
        h,
        counts(days),
        colors,
        strings,
        now: today,
      ).rows.single.first.value;
      expect(progress(habit(target: 3), [today]), '1/3');
      expect(progress(habit(), []), '0/1');
      expect(progress(habit(), [today]), '1/1');
    });

    test('a dead habit has a dash for progress and a 0 streak', () {
      final row = habitCardBadges(
        habit(dead: true),
        {},
        colors,
        strings,
        now: today,
      ).rows.single;
      expect(row.first.value, '—');
      expect(row.last.value, '0');
    });
  });

  group('constellation and area', () {
    test('a constellation has the same five badges whatever it holds', () {
      CardBadges build({required bool full}) => projectCardBadges(
        stars: full ? [victory(), goal(date: DateTime(2026, 2, 1))] : const [],
        habits: const [],
        countsByHabit: const {},
        slotCount: full ? 8 : 0,
        colors: colors,
        strings: strings,
        now: today,
      );
      expect(
        slots(build(full: false)),
        kBadgeRows[BadgeCardKind.constellation],
      );
      expect(slots(build(full: true)), kBadgeRows[BadgeCardKind.constellation]);
      // Empty: zeros, muted; nothing is dropped.
      final empty = build(full: false);
      expect(empty.rows.single.length, 5);
      expect(empty.rows.length, 1);
      expect(
        empty.rows.single.every((b) => b.valueColor == colors.muted),
        isTrue,
      );
      expect(empty.intensity!.value, '0');
      // The intensity is the total of its lit stars.
      expect(build(full: true).intensity!.value, '4');
    });

    test('an area has one row of six counts and the total intensity', () {
      CardBadges build({required bool full}) => areaCardBadges(
        constellationCount: full ? 2 : 0,
        stars: full ? [victory(), victory(intensity: 3), goal()] : const [],
        habits: const [],
        emptySlots: full ? 5 : 0,
        colors: colors,
        strings: strings,
      );
      expect(slots(build(full: true)), kBadgeRows[BadgeCardKind.area]);
      expect(slots(build(full: false)), kBadgeRows[BadgeCardKind.area]);
      final full = build(full: true);
      expect(full.intensity!.value, '7');
      // constellations, lit stars, habits, goals, empty slots, dead stars.
      expect(full.rows.single.map((b) => b.value), [
        '2',
        '2',
        '0',
        '1',
        '5',
        '0',
      ]);
    });
  });

  test(
    'every grid of the schema fits the reference width, one row at most',
    () {
      for (final rows in kBadgeRows.values) {
        expect(rows.length, 1);
        expect(rows.single.length, lessThanOrEqualTo(6));
        expect(badgeGridWidth(rows), lessThanOrEqualTo(kBadgeReferenceWidth));
      }
    },
  );

  test('a row is as wide as the sum of its cells', () {
    for (final rows in kBadgeRows.values) {
      final widths = badgeColumnWidths(rows);
      expect(widths, [for (final slot in rows.single) slot.width]);
    }
  });
}
