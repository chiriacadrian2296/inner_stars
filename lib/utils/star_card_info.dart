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
/// and a text value. The icon carries the state in its colour (gold / blue);
/// a value of zero is shown muted. Every badge has a value: there are no bare
/// icons.
class CardBadge {
  const CardBadge({
    required this.slot,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    required this.value,
    this.iconColorEnd,
    this.semanticLabel,
  });

  final BadgeSlot slot;
  final IconData icon;
  final Color iconColor;

  /// When set, the icon is [iconColor] on its left half and this on its
  /// right half.
  final Color? iconColorEnd;
  final Color valueColor;

  /// The text shown beside the icon.
  final String value;

  /// What the badge stands for, read out by screen readers.
  final String? semanticLabel;
}

/// A card's badges: its [intensity] (drawn bigger, above the card's first
/// text) and its [rows] of fixed badges (see [kBadgeRows]).
class CardBadges {
  const CardBadges({this.intensity, this.title, this.rows = const []});

  /// The intensity, or null for a card that has none (a goal, a dead star).
  final CardBadge? intensity;

  /// A badge shown to the right of the card's title (an area's number of
  /// constellations), or null.
  final CardBadge? title;
  final List<List<CardBadge>> rows;

  static const none = CardBadges();
}

/// A badge whose value is [value]. The icon always keeps its own [color];
/// only the value is muted when it is [zero] — a count that is nothing.
CardBadge makeBadge(
  BadgeSlot slot,
  IconData icon,
  AppColors colors, {
  required Color color,
  required String value,
  Color? colorEnd,
  bool zero = false,
  String? label,
}) => CardBadge(
  slot: slot,
  icon: icon,
  iconColor: color,
  iconColorEnd: colorEnd,
  valueColor: zero ? colors.muted : colors.text,
  value: value,
  semanticLabel: label,
);

/// The intensity badge of a card: the gold bolt and the number, muted when
/// the number is 0.
CardBadge intensityBadge(int intensity, AppColors colors, AppStrings strings) =>
    makeBadge(
      BadgeSlot.intensity,
      Icons.bolt_rounded,
      colors,
      color: colors.gold,
      value: '$intensity',
      zero: intensity == 0,
      label: strings.intensityLabel,
    );

/// The badges for a [star] (a victory, a goal or a dead star), grouped in
/// rows by [kBadgeRows]. A victory always has its intensity and voice notes,
/// photos, videos and links — a count of 0 when it has none. Pure model data,
/// no I/O.
CardBadges starCardBadges(Star star, AppColors colors, AppStrings strings) {
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

      return CardBadges(
        intensity: intensityBadge(star.intensity ?? 0, colors, strings),
        rows: [
          [
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
        ],
      );
    case StarKind.unlit:
      final date = star.targetDate;
      return CardBadges(
        rows: [
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
        ],
      );
    case StarKind.dead:
      final date = star.deadDate;
      return CardBadges(
        rows: [
          [
            makeBadge(
              BadgeSlot.date,
              Icons.delete_outline_rounded,
              colors,
              color: starKindColor(StarKind.dead, colors),
              value: date == null ? '—' : formatDisplayDate(date, strings),
            ),
          ],
        ],
      );
    case StarKind.pulsar || StarKind.nascent:
      return CardBadges.none;
  }
}

/// The badges for a [habit] (a pulsar): its intensity, then the progress of
/// today (a daily habit) or of this week (a weekly one) and the streak.
/// [countsByDay] is the habit's completions per day, taken from a cache —
/// never read from storage here. A dead habit keeps the same badges, with no
/// progress and a 0 streak.
CardBadges habitCardBadges(
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

  return CardBadges(
    intensity: intensityBadge(habit.intensity, colors, strings),
    rows: [
      [
        progress,
        makeBadge(
          BadgeSlot.streak,
          Icons.local_fire_department_rounded,
          colors,
          color: starKindColor(StarKind.pulsar, colors, lit: lit),
          value: '$streak',
          label: strings.habitCurrentStreakLabel,
        ),
      ],
    ],
  );
}
