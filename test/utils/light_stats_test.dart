import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/habit_cycle.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/utils/entity_insights.dart';
import 'package:inner_stars/utils/light_stats.dart';

final _now = DateTime(2026, 10, 14, 12);

Project _project(int id, LifeArea area) => Project(
  id: id,
  name: 'Project $id',
  area: area,
  iconSlug: 'star',
  createdAt: DateTime(2026, 1),
);

Star _star(
  int id,
  DateTime? achieved, {
  int project = 1,
  int intensity = 3,
  bool dead = false,
}) => Star(
  id: id,
  projectId: project,
  slotSequence: id,
  title: 'Star $id',
  createdAt: DateTime(2026, 1),
  achievedDate: achieved,
  intensity: achieved == null ? null : intensity,
  dead: dead,
  deadDate: dead ? DateTime(2026, 10, 1) : null,
);

Habit _habit(int id, {int project = 1}) => Habit(
  id: id,
  projectId: project,
  title: 'Habit $id',
  createdAt: DateTime(2026, 1),
);

HabitCompletion _done(int id, int habit, DateTime day) =>
    HabitCompletion(id: id, habitId: habit, date: day);

HabitCycle _cycle(int id, int habit, DateTime day, {int intensity = 4}) =>
    HabitCycle(
      id: id,
      habitId: habit,
      startDate: day.subtract(const Duration(days: 6)),
      completedDate: day,
      length: 7,
      intensity: intensity,
    );

LightStats _build({
  InsightEntity? scope,
  LightPeriod period = LightPeriod.allTime,
  List<Star> stars = const [],
  List<Habit> habits = const [],
  List<HabitCompletion> completions = const [],
  List<HabitCycle> cycles = const [],
}) => LightStats.build(
  scope: scope,
  period: period,
  projects: [
    _project(1, LifeArea.physical),
    _project(2, LifeArea.physical),
    _project(3, LifeArea.social),
  ],
  stars: stars,
  habits: habits,
  completions: completions,
  cycles: cycles,
  now: _now,
);

void main() {
  test('light is lit stars plus completed cycles; goals, archived and '
      'future victories add nothing', () {
    final stats = _build(
      stars: [
        _star(1, DateTime(2026, 10, 1), intensity: 2),
        _star(2, DateTime(2026, 3, 5), intensity: 5),
        _star(3, null),
        _star(4, DateTime(2026, 9, 1), dead: true),
        _star(5, DateTime(2026, 11, 1)),
      ],
      habits: [_habit(1)],
      cycles: [_cycle(1, 1, DateTime(2026, 10, 7), intensity: 4)],
    );
    expect(stats.light, 2 + 5 + 4);
    expect(stats.victories.map((s) => s.id), [1, 2]);
    expect(stats.cycles, hasLength(1));
  });

  test('a period only counts what happened within it', () {
    final stars = [
      _star(1, DateTime(2026, 10, 2)),
      _star(2, DateTime(2026, 6, 2)),
      _star(3, DateTime(2025, 6, 2)),
    ];
    expect(_build(stars: stars).victories, hasLength(3));
    expect(
      _build(stars: stars, period: LightPeriod.year).victories,
      hasLength(2),
    );
    expect(
      _build(stars: stars, period: LightPeriod.month).victories,
      hasLength(1),
    );
  });

  test('check-in days light the calendar and count as days with light', () {
    final stats = _build(
      stars: [_star(1, DateTime(2026, 10, 1))],
      habits: [_habit(1), _habit(2)],
      completions: [
        _done(1, 1, DateTime(2026, 10, 1)),
        _done(2, 1, DateTime(2026, 10, 1)),
        _done(3, 2, DateTime(2026, 10, 1)),
        _done(4, 1, DateTime(2026, 10, 2)),
      ],
    );
    expect(stats.activeDays, {DateTime(2026, 10, 1), DateTime(2026, 10, 2)});
    // The victory and one per checked pulsar, however many check-ins.
    expect(stats.countsByDay[DateTime(2026, 10, 1)], 3);
    expect(stats.countsByDay[DateTime(2026, 10, 2)], 1);
  });

  test('the curve only grows and ends today', () {
    final stats = _build(
      stars: [
        _star(1, DateTime(2026, 10, 1), intensity: 2),
        _star(2, DateTime(2026, 10, 5), intensity: 3),
      ],
    );
    final totals = stats.cumulative.map((p) => p.total).toList();
    expect(totals, [0, 2, 5, 5]);
    expect(stats.cumulative.first.date, DateTime(2026, 9, 30));
    expect(stats.cumulative.last.date, DateTime(2026, 10, 14));
  });

  test('a pulsar curve counts its days done', () {
    final stats = _build(
      scope: const InsightEntity.habit(1),
      habits: [_habit(1)],
      completions: [
        _done(1, 1, DateTime(2026, 10, 1)),
        _done(2, 1, DateTime(2026, 10, 1)),
        _done(3, 1, DateTime(2026, 10, 3)),
      ],
    );
    expect(stats.daysDone, 2);
    expect(stats.cumulative.last.total, 2);
  });

  test('the breakdown goes one level down from the scope', () {
    final stars = [
      _star(1, DateTime(2026, 10, 1), project: 1, intensity: 2),
      _star(2, DateTime(2026, 10, 1), project: 2, intensity: 5),
      _star(3, DateTime(2026, 10, 1), project: 3, intensity: 1),
    ];
    final habits = [_habit(1, project: 1)];
    final cycles = [_cycle(1, 1, DateTime(2026, 10, 7), intensity: 4)];

    final all = _build(stars: stars, habits: habits, cycles: cycles);
    expect(all.breakdown.map((s) => (s.entity, s.light)), [
      (const InsightEntity.area(LifeArea.physical), 11),
      (const InsightEntity.area(LifeArea.social), 1),
    ]);

    final area = _build(
      scope: const InsightEntity.area(LifeArea.physical),
      stars: stars,
      habits: habits,
      cycles: cycles,
    );
    expect(area.light, 11);
    expect(area.breakdown.map((s) => (s.entity, s.light)), [
      (const InsightEntity.project(1), 6),
      (const InsightEntity.project(2), 5),
    ]);

    final project = _build(
      scope: const InsightEntity.project(1),
      stars: stars,
      habits: habits,
      cycles: cycles,
    );
    expect(project.breakdown.map((s) => (s.entity, s.light)), [
      (const InsightEntity.habit(1), 4),
      (const InsightEntity.star(1), 2),
    ]);
  });

  test('moments: first victory, brightest day and longest run', () {
    final stats = _build(
      stars: [
        _star(1, DateTime(2026, 9, 1), intensity: 1),
        _star(2, DateTime(2026, 9, 10), intensity: 5),
        _star(3, DateTime(2026, 9, 11), intensity: 2),
        _star(4, DateTime(2026, 9, 12), intensity: 2),
      ],
    );
    final moments = stats.moments;
    expect(moments.firstVictory?.id, 1);
    expect(moments.latestVictory?.id, 4);
    expect(moments.brightestDay, DateTime(2026, 9, 10));
    expect(moments.brightestDayLight, 5);
    expect(moments.longestRun?.length, 3);
    expect(moments.longestRun?.start, DateTime(2026, 9, 10));
    // Not enough days yet to name a favourite weekday.
    expect(moments.favouriteWeekday, isNull);
  });

  test('nothing done means no moments, never a "missed" state', () {
    final stats = _build();
    expect(stats.light, 0);
    expect(stats.moments.isEmpty, isTrue);
    expect(stats.breakdown, isEmpty);
  });
}
