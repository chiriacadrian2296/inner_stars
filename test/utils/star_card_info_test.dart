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

  List<List<BadgeSlot>> slots(List<List<CardBadge>> rows) => [
    for (final row in rows) [for (final badge in row) badge.slot],
  ];

  group('victory', () {
    test('always has the same five badges, zeros when empty', () {
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
      expect(bare.single.map((b) => b.value), ['4', '0', '0', '0', '0']);
      expect(full.single.map((b) => b.value), ['4', '2', '1', '1', '1']);
      // A zero mutes the value, never the icon.
      expect(bare.single[1].valueColor, colors.muted);
      expect(full.single[1].valueColor, colors.text);
      expect(bare.single[1].iconColor, colors.gold);
      expect(full.single[1].iconColor, colors.gold);
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
        expect(dated.single.single.iconColor, colors.gold);
        expect(undated.single.single.iconColor, colors.starUnlit);
        expect(undated.single.single.value, '—');
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
      expect(rows.single.single.value, '—');
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

    test('always has streak, intensity and progress', () {
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
      ).single.last;
      expect(before.value, '1/3');
      expect(before.iconColor, colors.starUnlit);

      final after = habitCardBadges(
        weekly,
        counts([DateTime(2026, 1, 12), today]),
        colors,
        strings,
        now: today,
      ).single.last;
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
      ).single.last.value!;
      expect(progress(habit(target: 3), [today]), '1/3');
      expect(progress(habit(), []), '0/1');
      expect(progress(habit(), [today]), '1/1');
    });

    test('a dead habit has a 0 streak and a dash for progress', () {
      final row = habitCardBadges(
        habit(dead: true),
        {},
        colors,
        strings,
        now: today,
      ).single;
      expect(row.first.value, '0');
      expect(row.last.value, '—');
    });
  });

  group('constellation and area', () {
    test('a constellation has the same eight badges whatever it holds', () {
      List<List<CardBadge>> build({required bool full}) => projectCardBadges(
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
      // Empty: zeros and a dash, muted; nothing is dropped.
      final empty = build(full: false).expand((row) => row).toList();
      expect(empty.length, 8);
      expect(empty.every((b) => b.valueColor == colors.muted), isTrue);
    });

    test('an area has the same seven badges, vision is a check or a cross', () {
      List<List<CardBadge>> build({required bool vision}) => areaCardBadges(
        constellationCount: 2,
        stars: [victory(), goal()],
        habits: const [],
        countsByHabit: const {},
        reflectionsAnswered: 0,
        hasVision: vision,
        moodboardCount: 0,
        colors: colors,
        strings: strings,
        now: today,
      );
      expect(slots(build(vision: true)), kBadgeRows[BadgeCardKind.area]);
      expect(slots(build(vision: false)), kBadgeRows[BadgeCardKind.area]);
      CardBadge visionOf(List<List<CardBadge>> rows) =>
          rows.expand((r) => r).firstWhere((b) => b.slot == BadgeSlot.vision);
      expect(visionOf(build(vision: true)).check, isTrue);
      expect(visionOf(build(vision: false)).check, isFalse);
      expect(visionOf(build(vision: false)).value, isNull);
    });
  });

  test(
    'every grid of the schema fits the reference width, 5 columns at most',
    () {
      for (final rows in kBadgeRows.values) {
        expect(rows.length, lessThanOrEqualTo(2));
        for (final row in rows) {
          expect(row.length, lessThanOrEqualTo(5));
        }
        expect(badgeGridWidth(rows), lessThanOrEqualTo(kBadgeReferenceWidth));
      }
    },
  );

  test('the columns of a two-row card are as wide as their widest cell', () {
    final widths = badgeColumnWidths(kBadgeRows[BadgeCardKind.constellation]!);
    expect(widths.length, 4);
    for (var c = 0; c < widths.length; c++) {
      for (final row in kBadgeRows[BadgeCardKind.constellation]!) {
        expect(row[c].width, lessThanOrEqualTo(widths[c]));
      }
    }
  });
}
