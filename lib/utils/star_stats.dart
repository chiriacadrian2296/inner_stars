import '../data/project_repository.dart';
import '../data/star_repository.dart';
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
/// dashboard's activity heatmap and streak calculations.
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

/// A run of consecutive days with at least one win. [length] is 0 (with
/// [start] and [end] both null) when there's nothing to report.
class StreakRange {
  const StreakRange({required this.length, this.start, this.end});

  final int length;
  final DateTime? start;
  final DateTime? end;
}

/// Consecutive days with at least one win, counting back from [today]
/// (defaults to now) until the first day with none. Zero-length if today has
/// no win yet — a streak that isn't still "alive" doesn't count as current.
int currentStreak(Map<DateTime, int> countsByDay, {DateTime? today}) {
  return currentStreakRange(countsByDay, today: today).length;
}

/// Same streak [currentStreak] measures, but with the date range it spans
/// (ending on [today]) — used by the dashboard's streak detail screen.
StreakRange currentStreakRange(
  Map<DateTime, int> countsByDay, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  var day = DateTime(now.year, now.month, now.day);
  final end = day;
  var streak = 0;
  while ((countsByDay[day] ?? 0) > 0) {
    streak++;
    day = addDays(day, -1);
  }
  if (streak == 0) return const StreakRange(length: 0);
  return StreakRange(
    length: streak,
    start: addDays(end, -(streak - 1)),
    end: end,
  );
}

/// The longest run of consecutive days with at least one win, anywhere in
/// [countsByDay] — not necessarily ending today.
int longestStreak(Map<DateTime, int> countsByDay) {
  return longestStreakRange(countsByDay).length;
}

/// Same streak [longestStreak] measures, but with the date range it spans —
/// used by the dashboard's streak detail screen.
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
