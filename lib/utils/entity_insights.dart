import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import 'date_math.dart';
import 'habit_stats.dart';
import 'star_stats.dart';

enum InsightEntityKind { area, project, star, habit }

/// Stable identity shared by Sky, Galaxy and the readers. No storage changes.
class InsightEntity {
  const InsightEntity.area(LifeArea value)
    : kind = InsightEntityKind.area,
      area = value,
      id = null;
  const InsightEntity.project(int value)
    : kind = InsightEntityKind.project,
      id = value,
      area = null;
  const InsightEntity.star(int value)
    : kind = InsightEntityKind.star,
      id = value,
      area = null;
  const InsightEntity.habit(int value)
    : kind = InsightEntityKind.habit,
      id = value,
      area = null;

  final InsightEntityKind kind;
  final LifeArea? area;
  final int? id;
  bool get aggregate =>
      kind == InsightEntityKind.area || kind == InsightEntityKind.project;
  @override
  bool operator ==(Object other) =>
      other is InsightEntity &&
      kind == other.kind &&
      area == other.area &&
      id == other.id;
  @override
  int get hashCode => Object.hash(kind, area, id);
}

class EntityInsights {
  EntityInsights({
    required this.entity,
    required this.projects,
    required this.stars,
    required this.habits,
    required this.completions,
    required this.now,
    required this.range,
  });

  final InsightEntity entity;
  final List<Project> projects;
  final List<Star> stars;
  final List<Habit> habits;
  final List<HabitCompletion> completions;
  final DateTime now;
  final HabitStatsRange range;
  DateTime get today => dateOnly(now);
  DateTime get start => addDays(today, 1 - range.days);
  List<Habit> get activeHabits => habits.where((h) => h.isActive).toList();
  int get victories => stars.where((s) => s.isLit).length;
  int get goals => stars.where((s) => s.isUnlit).length;
  int get recentVictories => stars
      .where(
        (s) =>
            s.isLit &&
            !dateOnly(s.achievedDate!).isBefore(start) &&
            !dateOnly(s.achievedDate!).isAfter(today),
      )
      .length;
  Map<DateTime, int> get victoryDays => starCountsByDay(
    stars
        .where(
          (s) =>
              s.isLit &&
              !dateOnly(s.achievedDate!).isBefore(start) &&
              !dateOnly(s.achievedDate!).isAfter(today),
        )
        .toList(),
  );
  int todayCount(Habit habit) => completions
      .where((c) => c.habitId == habit.id && dateOnly(c.date) == today)
      .length;
  bool doneToday(Habit habit) =>
      todayCount(habit) >=
      (habit.frequency == HabitFrequency.daily ? habit.targetPerPeriod : 1);
  int get habitsDoneToday => activeHabits.where(doneToday).length;

  /// Archived history ends at archiving; future-created records have no observations.
  final _summaries = <int, HabitStatsSummary>{};
  HabitStatsSummary summary(Habit habit) => _summaries.putIfAbsent(
    habit.id,
    () => habitStatsSummary(
      habit,
      completions.where((c) => c.habitId == habit.id).toList(),
      range: range,
      now: habit.dead && habit.deadDate != null && habit.deadDate!.isBefore(now)
          ? habit.deadDate
          : now,
    ),
  );

  double? get consistency {
    final candidates = entity.aggregate ? activeHabits : habits;
    final observed = candidates
        .where((h) => summary(h).trend.isNotEmpty)
        .toList();
    if (observed.isEmpty) return null;
    return observed.fold<double>(
          0,
          (sum, h) => sum + summary(h).completionRate,
        ) /
        observed.length;
  }

  static EntityInsights read({
    required InsightEntity entity,
    required ProjectRepository projects,
    required StarRepository stars,
    required HabitRepository habits,
    required HabitCompletionRepository completions,
    HabitStatsRange range = HabitStatsRange.days30,
    DateTime? now,
  }) {
    final allProjects = projects.getAll();
    final selectedProjects = allProjects
        .where(
          (p) => switch (entity.kind) {
            InsightEntityKind.area => p.area == entity.area,
            InsightEntityKind.project => p.id == entity.id,
            _ => true,
          },
        )
        .toList();
    final ids = selectedProjects.map((p) => p.id).toSet();
    final selectedStars = stars
        .getAll()
        .where(
          (s) => entity.aggregate
              ? ids.contains(s.projectId)
              : entity.kind == InsightEntityKind.star && s.id == entity.id,
        )
        .toList();
    final selectedHabits = habits
        .getAll()
        .where(
          (h) => entity.aggregate
              ? ids.contains(h.projectId)
              : entity.kind == InsightEntityKind.habit && h.id == entity.id,
        )
        .toList();
    final habitIds = selectedHabits.map((h) => h.id).toSet();
    return EntityInsights(
      entity: entity,
      projects: selectedProjects,
      stars: selectedStars,
      habits: selectedHabits,
      completions: completions
          .getAll()
          .where((c) => habitIds.contains(c.habitId))
          .toList(),
      now: now ?? DateTime.now(),
      range: range,
    );
  }
}
