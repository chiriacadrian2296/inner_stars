import '../models/star.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import 'date_math.dart';

/// Recorded accomplishments, without targets or missed days. Past Pulsar
/// completions remain accomplishments even when their habit is archived.
class CelebrationStats {
  CelebrationStats({
    required List<Star> stars,
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    required DateTime now,
    int? days,
  }) {
    final today = dateOnly(now);
    final start = days == null ? null : addDays(today, 1 - days);
    bool includes(DateTime date) {
      final day = dateOnly(date);
      return !day.isAfter(today) && (start == null || !day.isBefore(start));
    }

    final habitsById = {for (final habit in habits) habit.id: habit};
    final projects = <int>{};
    final countsByDay = <DateTime, int>{};
    void record(DateTime date) {
      final day = dateOnly(date);
      countsByDay[day] = (countsByDay[day] ?? 0) + 1;
    }

    for (final star in stars) {
      if (!star.isLit || !includes(star.achievedDate!)) continue;
      starsCount++;
      record(star.achievedDate!);
      projects.add(star.projectId);
    }
    for (final completion in completions) {
      final habit = habitsById[completion.habitId];
      if (habit == null || !includes(completion.date)) continue;
      gesturesCount++;
      record(completion.date);
      projects.add(habit.projectId);
    }
    projectsCount = projects.length;
    final dates = countsByDay.keys.toList()..sort();
    final first = start ?? (dates.isEmpty ? today : dates.first);
    // A zero baseline precedes the first included day. Sparse event points
    // retain exact plateaus without allocating one point per empty day.
    cumulative = [CelebrationPoint(addDays(first, -1), 0)];
    var accumulated = 0;
    for (final date in dates) {
      accumulated += countsByDay[date]!;
      cumulative.add(CelebrationPoint(date, accumulated));
    }
    if (cumulative.last.date != today) {
      cumulative.add(CelebrationPoint(today, accumulated));
    }
  }

  int starsCount = 0;
  int gesturesCount = 0;
  int projectsCount = 0;
  late final List<CelebrationPoint> cumulative;
  int get total => starsCount + gesturesCount;
}

class CelebrationPoint {
  const CelebrationPoint(this.date, this.total);
  final DateTime date;
  final int total;
}
