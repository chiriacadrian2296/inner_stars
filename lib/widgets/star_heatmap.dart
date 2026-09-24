import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// A calendar for the current month — one star per day (the app's own take
/// on a GitHub-style contribution graph). Weekday headers on top, up to 6
/// week rows below; days outside the current month are blank. The star
/// itself is always the same solid gold once lit — what actually varies
/// between days is a gold glow around it, scaled in both opacity and size
/// between the month's dimmest and brightest day by that day's total win
/// intensity (see [intensityByDay]), not by how many wins it has.
class StarHeatmap extends StatelessWidget {
  const StarHeatmap({
    super.key,
    required this.countsByDay,
    required this.intensityByDay,
    this.onDayTap,
    this.month,
    this.onPreviousMonth,
    this.onNextMonth,
  });

  final Map<DateTime, int> countsByDay;

  /// Each day's total win intensity (sum of that day's wins' 1-5 intensity
  /// values) — see [winIntensityByDay]. Drives the glow, independently of
  /// [countsByDay], which only drives the star's fill opacity.
  final Map<DateTime, int> intensityByDay;

  final void Function(DateTime day)? onDayTap;

  /// The month being shown — any day within it works, only year/month are
  /// read. Defaults to the current month (via [build]) when omitted, so
  /// existing callers that don't care about month navigation still work.
  final DateTime? month;

  /// Paging arrows shown beside the month title. Null greys the arrow out
  /// (used by the caller to stop paging past the current month) rather than
  /// removing it, so the header's width stays stable as months change.
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final shownMonth = month ?? DateTime(todayDate.year, todayDate.month);
    final firstOfMonth = DateTime(shownMonth.year, shownMonth.month, 1);
    final daysInMonth = DateTime(shownMonth.year, shownMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - DateTime.monday;
    // Always 6 — the most any month can need — rather than the 5 or 6 a
    // given month's actual layout happens to require, so the grid (and the
    // panel around it) is exactly as tall for every month instead of
    // shrinking by a row for months that fit in 5.
    const rows = 6;

    // The min/max that calibrate glow intensity, taken only from days that
    // actually have a star lit — an all-zero day never glows, so it
    // shouldn't pull the low end of the scale down further.
    final litIntensities = intensityByDay.values.where((v) => v > 0);
    final minIntensity = litIntensities.isEmpty
        ? 0
        : litIntensities.reduce((a, b) => a < b ? a : b);
    final maxIntensity = litIntensities.isEmpty
        ? 0
        : litIntensities.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.monthTitle(firstOfMonth),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            _MonthArrowButton(icon: Icons.chevron_left, onTap: onPreviousMonth),
            _MonthArrowButton(icon: Icons.chevron_right, onTap: onNextMonth),
          ],
        ),
        const SizedBox(height: 12),
        // Paging to another month swaps the grid in place, so it cross-fades
        // instead of jumping. Every month draws the same 6 rows, so the two
        // grids overlap exactly during the fade.
        AnimatedSwitcher(
          duration: motionDuration(context, kMotionBase),
          child: Column(
            key: ValueKey(shownMonth.year * 12 + shownMonth.month),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final label in strings.weekdayAbbreviations)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < rows; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: Center(
                            child: _DayCell(
                              dayNumber: row * 7 + col - leadingBlanks + 1,
                              daysInMonth: daysInMonth,
                              month: shownMonth,
                              today: todayDate,
                              countsByDay: countsByDay,
                              intensityByDay: intensityByDay,
                              minIntensity: minIntensity,
                              maxIntensity: maxIntensity,
                              onTap: onDayTap,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 20,
      color: colors.text,
      disabledColor: colors.muted.withValues(alpha: 0.3),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.daysInMonth,
    required this.month,
    required this.today,
    required this.countsByDay,
    required this.intensityByDay,
    required this.minIntensity,
    required this.maxIntensity,
    this.onTap,
  });

  final int dayNumber;
  final int daysInMonth;
  final DateTime month;
  final DateTime today;
  final Map<DateTime, int> countsByDay;
  final Map<DateTime, int> intensityByDay;
  final int minIntensity;
  final int maxIntensity;
  final void Function(DateTime day)? onTap;

  // The star glyph itself, unchanged regardless of lit state.
  static const _starSize = 22.0;
  // The reserved footprint around it — bigger than the star so a lit day's
  // glow (up to 25px blur + 4px spread, see below) has room to render
  // without bleeding into neighboring cells or the panel's edge, which is
  // what previously made the calendar's apparent size shift between months
  // depending on which rows happened to have glowing days. Fixed for every
  // cell regardless of whether that day is actually lit, so an unlit day
  // just reads as extra breathing room around its star instead.
  static const _slotSize = 34.0;

  @override
  Widget build(BuildContext context) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(width: _slotSize, height: _slotSize);
    }

    final day = DateTime(month.year, month.month, dayNumber);
    if (day.isAfter(today)) {
      return SizedBox(
        width: _slotSize,
        height: _slotSize,
        child: Center(
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 10,
              color: context.colors.muted.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final count = countsByDay[day] ?? 0;
    final colors = context.colors;
    final isLit = count > 0;

    final dayIntensity = intensityByDay[day] ?? 0;
    var glowStrength = 0.0;
    if (dayIntensity > 0) {
      // Even the month's dimmest lit day still gets a faint trace of glow
      // instead of fading to nothing — only an unlit day (no stars at all)
      // gets none. Kept close to 0 (rather than a more noticeable floor) so
      // there's more visible range between the dimmest and brightest days.
      const glowFloor = 0.03;
      final normalized = maxIntensity == minIntensity
          ? 1.0
          : (dayIntensity - minIntensity) / (maxIntensity - minIntensity);
      glowStrength = glowFloor + (1 - glowFloor) * normalized;
    }

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(day),
        child: SizedBox(
          width: _slotSize,
          height: _slotSize,
          child: Center(
            child: Container(
              width: _starSize,
              height: _starSize,
              decoration: dayIntensity <= 0
                  ? null
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.gold.withValues(
                            alpha: 0.1 + 0.65 * glowStrength,
                          ),
                          blurRadius: 1 + 25 * glowStrength,
                          spreadRadius: 4 * glowStrength,
                        ),
                      ],
                    ),
              // The star itself is always the same solid gold, lit or not —
              // only the glow (above) carries how many/how intense that
              // day's wins were. It used to also fade the star's own opacity
              // down for low counts, which just made a light day look like a
              // rendering glitch rather than a deliberate "less glow" day.
              child: Icon(
                isLit ? Icons.star : Icons.star_border,
                size: _starSize,
                color: isLit
                    ? colors.gold
                    : colors.gold.withValues(alpha: 0.16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
