import '../models/habit.dart';
import '../models/habit_completion.dart';
import 'date_math.dart';

enum HabitStatsRange {
  days7(7),
  days30(30),
  days90(90);

  const HabitStatsRange(this.days);
  final int days;
}

class HabitTrendPoint {
  const HabitTrendPoint({required this.date, required this.progress});

  final DateTime date;
  final double progress;
}

class HabitWeekdayStat {
  const HabitWeekdayStat({
    required this.weekday,
    required this.completed,
    required this.available,
  });

  final int weekday;
  final int completed;
  final int available;
  double get rate => available == 0 ? 0 : completed / available;
}

class HabitStatsSummary {
  const HabitStatsSummary({
    required this.range,
    required this.currentStreak,
    required this.longestStreak,
    required this.daysDone,
    required this.totalCompletions,
    required this.trend,
    required this.progressByDay,
    required this.weekdays,
    required this.bestWeekday,
  });

  final HabitStatsRange range;
  final int currentStreak;
  final int longestStreak;

  /// Distinct days with at least one check-in inside [range] — what was done,
  /// never measured against what was asked.
  final int daysDone;
  final int totalCompletions;
  final List<HabitTrendPoint> trend;
  final Map<DateTime, double> progressByDay;
  final List<HabitWeekdayStat> weekdays;
  final HabitWeekdayStat? bestWeekday;
}

/// Monday of the calendar week containing [day] — [HabitFrequency.weekly]'s
/// own period boundary, a hard reset every Monday rather than a rolling
/// 7-day window (`DateTime.weekday` is 1 for Monday..7 for Sunday).
DateTime _weekStart(DateTime day) => addDays(day, -(day.weekday - 1));

