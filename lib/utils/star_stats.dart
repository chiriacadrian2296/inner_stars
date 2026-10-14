import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../models/habit.dart';
import '../models/habit_cycle.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import 'date_math.dart';

/// Total victories logged across every project in [area], summed over that
/// area's projects — used by both Sky's aggregate area counts and the
/// Stars tab's area picker, so the two stay consistent. Goals and dead stars
/// don't count as a "star" here — only achieved ones do.
int starsInArea(
  LifeArea area,
  ProjectRepository projectRepository,
  StarRepository starRepository,
) {
  var total = 0;
  for (final project in projectRepository.getProjectsForArea(area)) {
    total += starRepository
        .getAllForProject(project.id)
        .where((s) => s.isLit)
        .length;
  }
  return total;
}

/// Groups achieved [stars] by calendar day (time-of-day discarded, [Star.dead]
/// and unachieved goals excluded by the caller before this is called),
/// counting how many were achieved on each day. Used to drive the
/// calendars and the longest-run record.
Map<DateTime, int> starCountsByDay(List<Star> stars) {
  final counts = <DateTime, int>{};
  for (final star in stars) {
    final achievedDate = star.achievedDate;
    if (achievedDate == null) continue;
    final day = DateTime(
      achievedDate.year,
      achievedDate.month,
      achievedDate.day,
    );
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

/// Groups achieved [stars] by calendar day, summing each day's intensities —
/// the total "brightness" for that day, used to scale the dashboard
/// calendar's per-star glow.
Map<DateTime, int> starIntensityByDay(List<Star> stars) {
  final totals = <DateTime, int>{};
  for (final star in stars) {
    final achievedDate = star.achievedDate;
    final intensity = star.intensity;
    if (achievedDate == null || intensity == null) continue;
    final day = DateTime(
      achievedDate.year,
      achievedDate.month,
      achievedDate.day,
    );
    totals[day] = (totals[day] ?? 0) + intensity;
  }
  return totals;
}

/// Groups completed pulsar [cycles] by the day their goal was reached,
/// summing each day's rewards — a cycle lights the calendar exactly like a
/// star of the same intensity does.
Map<DateTime, int> cycleIntensityByDay(Iterable<HabitCycle> cycles) {
  final totals = <DateTime, int>{};
  for (final cycle in cycles) {
    final day = dateOnly(cycle.completedDate);
    totals[day] = (totals[day] ?? 0) + cycle.intensity;
  }
  return totals;
}

/// How many cycles were completed on each calendar day.
Map<DateTime, int> cycleCountsByDay(Iterable<HabitCycle> cycles) {
  final counts = <DateTime, int>{};
  for (final cycle in cycles) {
    final day = dateOnly(cycle.completedDate);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

/// Per-day totals of [a] and [b] added together.
Map<DateTime, int> addDayTotals(Map<DateTime, int> a, Map<DateTime, int> b) {
  final merged = {...a};
  for (final entry in b.entries) {
    merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
  }
  return merged;
}

/// The total reward of the completed [cycles] belonging to [habitIds] (all
/// of them when null) — what a pulsar's finished cycles add to a
/// constellation's or an area's intensity.
int cycleIntensityTotal(Iterable<HabitCycle> cycles, {Set<int>? habitIds}) =>
    cycles
        .where((c) => habitIds == null || habitIds.contains(c.habitId))
        .fold<int>(0, (sum, c) => sum + c.intensity);

/// A run of consecutive days with at least one win. [length] is 0 (with
/// [start] and [end] both null) when there's nothing to report.
class StreakRange {
  const StreakRange({required this.length, this.start, this.end});

  final int length;
  final DateTime? start;
  final DateTime? end;
}

/// The longest run of consecutive days with at least one win, anywhere in
/// [countsByDay] — not necessarily ending today.
int longestStreak(Map<DateTime, int> countsByDay) {
  return longestStreakRange(countsByDay).length;
}

/// Same streak [longestStreak] measures, but with the date range it spans —
/// a record that only ever grows.
StreakRange longestStreakRange(Map<DateTime, int> countsByDay) {
  if (countsByDay.isEmpty) return const StreakRange(length: 0);
  final days = countsByDay.keys.toList()..sort();

  var longest = 1;
  var longestStart = days.first;
  var longestEnd = days.first;
  var currentLength = 1;
  var currentStart = days.first;
  for (var i = 1; i < days.length; i++) {
    final gap = dayDiff(days[i - 1], days[i]);
    if (gap == 1) {
      currentLength++;
    } else {
      currentLength = 1;
      currentStart = days[i];
    }
    if (currentLength > longest) {
      longest = currentLength;
      longestStart = currentStart;
      longestEnd = days[i];
    }
  }
  return StreakRange(length: longest, start: longestStart, end: longestEnd);
}

/// Which achieved stars the Statistics page counts: those in one of [areas]
/// (an empty set matches nothing, mirroring the Sky's area filter) and, when
/// [from]/[to] are set, achieved on or between those calendar days.
class StarFilter {
  const StarFilter({required this.areas, this.from, this.to});

  /// Everything: every area, any date.
  factory StarFilter.all() => StarFilter(areas: {...LifeArea.values});

  final Set<LifeArea> areas;
  final DateTime? from;
  final DateTime? to;

  bool get isAreaNarrowed => areas.length != LifeArea.values.length;
  bool get hasDateRange => from != null && to != null;
  bool get isActive => isAreaNarrowed || hasDateRange;

  StarFilter copyWith({
    Set<LifeArea>? areas,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) => StarFilter(
    areas: areas ?? this.areas,
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
  );

  /// Whether [star] passes. A star whose project no longer exists has no
  /// area, so it only passes while the area filter is untouched.
  bool matches(Star star, Map<int, Project> projectsById) {
    final achieved = star.achievedDate;
    if (achieved == null) return false;
    if (isAreaNarrowed) {
      final area = projectsById[star.projectId]?.area;
      if (area == null || !areas.contains(area)) return false;
    }
    if (hasDateRange) {
      final day = dateOnly(achieved);
      if (day.isBefore(dateOnly(from!)) || day.isAfter(dateOnly(to!))) {
        return false;
      }
    }
    return true;
  }
}

/// Whether a completed [cycle] of [habit] passes this filter, the way
/// [matches] does for a star: by the area of the habit's project and by the
/// day the cycle's goal was reached.
extension StarFilterCycles on StarFilter {
  bool matchesCycle(
    HabitCycle cycle,
    Habit? habit,
    Map<int, Project> projectsById,
  ) {
    if (isAreaNarrowed) {
      final area = habit == null ? null : projectsById[habit.projectId]?.area;
      if (area == null || !areas.contains(area)) return false;
    }
    if (hasDateRange) {
      final day = dateOnly(cycle.completedDate);
      if (day.isBefore(dateOnly(from!)) || day.isAfter(dateOnly(to!))) {
        return false;
      }
    }
    return true;
  }
}

/// Achieved-star counts per life area, largest first; areas with none are
/// left out.
List<MapEntry<LifeArea, int>> starCountsByArea(
  Iterable<Star> stars,
  Map<int, Project> projectsById,
) {
  final counts = <LifeArea, int>{};
  for (final star in stars) {
    final area = projectsById[star.projectId]?.area;
    if (area == null) continue;
    counts[area] = (counts[area] ?? 0) + 1;
  }
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
