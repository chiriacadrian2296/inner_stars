import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../widgets/star_glyph.dart' show starKindColor;
import 'badge_schema.dart';
import 'date_format.dart';
import 'habit_stats.dart';

/// One small fact on a card (tooltip or grid tile): a fixed [slot], an icon
/// and a value — a text, or a ✓/✗ ([check]). The icon carries the state in
/// its colour (gold / blue); a value of zero is shown muted. Every badge has
/// a value: there are no bare icons.
class CardBadge {
  const CardBadge({
    required this.slot,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    this.value,
    this.check,
    this.semanticLabel,
  }) : assert(
         (value == null) != (check == null),
         'a badge shows either a text value or a check, not both or neither',
       );

  final BadgeSlot slot;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;

  /// The text shown beside the icon.
  final String? value;

  /// A ✓ (true) or ✗ (false) shown instead of a text.
  final bool? check;

  /// What the badge stands for, read out by screen readers.
  final String? semanticLabel;
}

/// A badge whose value is [value] (or, when [check] is set, a ✓/✗). The icon
/// always keeps its own [color]; only the value is muted when it is [zero] —
/// a count that is nothing.
CardBadge makeBadge(
  BadgeSlot slot,
  IconData icon,
  AppColors colors, {
  required Color color,
  String? value,
  bool? check,
  bool zero = false,
  String? label,
}) => CardBadge(
  slot: slot,
  icon: icon,
  iconColor: color,
  valueColor: zero ? colors.muted : colors.text,
  value: value,
  check: check,
  semanticLabel: label,
);

/// The badges for a [star] (a victory, a goal or a dead star), grouped in
/// rows by [kBadgeRows]. A victory always has intensity, voice notes, photos,
/// videos and links — a count of 0 when it has none. Pure model data, no I/O.
List<List<CardBadge>> starCardBadges(
  Star star,
  AppColors colors,
  AppStrings strings,
) {
  switch (star.kind) {
    case StarKind.lit:
      CardBadge attachment(
        BadgeSlot slot,
        StarMediaKind kind,
        IconData icon,
        String label,
      ) {
        final count = star.mediaCount(kind);
        return makeBadge(
          slot,
          icon,
          colors,
          color: colors.gold,
          value: '$count',
          zero: count == 0,
          label: label,
        );
      }

      return [
        [
          makeBadge(
            BadgeSlot.intensity,
            Icons.bolt_rounded,
            colors,
            color: colors.gold,
            value: '${star.intensity ?? 0}',
            label: strings.intensityLabel,
          ),
          attachment(
            BadgeSlot.voice,
            StarMediaKind.voice,
            Icons.mic_none_rounded,
            strings.cardBadgeVoice,
          ),
          attachment(
            BadgeSlot.photo,
            StarMediaKind.photo,
            Icons.photo_library_outlined,
            strings.cardBadgePhotos,
          ),
          attachment(
            BadgeSlot.video,
            StarMediaKind.video,
            Icons.videocam_outlined,
            strings.cardBadgeVideos,
          ),
          attachment(
            BadgeSlot.link,
            StarMediaKind.link,
            Icons.link_rounded,
            strings.cardBadgeLinks,
          ),
        ],
      ];
    case StarKind.unlit:
      final date = star.targetDate;
      return [
        [
          makeBadge(
            BadgeSlot.date,
            Icons.calendar_month_rounded,
            colors,
            // Gold once a date is set, blue while it isn't.
            color: date == null ? colors.starUnlit : colors.gold,
            value: date == null ? '—' : formatDisplayDate(date, strings),
          ),
        ],
      ];
    case StarKind.dead:
      final date = star.deadDate;
      return [
        [
          makeBadge(
            BadgeSlot.date,
            StarKind.dead.icon,
            colors,
            color: starKindColor(StarKind.dead, colors),
            value: date == null ? '—' : formatDisplayDate(date, strings),
          ),
        ],
      ];
    case StarKind.pulsar || StarKind.nascent:
      return const [];
  }
}

/// The badges for a [habit] (a pulsar): streak, intensity and the progress of
/// today (a daily habit) or of this week (a weekly one). [countsByDay] is the
/// habit's completions per day, taken from a cache — never read from storage
/// here. A dead habit keeps the same three, with a 0 streak and no progress.
List<List<CardBadge>> habitCardBadges(
  Habit habit,
  Map<DateTime, int> countsByDay,
  AppColors colors,
  AppStrings strings, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final dead = habit.dead;
  final lit = !dead && isHabitLit(habit, countsByDay, now: today);
  final streak = dead ? 0 : habitCurrentStreak(habit, countsByDay, now: today);

  final CardBadge progress;
  if (dead) {
    progress = makeBadge(
      BadgeSlot.progress,
      Icons.import_export,
      colors,
      color: starKindColor(StarKind.pulsar, colors, lit: false),
      value: '—',
      zero: true,
      label: strings.habitTodayLabel,
    );
  } else if (habit.frequency == HabitFrequency.weekly) {
    final doneToday = countsByDay.containsKey(today);
    progress = makeBadge(
      BadgeSlot.progress,
      Icons.date_range,
      colors,
      color: starKindColor(StarKind.pulsar, colors, lit: doneToday),
      value:
          '${habitWeeklyProgress(habit, countsByDay, now: today)}'
          '/${habit.targetPerPeriod}',
      label: strings.habitThisWeekCaption(doneToday),
    );
  } else {
    final done = habitDailyProgress(habit, countsByDay, now: today);
    progress = makeBadge(
      BadgeSlot.progress,
      Icons.import_export,
      colors,
      color: starKindColor(
        StarKind.pulsar,
        colors,
        lit: done >= habit.targetPerPeriod,
      ),
      value: '$done/${habit.targetPerPeriod}',
      label: strings.habitTodayLabel,
    );
  }

  return [
    [
      makeBadge(
        BadgeSlot.streak,
        Icons.local_fire_department_rounded,
        colors,
        color: starKindColor(StarKind.pulsar, colors, lit: lit),
        value: '$streak',
        label: strings.habitCurrentStreakLabel,
      ),
      makeBadge(
        BadgeSlot.intensity,
        Icons.bolt_rounded,
        colors,
        color: colors.gold,
        value: '${habit.intensity}',
        label: strings.intensityLabel,
      ),
      progress,
    ],
  ];
}
