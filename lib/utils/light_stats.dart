import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_cycle.dart';
import '../models/project.dart';
import '../models/star.dart';
import 'celebration_stats.dart' show CelebrationPoint;
import 'date_math.dart';
import 'entity_insights.dart';
import 'habit_stats.dart' show habitCompletionCountsByDay;

/// The time window "Your Light" looks at. Every figure only ever grows
/// within it: there is no rolling window to fall out of.
enum LightPeriod { allTime, year, month }

/// One child of the current scope (an area of everything, a constellation
/// of an area, an activity of a constellation) and the light it holds.
class LightShare {
  const LightShare({required this.entity, required this.light});

  final InsightEntity entity;
  final int light;
}

/// A run of consecutive days with something done.
class LightRun {
  const LightRun({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
  int get length => dayDiff(start, end) + 1;
}

/// The highlights of a period — each one is null when there isn't enough
/// to say about it yet, never a "missing" state.
class LightMoments {
  const LightMoments({
    this.firstVictory,
    this.latestVictory,
    this.firstDay,
    this.brightestDay,
    this.brightestDayLight = 0,
    this.longestRun,
    this.favouriteWeekday,
    this.brightestMonth,
    this.brightestMonthLight = 0,
    this.longestCycle,
  });

  final Star? firstVictory;
  final Star? latestVictory;

  /// The first day with something done (used where there are no
  /// victories to point to, i.e. a pulsar).
  final DateTime? firstDay;
  final DateTime? brightestDay;
  final int brightestDayLight;
  final LightRun? longestRun;

  /// 1 (Monday) to 7 (Sunday).
  final int? favouriteWeekday;

  /// The first day of the month.
  final DateTime? brightestMonth;
  final int brightestMonthLight;
  final HabitCycle? longestCycle;

  bool get isEmpty =>
      firstVictory == null &&
      latestVictory == null &&
      firstDay == null &&
      brightestDay == null &&
      longestRun == null &&
      favouriteWeekday == null &&
      brightestMonth == null &&
      longestCycle == null;
}

/// Everything "Your Light" shows for one scope and period.
///
/// One measure everywhere, shown to the user as "Intensity" (internally
/// called light here): the intensity of every lit star plus the reward of
/// every completed pulsar cycle. A day counts as a day with light
/// when a victory, a completed cycle or a pulsar check-in happened on it.
/// Nothing here is measured against a target.
class LightStats {
  LightStats._({
    required this.scope,
    required this.period,
    required this.from,
    required this.today,
    required this.projects,
    required this.stars,
    required this.habits,
    required this.victories,
    required this.cycles,
    required this.completions,
  });

  /// Null means everything.
  final InsightEntity? scope;
  final LightPeriod period;

  /// First day of the period; null for all time.
  final DateTime? from;
  final DateTime today;

  /// What the scope covers, regardless of the period.
  final List<Project> projects;
  final List<Star> stars;
  final List<Habit> habits;

  /// What happened within the period.
  final List<Star> victories;
  final List<HabitCycle> cycles;
  final List<HabitCompletion> completions;

  bool get isHabitScope => scope?.kind == InsightEntityKind.habit;
  bool get isStarScope => scope?.kind == InsightEntityKind.star;

  int get light =>
      victories.fold<int>(0, (sum, s) => sum + (s.intensity ?? 0)) +
      cycles.fold<int>(0, (sum, c) => sum + c.intensity);

  /// The reward the scope's completed cycles earned within the period.
  int get cycleLight => cycles.fold<int>(0, (sum, c) => sum + c.intensity);

  late final Map<DateTime, int> checkInsByDay = habitCompletionCountsByDay(
    completions,
  );

  /// Distinct days with a check-in — a pulsar's own headline figure.
  int get daysDone => checkInsByDay.length;

  late final Set<DateTime> activeDays = {
    for (final star in victories) dateOnly(star.achievedDate!),
    for (final cycle in cycles) dateOnly(cycle.completedDate),
    ...checkInsByDay.keys,
  };

  /// Each day's light: victories' intensity plus cycles' rewards.
  late final Map<DateTime, int> lightByDay = () {
    final totals = <DateTime, int>{};
    for (final star in victories) {
      final day = dateOnly(star.achievedDate!);
      totals[day] = (totals[day] ?? 0) + (star.intensity ?? 0);
    }
    for (final cycle in cycles) {
      final day = dateOnly(cycle.completedDate);
      totals[day] = (totals[day] ?? 0) + cycle.intensity;
    }
    return totals;
  }();

  /// What lights each calendar day: victories, completed cycles and (one
  /// per pulsar) check-ins.
  late final Map<DateTime, int> countsByDay = () {
    final counts = <DateTime, int>{};
    void add(DateTime date) {
      final day = dateOnly(date);
      counts[day] = (counts[day] ?? 0) + 1;
    }

    for (final star in victories) {
      add(star.achievedDate!);
    }
    for (final cycle in cycles) {
      add(cycle.completedDate);
    }
    final seen = <(String, DateTime)>{};
    for (final completion in completions) {
      if (seen.add((completion.habitId, dateOnly(completion.date)))) {
        add(completion.date);
      }
    }
    return counts;
  }();

  /// The cumulative curve: light for every scope but a pulsar, whose
  /// curve counts its days done instead (its light only arrives with a
  /// completed cycle, so it would mostly sit flat).
  late final List<CelebrationPoint> cumulative = () {
    final perDay = isHabitScope
        ? {for (final day in checkInsByDay.keys) day: 1}
        : lightByDay;
    final days = perDay.keys.toList()..sort();
    final first = from ?? (days.isEmpty ? today : days.first);
    final points = [CelebrationPoint(addDays(first, -1), 0)];
    var total = 0;
    for (final day in days) {
      total += perDay[day]!;
      points.add(CelebrationPoint(day, total));
    }
    if (points.last.date != today) {
      points.add(CelebrationPoint(today, total));
    }
    return points;
  }();

  /// Where the light of this scope sits, one level down, brightest first.
  /// Children without light are left out.
  late final List<LightShare> breakdown = () {
    final projectsById = {for (final p in projects) p.id: p};
    final habitsById = {for (final h in habits) h.id: h};
    final totals = <InsightEntity, int>{};
    void add(InsightEntity entity, int value) {
      if (value <= 0) return;
      totals[entity] = (totals[entity] ?? 0) + value;
    }

    InsightEntity? childOf(String projectId, InsightEntity activity) {
      final project = projectsById[projectId];
      if (project == null) return null;
      return switch (scope?.kind) {
        null => InsightEntity.area(project.area),
        InsightEntityKind.area => InsightEntity.project(project.id),
        InsightEntityKind.project => activity,
        _ => null,
      };
    }

    for (final star in victories) {
      final child = childOf(star.projectId, InsightEntity.star(star.id));
      if (child != null) add(child, star.intensity ?? 0);
    }
    for (final cycle in cycles) {
      final habit = habitsById[cycle.habitId];
      if (habit == null) continue;
      final child = childOf(habit.projectId, InsightEntity.habit(habit.id));
      if (child != null) add(child, cycle.intensity);
    }
    return [
      for (final entry in totals.entries)
        LightShare(entity: entry.key, light: entry.value),
    ]..sort((a, b) => b.light.compareTo(a.light));
  }();

  late final LightMoments moments = () {
    Star? firstVictory;
    Star? latestVictory;
    for (final star in victories) {
      if (firstVictory == null ||
          star.achievedDate!.isBefore(firstVictory.achievedDate!)) {
        firstVictory = star;
      }
      if (latestVictory == null ||
          star.achievedDate!.isAfter(latestVictory.achievedDate!)) {
        latestVictory = star;
      }
    }

    final sortedActive = activeDays.toList()..sort();

    DateTime? brightestDay;
    var brightestDayLight = 0;
    if (lightByDay.length >= 2) {
      for (final entry in lightByDay.entries) {
        if (entry.value > brightestDayLight ||
            (entry.value == brightestDayLight &&
                brightestDay != null &&
                entry.key.isBefore(brightestDay))) {
          brightestDay = entry.key;
          brightestDayLight = entry.value;
        }
      }
    }

    LightRun? longestRun;
    if (sortedActive.isNotEmpty) {
      var runStart = sortedActive.first;
      var bestStart = runStart;
      var bestEnd = runStart;
      for (var i = 1; i < sortedActive.length; i++) {
        if (dayDiff(sortedActive[i - 1], sortedActive[i]) != 1) {
          runStart = sortedActive[i];
        }
        if (dayDiff(runStart, sortedActive[i]) > dayDiff(bestStart, bestEnd)) {
          bestStart = runStart;
          bestEnd = sortedActive[i];
        }
      }
      final run = LightRun(start: bestStart, end: bestEnd);
      if (run.length >= 2) longestRun = run;
    }

    // A favourite day only once there is something to compare: at least
    // two weeks' worth of days with light, and one weekday clearly ahead.
    int? favouriteWeekday;
    if (sortedActive.length >= 14) {
      final byWeekday = List<int>.filled(7, 0);
      for (final day in sortedActive) {
        byWeekday[day.weekday - 1]++;
      }
      final best = byWeekday.reduce((a, b) => a > b ? a : b);
      if (byWeekday.where((count) => count == best).length == 1) {
        favouriteWeekday = byWeekday.indexOf(best) + 1;
      }
    }

    DateTime? brightestMonth;
    var brightestMonthLight = 0;
    if (period != LightPeriod.month) {
      final byMonth = <DateTime, int>{};
      for (final entry in lightByDay.entries) {
        final month = DateTime(entry.key.year, entry.key.month);
        byMonth[month] = (byMonth[month] ?? 0) + entry.value;
      }
      if (byMonth.length >= 2) {
        for (final entry in byMonth.entries) {
          if (entry.value > brightestMonthLight) {
            brightestMonth = entry.key;
            brightestMonthLight = entry.value;
          }
        }
      }
    }

    HabitCycle? longestCycle;
    for (final cycle in cycles) {
      if (longestCycle == null || cycle.length > longestCycle.length) {
        longestCycle = cycle;
      }
    }

    return LightMoments(
      firstVictory: firstVictory,
      latestVictory: latestVictory,
      firstDay: isHabitScope && sortedActive.isNotEmpty
          ? sortedActive.first
          : null,
      brightestDay: brightestDay,
      brightestDayLight: brightestDayLight,
      longestRun: longestRun,
      favouriteWeekday: favouriteWeekday,
      brightestMonth: brightestMonth,
      brightestMonthLight: brightestMonthLight,
      longestCycle: longestCycle,
    );
  }();

  /// The first day of [period] containing [today]; null for all time.
  static DateTime? periodStart(LightPeriod period, DateTime today) =>
      switch (period) {
        LightPeriod.allTime => null,
        LightPeriod.year => DateTime(today.year),
        LightPeriod.month => DateTime(today.year, today.month),
      };

  static LightStats build({
    required InsightEntity? scope,
    required LightPeriod period,
    required List<Project> projects,
    required List<Star> stars,
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    required List<HabitCycle> cycles,
    DateTime? now,
  }) {
    final today = dateOnly(now ?? DateTime.now());
    final from = periodStart(period, today);
    bool inPeriod(DateTime date) {
      final day = dateOnly(date);
      return !day.isAfter(today) && (from == null || !day.isBefore(from));
    }

    final selectedProjects = [
      for (final project in projects)
        if (switch (scope?.kind) {
          null => true,
          InsightEntityKind.area => project.area == scope!.area,
          InsightEntityKind.project => project.id == scope!.id,
          _ => false,
        })
          project,
    ];
    final projectIds = {for (final p in selectedProjects) p.id};
    final aggregate = scope == null || scope.aggregate;
    final selectedStars = [
      for (final star in stars)
        if (aggregate
            ? projectIds.contains(star.projectId)
            : scope.kind == InsightEntityKind.star && star.id == scope.id)
          star,
    ];
    final selectedHabits = [
      for (final habit in habits)
        if (aggregate
            ? projectIds.contains(habit.projectId)
            : scope.kind == InsightEntityKind.habit && habit.id == scope.id)
          habit,
    ];
    final habitIds = {for (final h in selectedHabits) h.id};

    return LightStats._(
      scope: scope,
      period: period,
      from: from,
      today: today,
      projects: selectedProjects,
      stars: selectedStars,
      habits: selectedHabits,
      victories: [
        for (final star in selectedStars)
          if (star.isLit && inPeriod(star.achievedDate!)) star,
      ],
      cycles: [
        for (final cycle in cycles)
          if (habitIds.contains(cycle.habitId) && inPeriod(cycle.completedDate))
            cycle,
      ],
      completions: [
        for (final completion in completions)
          if (habitIds.contains(completion.habitId) &&
              inPeriod(completion.date))
            completion,
      ],
    );
  }
}
