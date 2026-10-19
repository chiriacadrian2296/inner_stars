import '../models/habit.dart';
import '../models/habit_completion.dart';
import 'habit_stats.dart';

/// Everything the Statistics page needs to know about one habit, computed
/// once so the list, its ordering and the overview tiles all read the same
/// numbers instead of each re-deriving them from storage.
class HabitStatsEntry {
  const HabitStatsEntry({
    required this.habit,
    required this.countsByDay,
    required this.summary,
    required this.isLit,
    required this.cycleProgress,
  });

  final Habit habit;
  final Map<DateTime, int> countsByDay;

  /// Summary over the range the snapshot was built for.
  final HabitStatsSummary summary;
  final bool isLit;

  /// Distinct days done in the habit's current cycle.
  final int cycleProgress;
}

/// A single pass over [habits] and [allCompletions] (one storage decode for
/// the whole page), with the entries ordered so habits not done yet today
/// (not lit) come first.
class HabitStatsSnapshot {
  HabitStatsSnapshot._(this.entries, this.range, this.totalDaysDone);

  factory HabitStatsSnapshot.build({
    required List<Habit> habits,
    required List<HabitCompletion> allCompletions,
    required HabitStatsRange range,
    DateTime? now,
  }) {
    final byHabit = <String, List<HabitCompletion>>{};
    for (final completion in allCompletions) {
      (byHabit[completion.habitId] ??= []).add(completion);
    }
    final entries = <HabitStatsEntry>[];
    var daysDone = 0;
    for (final habit in habits) {
      final completions = byHabit[habit.id] ?? const <HabitCompletion>[];
      final counts = habitCompletionCountsByDay(completions);
      final summary = habitStatsSummary(
        habit,
        completions,
        range: range,
        now: now,
      );
      daysDone += summary.daysDone;
      entries.add(
        HabitStatsEntry(
          habit: habit,
          countsByDay: counts,
          summary: summary,
          isLit: isHabitLit(habit, counts, now: now),
          cycleProgress: habitCycleProgress(habit, counts, now: now),
        ),
      );
    }
    // Stable sort: unlit first, otherwise keep the repository's order.
    final indexed = entries.asMap().entries.toList()
      ..sort((a, b) {
        final byLit = (a.value.isLit ? 1 : 0).compareTo(b.value.isLit ? 1 : 0);
        return byLit != 0 ? byLit : a.key.compareTo(b.key);
      });
    return HabitStatsSnapshot._(
      [for (final e in indexed) e.value],
      range,
      daysDone,
    );
  }

  final List<HabitStatsEntry> entries;
  final HabitStatsRange range;

  /// Days with a check-in over [range], summed across every entry.
  final int totalDaysDone;

  /// How many habits were already done today.
  int get doneTodayCount => entries.where((e) => e.isLit).length;
}