/// Groups [completions] by calendar day, counting how many were logged on
/// each day — 0 or 1 for a [HabitFrequency.daily] habit whose target is 1
/// (see [HabitCompletionRepository.markDone]'s idempotency), but can be
/// higher for a daily habit whose target is more than 1 (see
/// [HabitCompletionRepository.logInstance]) or for [StarHeatmap], which
/// expects a count map regardless.
Map<DateTime, int> habitCompletionCountsByDay(
  List<HabitCompletion> completions,
) {
  final counts = <DateTime, int>{};
  for (final completion in completions) {
    final day = dateOnly(completion.date);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

Map<DateTime, double> habitProgressByDay(
  Habit habit,
  Map<DateTime, int> countsByDay,
) {
  return {
    for (final entry in countsByDay.entries)
      entry.key: habit.frequency == HabitFrequency.daily
          ? (entry.value / habit.targetPerPeriod).clamp(0.0, 1.0).toDouble()
          : (entry.value > 0 ? 1.0 : 0.0),
  };
}

/// Whether [day] counts as "met" for [habit] — the one place both
/// frequencies' own definition of a satisfied day lives. A [daily] habit
/// needs that day's own count to reach [Habit.targetPerPeriod] (e.g. 3 of 3
/// meditation sessions); a [weekly] habit only needs *a* completion that
/// day — its target is a count of distinct days, not a per-day count, so a
/// second same-day session never counts as a second day.
bool _dayMet(Habit habit, Map<DateTime, int> countsByDay, DateTime day) {
  final count = countsByDay[day] ?? 0;
  return habit.frequency == HabitFrequency.daily
      ? count >= habit.targetPerPeriod
      : count >= 1;
}

/// How many of [weekStart]'s own 7 days (Monday..Sunday) are [_dayMet] —
/// safe to call on a week still in progress, since a day that hasn't
/// happened yet simply has no completions and so isn't met, the same as a
/// missed one; it never needs to be excluded separately.
int _weekMetDays(
  Habit habit,
  Map<DateTime, int> countsByDay,
  DateTime weekStart,
) {
  var count = 0;
  for (var i = 0; i < 7; i++) {
    if (_dayMet(habit, countsByDay, addDays(weekStart, i))) {
      count++;
    }
  }
  return count;
}

/// Whether a habit's star should currently read as lit: it was done at least
/// once today. The habit's own frequency and target are only the rhythm the
/// user would like — they never decide the state, so a habit is never "dark"
/// for missing a goal, it simply isn't lit until it's done again.
bool isHabitLit(Habit habit, Map<DateTime, int> countsByDay, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  return (countsByDay[today] ?? 0) > 0;
}

/// How many distinct days of the habit's current cycle have been done: every
/// day from [Habit.currentCycleStart] up to [now] with at least one
/// completion. Not capped — callers clamp for display; reaching
/// [Habit.cycleLength] is what completes the cycle.
int habitCycleProgress(
  Habit habit,
  Map<DateTime, int> countsByDay, {
  DateTime? now,
}) {
  final start = habit.currentCycleStart;
  final end = dateOnly(now ?? DateTime.now());
  var days = 0;
  for (final entry in countsByDay.entries) {
    if (entry.value <= 0) continue;
    final day = dateOnly(entry.key);
    if (day.isBefore(start) || day.isAfter(end)) continue;
    days++;
  }
  return days;
}

/// The day the current cycle's last needed repetition happened — the
/// [Habit.cycleLength]-th distinct done day counting from
/// [Habit.currentCycleStart] — or null while the cycle isn't complete yet.
DateTime? habitCycleCompletedDay(
  Habit habit,
  Map<DateTime, int> countsByDay, {
  DateTime? now,
}) {
  final start = habit.currentCycleStart;
  final end = dateOnly(now ?? DateTime.now());
  final days = <DateTime>[
    for (final entry in countsByDay.entries)
      if (entry.value > 0 &&
          !dateOnly(entry.key).isBefore(start) &&
          !dateOnly(entry.key).isAfter(end))
        dateOnly(entry.key),
  ]..sort();
  if (days.length < habit.cycleLength) return null;
  return days[habit.cycleLength - 1];
}

/// [HabitFrequency.daily]: today's raw completion count, for a "2/3 today"
/// progress display on a habit whose target is more than 1 — meaningless
/// (always 0 or 1) for a target of exactly 1, so callers only show this for
/// `targetPerPeriod > 1`.
int habitDailyProgress(
  Habit habit,
  Map<DateTime, int> countsByDay, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  return countsByDay[today] ?? 0;
}

/// [HabitFrequency.weekly]: how many of this calendar week's days have
/// already been met, for a "2/3 this week" progress display.
int habitWeeklyProgress(
  Habit habit,
  Map<DateTime, int> countsByDay, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  return _weekMetDays(habit, countsByDay, _weekStart(today));
}

/// Consecutive periods met — days for [HabitFrequency.daily], calendar
/// weeks for [HabitFrequency.weekly]. A habit not done yet for the current
/// period (today / this week) keeps the streak it had up to the previous one
/// until that period ends; it drops to 0 once the previous one was missed too.
///
/// Deliberately not a generalization of `star_stats.dart`'s `currentStreak`
/// (which requires today specifically to have a value) — a habit's own
/// grace before its deadline needs different anchoring per frequency.
int habitCurrentStreak(
  Habit habit,
  Map<DateTime, int> countsByDay, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  if (habit.frequency == HabitFrequency.daily) {
    var day = _dayMet(habit, countsByDay, today) ? today : addDays(today, -1);
    var streak = 0;
    while (_dayMet(habit, countsByDay, day)) {
      streak++;
      day = addDays(day, -1);
    }
    return streak;
  }

  // A week still in progress only joins the streak once it's actually met
  // its target.
  var weekStart = _weekStart(today);
  if (_weekMetDays(habit, countsByDay, weekStart) < habit.targetPerPeriod) {
    weekStart = addDays(weekStart, -7);
  }
  var streak = 0;
  while (_weekMetDays(habit, countsByDay, weekStart) >= habit.targetPerPeriod) {
    streak++;
    weekStart = addDays(weekStart, -7);
  }
  return streak;
}

DateTime _habitEnd(Habit habit, DateTime now) {
  final today = dateOnly(now);
  if (habit.deadDate == null) return today;
  final deadDay = dateOnly(habit.deadDate!);
  return deadDay.isBefore(today) ? deadDay : today;
}

DateTime _maxDay(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// The longest run over the habit's complete eligible lifetime. Daily habits
/// return days; weekly habits return calendar weeks that reached their target.
int habitLongestStreak(
  Habit habit,
  Map<DateTime, int> countsByDay, {
  DateTime? now,
}) {
  final end = _habitEnd(habit, now ?? DateTime.now());
  final start = dateOnly(habit.createdAt);
  if (end.isBefore(start)) return 0;

  var longest = 0;
  var running = 0;
  if (habit.frequency == HabitFrequency.daily) {
    for (var day = start; !day.isAfter(end); day = addDays(day, 1)) {
      if (_dayMet(habit, countsByDay, day)) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 0;
      }
    }
    return longest;
  }

  for (
    var week = _weekStart(start);
    !week.isAfter(_weekStart(end));
    week = addDays(week, 7)
  ) {
    if (_weekMetDays(habit, countsByDay, week) >= habit.targetPerPeriod) {
      running++;
      if (running > longest) longest = running;
    } else {
      running = 0;
    }
  }
  return longest;
}

/// Builds every figure used by the overview and the pulsar dashboard.
/// Values are clamped to the habit's lifetime and [now] is injectable so the
/// result remains stable in tests.
HabitStatsSummary habitStatsSummary(
  Habit habit,
  List<HabitCompletion> completions, {
  HabitStatsRange range = HabitStatsRange.days30,
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final end = _habitEnd(habit, effectiveNow);
  final lifetimeStart = dateOnly(habit.createdAt);
  final requestedStart = addDays(end, -(range.days - 1));
  final start = _maxDay(lifetimeStart, requestedStart);
  final counts = habitCompletionCountsByDay(completions);
  final progress = <DateTime, double>{};
  final trend = <HabitTrendPoint>[];
  final weekdayCompleted = List<int>.filled(7, 0);
  final weekdayAvailable = List<int>.filled(7, 0);

  var daysDone = 0;
  if (!end.isBefore(start)) {
    for (var day = start; !day.isAfter(end); day = addDays(day, 1)) {
      final raw = counts[day] ?? 0;
      final dayProgress = habit.frequency == HabitFrequency.daily
          ? (raw / habit.targetPerPeriod).clamp(0.0, 1.0).toDouble()
          : (raw > 0 ? 1.0 : 0.0);
      progress[day] = dayProgress;
      trend.add(HabitTrendPoint(date: day, progress: dayProgress));
      weekdayAvailable[day.weekday - 1]++;
      if (raw > 0) {
        daysDone++;
        weekdayCompleted[day.weekday - 1]++;
      }
    }
  }

  final weekdays = List<HabitWeekdayStat>.generate(
    7,
    (index) => HabitWeekdayStat(
      weekday: index + 1,
      completed: weekdayCompleted[index],
      available: weekdayAvailable[index],
    ),
  );
  final comparable = weekdays.where((item) => item.available > 0).toList();
  HabitWeekdayStat? best;
  // Avoid claiming a pattern before every weekday has had at least one fair
  // chance to occur in the selected interval.
  if (comparable.length == 7) {
    best = comparable.reduce((a, b) => b.rate > a.rate ? b : a);
  }

  return HabitStatsSummary(
    range: range,
    currentStreak: habit.dead
        ? 0
        : habitCurrentStreak(habit, counts, now: effectiveNow),
    longestStreak: habitLongestStreak(habit, counts, now: effectiveNow),
    daysDone: daysDone,
    totalCompletions: completions.where((completion) {
      final day = dateOnly(completion.date);
      return !day.isBefore(lifetimeStart) && !day.isAfter(end);
    }).length,
    trend: List.unmodifiable(trend),
    progressByDay: Map.unmodifiable(progress),
    weekdays: List.unmodifiable(weekdays),
    bestWeekday: best,
  );
}
