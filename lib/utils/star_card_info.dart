import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/habit.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../widgets/star_glyph.dart' show starKindColor;
import 'date_format.dart';
import 'habit_stats.dart';

/// One small fact on a star's card (tooltip or grid tile): an icon, an
/// optional value and what it stands for. The icon carries the state in its
/// colour (gold / blue); the value is always plain text colour.
class CardBadge {
  const CardBadge({
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    this.value,
    this.semanticLabel,
    this.secondary = false,
  });

  final IconData icon;
  final String? value;
  final Color iconColor;
  final Color valueColor;
  final String? semanticLabel;

  /// Nice to have rather than essential: a small tile may leave it out.
  final bool secondary;
}

/// The badges for a [star] (lit, goal or dead): its main fact first, then
/// (lit only) attachments — voice notes, photos, videos, links —
/// each with its count, even when it is 1. Pure model data, no I/O.
List<CardBadge> starCardBadges(
  Star star,
  AppColors colors,
  AppStrings strings,
) {
  final text = colors.text;
  final badges = <CardBadge>[];
  switch (star.kind) {
    case StarKind.lit:
      badges.add(
        CardBadge(
          icon: Icons.bolt_rounded,
          value: '${star.intensity ?? 0}',
          iconColor: colors.gold,
          valueColor: text,
          semanticLabel: strings.intensityLabel,
        ),
      );
    case StarKind.unlit:
      final date = star.targetDate;
      badges.add(
        CardBadge(
          icon: Icons.calendar_month_rounded,
          value: date == null ? '—' : formatDisplayDate(date, strings),
          iconColor: date == null ? colors.starUnlit : colors.gold,
          valueColor: text,
        ),
      );
    case StarKind.dead:
      final date = star.deadDate;
      badges.add(
        CardBadge(
          icon: Icons.cancel_outlined,
          value: date == null ? '—' : formatDisplayDate(date, strings),
          iconColor: colors.gold,
          valueColor: text,
        ),
      );
    case StarKind.pulsar || StarKind.nascent:
      break;
  }
  // A dead star's page doesn't show its extras, so its card doesn't hint at
  // them either.
  if (star.dead) return badges;
  if (star.kind == StarKind.lit) {
    void attachment(StarMediaKind kind, IconData icon, String label) {
      final count = star.mediaCount(kind);
      if (count == 0) return;
      badges.add(
        CardBadge(
          icon: icon,
          value: '$count',
          iconColor: colors.gold,
          valueColor: text,
          semanticLabel: label,
          secondary: true,
        ),
      );
    }

    attachment(
      StarMediaKind.voice,
      Icons.mic_none_rounded,
      strings.cardBadgeVoice,
    );
    attachment(
      StarMediaKind.photo,
      Icons.photo_library_outlined,
      strings.cardBadgePhotos,
    );
    attachment(
      StarMediaKind.video,
      Icons.videocam_outlined,
      strings.cardBadgeVideos,
    );
    attachment(StarMediaKind.link, Icons.link_rounded, strings.cardBadgeLinks);
  }
  return badges;
}

/// The badges for a [habit] (a pulsar): streak, intensity, today's or this
/// week's progress. [countsByDay] is the habit's completions per
/// day, taken from a cache — never read from storage here.
List<CardBadge> habitCardBadges(
  Habit habit,
  Map<DateTime, int> countsByDay,
  AppColors colors,
  AppStrings strings, {
  DateTime? now,
}) {
  final text = colors.text;
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final badges = <CardBadge>[];
  if (!habit.dead) {
    final lit = isHabitLit(habit, countsByDay, now: today);
    badges.add(
      CardBadge(
        icon: Icons.local_fire_department_rounded,
        value: '${habitCurrentStreak(habit, countsByDay, now: today)}',
        iconColor: starKindColor(StarKind.pulsar, colors, lit: lit),
        valueColor: text,
        semanticLabel: strings.habitCurrentStreakLabel,
      ),
    );
  }
  badges.add(
    CardBadge(
      icon: Icons.bolt_rounded,
      value: '${habit.intensity}',
      iconColor: colors.gold,
      valueColor: text,
      semanticLabel: strings.intensityLabel,
    ),
  );
  if (!habit.dead) {
    if (habit.frequency == HabitFrequency.weekly) {
      final doneToday = countsByDay.containsKey(today);
      final week = habitWeeklyProgress(habit, countsByDay, now: today);
      badges.add(
        CardBadge(
          icon: Icons.date_range,
          value: '$week/${habit.targetPerPeriod}',
          iconColor: starKindColor(StarKind.pulsar, colors, lit: doneToday),
          valueColor: text,
          semanticLabel: strings.habitThisWeekCaption(doneToday),
        ),
      );
    } else if (habit.targetPerPeriod > 1) {
      final done = habitDailyProgress(habit, countsByDay, now: today);
      badges.add(
        CardBadge(
          icon: Icons.import_export,
          value: '$done/${habit.targetPerPeriod}',
          iconColor: starKindColor(
            StarKind.pulsar,
            colors,
            lit: done >= habit.targetPerPeriod,
          ),
          valueColor: text,
          semanticLabel: strings.habitTodayLabel,
        ),
      );
    }
  }
  return badges;
}
