import 'package:inner_stars/widgets/activity_check_card.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_answer_repository.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/habit_completion.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/screens/entity_stats_screen.dart';
import 'package:inner_stars/screens/today_habits_screen.dart';
import 'package:inner_stars/screens/star_reader_screen.dart';
import 'package:inner_stars/screens/star_form_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/settings/settings_controller.dart';
import 'package:inner_stars/utils/entity_insights.dart';
import 'package:inner_stars/widgets/entity_flip_card.dart';
import 'package:inner_stars/widgets/entity_insights_scope.dart';
import 'package:inner_stars/widgets/grouped_action_layout.dart';
import 'package:inner_stars/widgets/sky_search_tooltip_card.dart';
import 'package:inner_stars/widgets/sky_explorer_view.dart';
import 'package:inner_stars/widgets/star_type_text.dart';
import 'package:inner_stars/widgets/stats/stats_widgets.dart';
import 'package:inner_stars/widgets/pill_action_button.dart';

final _now = DateTime(2026, 10, 12, 12);
Project _project(int id, LifeArea area) => Project(
  id: id,
  name: 'Project $id',
  area: area,
  iconSlug: 'star',
  createdAt: DateTime(2026, 1),
);
Habit _habit(
  int id, {
  int project = 1,
  int target = 1,
  bool dead = false,
  HabitFrequency frequency = HabitFrequency.daily,
  DateTime? created,
}) => Habit(
  id: id,
  projectId: project,
  title: 'Habit $id',
  createdAt: created ?? DateTime(2026, 9, 1),
  targetPerPeriod: target,
  frequency: frequency,
  dead: dead,
  deadDate: dead ? DateTime(2026, 9, 30) : null,
);
Star _star(int id, DateTime? achieved, {int project = 1, bool dead = false}) =>
    Star(
      id: id,
      projectId: project,
      slotSequence: id,
      title: 'Star $id',
      createdAt: DateTime(2026, 1),
      achievedDate: achieved,
      intensity: achieved == null ? null : 3,
      dead: dead,
      deadDate: dead ? DateTime(2026, 10, 1) : null,
    );

Future<EntityInsightsController> _controller({
  List<Star> stars = const [],
  List<Habit> habits = const [],
  List<HabitCompletion> completions = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'projects-list': jsonEncode([
      _project(1, LifeArea.physical).toJson(),
      _project(2, LifeArea.social).toJson(),
    ]),
    'stars-list-v1': jsonEncode(stars.map((s) => s.toJson()).toList()),
    'habits-list-v1': jsonEncode(habits.map((h) => h.toJson()).toList()),
    'habit-completions-list-v1': jsonEncode(
      completions.map((c) => c.toJson()).toList(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  return EntityInsightsController(
    projects: ProjectRepository(prefs),
    stars: StarRepository(prefs),
    habits: HabitRepository(prefs),
    completions: HabitCompletionRepository(prefs),
    shapes: StarsShapeRepository(prefs),
  );
}

EntityInsights _read(EntityInsightsController c, InsightEntity entity) =>
    EntityInsights.read(
      entity: entity,
      projects: c.projects,
      stars: c.stars,
      habits: c.habits,
      completions: c.completions,
      now: _now,
    );

Widget _app(
  EntityInsightsController c,
  Widget home, {
  TextScaler textScaler = TextScaler.noScaling,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: buildAppTheme(),
  builder: (context, child) => StringsScope(
    strings: StringsIt(),
    child: EntityInsightsScope(
      controller: c,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: textScaler, disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  ),
  home: home,
);

class _RejectingCompletions extends HabitCompletionRepository {
  _RejectingCompletions(super.prefs);
  @override
  Future<void> markDone(int habitId, {DateTime? date}) async {
    throw StateError('Storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('personal icons survive persistence, completion and archiving; legacy records keep defaults', () async {
    expect(Habit.fromJson(_habit(1).toJson()..remove('iconSlug')).iconSlug, '');
    expect(
      Star.fromJson(_star(1, null).toJson()..remove('iconSlug')).iconSlug,
      '',
    );
    final c = await _controller(
      stars: [_star(1, null).copyWith(iconSlug: 'park')],
      habits: [_habit(1).copyWith(iconSlug: 'fitness_center')],
    );
    addTearDown(c.dispose);
    expect(c.habits.getAll().single.iconSlug, 'fitness_center');
    await c.habits.update(
      id: 1,
      title: 'Habit 1',
      projectId: 1,
      iconSlug: 'eco',
    );
    await c.habits.delete(1);
    expect(c.habits.getAll().single.iconSlug, 'eco');
    await c.habits.resurrect(
      1,
      title: 'Habit 1',
      projectId: 1,
      completionRepository: c.completions,
    );
    expect(c.habits.getAll().single.iconSlug, 'eco');
    await c.stars.markAchieved(1, intensity: 4);
    expect(c.stars.getAll().single.iconSlug, 'park');
    await c.stars.delete(1);
    expect(c.stars.getAll().single.iconSlug, 'park');
    await c.habits.update(id: 1, title: 'Habit 1', projectId: 1, iconSlug: '');
    expect(c.habits.getAll().single.iconSlug, '');
  });

  testWidgets(
    'management switches scope-preserving lists and completes goals using the existing sheet',
    (tester) async {
      final c = await _controller(
        habits: [_habit(1).copyWith(iconSlug: 'fitness_center')],
        stars: [
          _star(1, null).copyWith(iconSlug: 'park'),
          _star(2, DateTime(2026, 9, 1)),
          _star(3, null, project: 2),
          _star(4, null, dead: true),
        ],
      );
      await tester.pumpWidget(
        _app(c, const TodayHabitsScreen(entity: InsightEntity.project(1))),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ActivityCheckCard>(find.byType(ActivityCheckCard)).icon,
        Icons.fitness_center,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(StringsIt().habitDoneTodayLabel), findsNothing);
      await tester.tap(find.byTooltip(StringsIt().manageGoals));
      await tester.pumpAndSettle();
      expect(find.text('Star 1'), findsOneWidget);
      expect(find.text('Star 3'), findsNothing);
      expect(find.text('Star 4'), findsNothing);
      expect(
        tester.widget<ActivityCheckCard>(find.byType(ActivityCheckCard)).icon,
        Icons.park,
      );
      final check = find.descendant(
        of: find.byKey(const ValueKey('s1')),
        matching: find.byType(IconButton),
      );
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.byType(MarkAchievedSheet), findsOneWidget);
      await tester.tap(find.text(StringsIt().cancel.toUpperCase()));
      await tester.pumpAndSettle();
      expect(c.stars.getAll().firstWhere((s) => s.id == 1).isUnlit, true);
      await tester.tap(check);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          ElevatedButton,
          StringsIt().markAchievedConfirm.toUpperCase(),
        ),
      );
      await tester.pumpAndSettle();
      final victory = c.stars.getAll().firstWhere((s) => s.id == 1);
      expect(victory.isLit, true);
      expect(victory.intensity, 3);
      expect(victory.iconSlug, 'park');
      expect(find.text(StringsIt().manageGoalsEmpty), findsOneWidget);
      await tester.tap(find.byTooltip(StringsIt().manageHabits));
      await tester.pumpAndSettle();
      expect(find.text('Habit 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'management card opens the existing reader; tooltip front opens scoped statistics',
    (tester) async {
      final c = await _controller(habits: [_habit(1)]);
      final tours = InMemoryTourStorage();
      await tours.markCompleted('star-reader');
      await tester.pumpWidget(
        TourScope(
          storage: tours,
          child: _app(
            c,
            const TodayHabitsScreen(entity: InsightEntity.project(1)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Habit 1'));
      await tester.pumpAndSettle();
      expect(find.byType(StarReaderScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        TourScope(
          storage: tours,
          child: _app(
            c,
            Scaffold(
              body: SizedBox(
                width: 340,
                child: SkySearchTooltipCard(
                  menuId: 'habit',
                  entity: const InsightEntity.habit(1),
                  visual: const Icon(Icons.restart_alt),
                  content: const Text('Habit'),
                  actions: const [],
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      expect(find.byType(EntityStatsScreen), findsOneWidget);
      expect(find.text('Habit 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'activity form selects a personal icon and returns it when saving',
    (tester) async {
      final c = await _controller(habits: [_habit(1)]);
      final tours = InMemoryTourStorage();
      await tours.markCompleted('star-form');
      StarFormResult? result;
      await tester.pumpWidget(
        TourScope(
          storage: tours,
          child: _app(
            c,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final saved = await Navigator.of(context).push<Object>(
                      MaterialPageRoute(
                        builder: (_) => StarFormScreen(
                          existingHabit: c.habits.getAll().single,
                          contextProject: c.projects.getAll().firstWhere(
                            (p) => p.id == 1,
                          ),
                          projectRepository: c.projects,
                          starsShapeRepository: c.shapes,
                          hideDelete: true,
                        ),
                      ),
                    );
                    if (saved is StarFormResult) result = saved;
                  },
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      final iconField = find.byKey(const ValueKey('activity-icon-field'));
      expect(iconField, findsOneWidget);
      await tester.ensureVisible(iconField);
      await tester.tap(iconField);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'fitness_center');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.fitness_center));
      await tester.pumpAndSettle();
      final save = find.byType(SaveActionButton);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(result?.iconSlug, 'fitness_center');
      expect(result?.kind, StarKind.pulsar);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  test('area and project counts exclude other scopes, archived and future victories', () async {
    final c = await _controller(
      stars: [
        _star(1, DateTime(2026, 9, 13)),
        _star(2, DateTime(2026, 9, 12)),
        _star(3, null),
        _star(4, _now, project: 2),
        _star(5, _now, dead: true),
        _star(6, DateTime(2026, 10, 13)),
      ],
      habits: [_habit(1), _habit(2, project: 2), _habit(3, dead: true)],
    );
    addTearDown(c.dispose);
    final area = _read(c, const InsightEntity.area(LifeArea.physical));
    expect(area.victories, 3);
    expect(area.recentVictories, 1);
    expect(area.goals, 1);
    expect(area.activeHabits.map((h) => h.id), [1]);
    expect(
      _read(c, const InsightEntity.project(1)).recentVictories,
      area.recentVictories,
    );
    expect(_read(c, const InsightEntity.project(2)).recentVictories, 1);
  });

  test(
    'today uses daily target and weekly day, rather than weekly lit status',
    () async {
      final day = DateTime(2026, 10, 12);
      final c = await _controller(
        habits: [
          _habit(1, target: 3),
          _habit(2, target: 5, frequency: HabitFrequency.weekly),
        ],
        completions: [
          HabitCompletion(id: 1, habitId: 1, date: day),
          HabitCompletion(id: 2, habitId: 1, date: day),
          HabitCompletion(id: 3, habitId: 2, date: day),
        ],
      );
      addTearDown(c.dispose);
      final data = _read(c, const InsightEntity.project(1));
      expect(data.todayCount(data.habits.firstWhere((h) => h.id == 1)), 2);
      expect(data.habitsDoneToday, 1);
      expect(data.doneToday(data.habits.firstWhere((h) => h.id == 2)), true);
    },
  );

  test('empty and future-only observations have no percentage; archived history remains', () async {
    final c = await _controller(
      habits: [
        _habit(1, created: DateTime(2027)),
        _habit(2, dead: true),
      ],
      completions: [
        HabitCompletion(id: 1, habitId: 2, date: DateTime(2026, 9, 29)),
      ],
    );
    addTearDown(c.dispose);
    expect(_read(c, const InsightEntity.project(2)).daysDone, isNull);
    expect(_read(c, const InsightEntity.habit(1)).daysDone, isNull);
    final archived = _read(c, const InsightEntity.habit(2));
    expect(archived.completions, hasLength(1));
    expect(
      archived.summary(archived.habits.single).trend.last.date,
      DateTime(2026, 9, 30),
    );
    expect(_read(c, const InsightEntity.star(99)).stars, isEmpty);
  });

  test('repository commits invalidate cached summaries and resume refreshes the day', () async {
    final c = await _controller(habits: [_habit(1)]);
    addTearDown(c.dispose);
    final old = c.read(const InsightEntity.project(1));
    expect(identical(old, c.read(const InsightEntity.project(1))), true);
    await c.completions.markDone(1);
    final updated = c.read(const InsightEntity.project(1));
    expect(identical(old, updated), false);
    expect(updated.habitsDoneToday, 1);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(identical(updated, c.read(const InsightEntity.project(1))), false);
  });

  testWidgets(
    'hold flips a small card, return restores tap, buttons open scoped pages',
    (tester) async {
      final c = await _controller();
      var flipped = false;
      var opened = 0;
      await tester.pumpWidget(
        _app(
          c,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 90,
                height: 135,
                child: StatefulBuilder(
                  builder: (context, setState) => EntityFlipCard(
                    entity: const InsightEntity.project(1),
                    flipped: flipped,
                    onFlip: () => setState(() => flipped = !flipped),
                    front: TextButton(
                      onPressed: () => opened++,
                      child: const Text('Front'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Front'));
      expect(opened, 1);
      await tester.longPress(find.text('Front'));
      await tester.pumpAndSettle();
      expect(flipped, true);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(StringsIt().statsTitle));
      await tester.pumpAndSettle();
      expect(find.byType(EntityStatsScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(StringsIt().manageHabits));
      await tester.pumpAndSettle();
      expect(find.byType(TodayHabitsScreen), findsOneWidget);
      expect(find.text(StringsIt().insightNoHabits), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(StringsIt().insightReturn));
      await tester.pumpAndSettle();
      expect(find.text('Front'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'minimum card handles large type and reduced motion; flip is keyboard accessible',
    (tester) async {
      final c = await _controller();
      var flipped = false;
      await tester.pumpWidget(
        _app(
          c,
          Scaffold(
            body: SizedBox(
              width: 65,
              height: 98,
              child: StatefulBuilder(
                builder: (context, setState) => EntityFlipCard(
                  entity: const InsightEntity.project(1),
                  flipped: flipped,
                  onFlip: () => setState(() => flipped = !flipped),
                  front: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
          textScaler: TextScaler.linear(3),
          reduceMotion: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(flipped, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'today list preserves rows and supports binary, multiple and weekly corrections',
    (tester) async {
      final c = await _controller(
        habits: [
          _habit(1),
          _habit(2, target: 3),
          _habit(3, target: 4, frequency: HabitFrequency.weekly),
        ],
      );
      await tester.pumpWidget(
        _app(c, const TodayHabitsScreen(entity: InsightEntity.project(1))),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('p1')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.read(const InsightEntity.project(1)).habitsDoneToday, 1);
      expect(find.text('Habit 1'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('p2')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-stepper-plus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-stepper-save')));
      await tester.pumpAndSettle();
      expect(c.completions.getAllForHabit(2), hasLength(1));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('p2')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-stepper-minus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-stepper-save')));
      await tester.pumpAndSettle();
      expect(c.completions.getAllForHabit(2), isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('p3')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.completions.getAllForHabit(3), hasLength(1));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('p3')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.completions.getAllForHabit(3), isEmpty);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'failed save leaves today unchecked and reports a retryable error',
    (tester) async {
      final initial = await _controller(habits: [_habit(1)]);
      final prefs = await SharedPreferences.getInstance();
      final c = EntityInsightsController(
        projects: initial.projects,
        stars: initial.stars,
        habits: initial.habits,
        completions: _RejectingCompletions(prefs),
        shapes: initial.shapes,
      );
      initial.dispose();
      await tester.pumpWidget(
        _app(c, const TodayHabitsScreen(entity: InsightEntity.project(1))),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('p1')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ActivityCheckCard>(find.byType(ActivityCheckCard)).lit,
        false,
      );
      expect(c.completions.getAllForHabit(1), isEmpty);
      expect(find.text(StringsIt().insightSaveError), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'archived statistics retain original type and habit history; stars have no artificial charts',
    (tester) async {
      final c = await _controller(
        stars: [_star(1, DateTime(2026, 9, 29), dead: true)],
        habits: [_habit(2, dead: true)],
        completions: [
          HabitCompletion(id: 1, habitId: 2, date: DateTime(2026, 9, 29)),
        ],
      );
      await tester.pumpWidget(
        _app(c, const EntityStatsScreen(entity: InsightEntity.star(1))),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<StarTypeText>(find.byType(StarTypeText)).originalKind,
        StarKind.lit,
      );
      expect(find.byType(HeatmapPanel), findsNothing);
      expect(find.text(StringsIt().insightArchived), findsOneWidget);
      await tester.pumpWidget(
        _app(
          c,
          const EntityStatsScreen(
            key: ValueKey('habit'),
            entity: InsightEntity.habit(2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<StarTypeText>(find.byType(StarTypeText)).originalKind,
        StarKind.pulsar,
      );
      expect(find.byType(HeatmapPanel), findsOneWidget);
      expect(c.read(const InsightEntity.habit(2)).completions, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'tooltip rotates on X, grows within viewport and resets for another entity',
    (tester) async {
      final c = await _controller();
      var id = 1;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          c,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return SkySearchTooltipCard(
                      menuId: id,
                      entity: InsightEntity.project(id),
                      visual: const Icon(Icons.star),
                      content: const Text('Title'),
                      actions: const [],
                      onTap: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final frontHeight = tester
          .getSize(find.byType(SkySearchTooltipCard))
          .height;
      await tester.tap(find.byTooltip(StringsIt().insightFlip));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SkySearchTooltipCard)).height,
        greaterThanOrEqualTo(frontHeight),
      );
      expect(
        tester.getRect(find.byType(SkySearchTooltipCard)).bottom,
        lessThanOrEqualTo(600),
      );
      expect(
        tester.widget<EntityFlipCard>(find.byType(EntityFlipCard)).axis,
        Axis.horizontal,
      );
      update(() => id = 2);
      await tester.pumpAndSettle();
      expect(find.byTooltip(StringsIt().insightFlip), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('white group dots disappear across wrapped rows', (tester) async {
    Future<void> layout(double width) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: const GroupedActionLayout(
              groups: [0, 1, 1, 2],
              children: [
                SizedBox(width: 34, height: 34),
                SizedBox(width: 34, height: 34),
                SizedBox(width: 34, height: 34),
                SizedBox(width: 34, height: 34),
              ],
            ),
          ),
        ),
      ),
    );
    await layout(220);
    final wide = tester.renderObject<RenderGroupedActions>(
      find.byType(GroupedActionLayout),
    );
    expect(wide.separators, hasLength(2));
    expect(wide.separators.first.width, 4);
    expect(wide.separators.first.height, 4);
    await layout(40);
    final narrow = tester.renderObject<RenderGroupedActions>(
      find.byType(GroupedActionLayout),
    );
    expect(narrow.separators, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Sky grid keeps one back open, updates after writes and resets on search',
    (tester) async {
      if (const bool.fromEnvironment('INSIGHTS_PREVIEW')) {
        await tester.runAsync(() async {
          for (final font in {
            'Instrument Sans': 'assets/fonts/InstrumentSans-Variable.ttf',
            'Newsreader': 'assets/fonts/Newsreader-Variable.ttf',
            'Fragment Mono': 'assets/fonts/FragmentMono-Regular.ttf',
            'Gloock': 'assets/fonts/Gloock-Regular.ttf',
          }.entries) {
            await ui.loadFontFromList(
              await File(font.value).readAsBytes(),
              fontFamily: font.key,
            );
          }
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await _controller(habits: [_habit(1)]);
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsController(SettingsRepository(prefs));
      final tours = InMemoryTourStorage();
      await tours.markCompleted('search-stars');
      final boundary = GlobalKey();
      await tester.pumpWidget(
        TourScope(
          storage: tours,
          child: _app(
            c,
            RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: SkyExplorerView(
                  projectRepository: c.projects,
                  starRepository: c.stars,
                  habitRepository: c.habits,
                  habitCompletionRepository: c.completions,
                  starsShapeRepository: c.shapes,
                  areaVisionRepository: AreaVisionRepository(prefs),
                  reflectionAnswerRepository: ReflectionAnswerRepository(prefs),
                  settings: settings,
                  session: SkyExplorerSession()..modeIndex = 1,
                  onNavigateTo: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(StringsIt().insightFlip).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip(StringsIt().insightReturn), findsOneWidget);
      await c.completions.markDone(1);
      await tester.pumpAndSettle();
      expect(find.byTooltip(StringsIt().insightReturn), findsOneWidget);
      expect(c.read(const InsightEntity.project(1)).habitsDoneToday, 1);
      if (const bool.fromEnvironment('INSIGHTS_PREVIEW')) {
        final image = await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return bytes!;
        });
        await tester.runAsync(() async {
          await Directory('build/insights-preview').create(recursive: true);
          await File('build/insights-preview/sky-grid.png')
              .writeAsBytes(image!.buffer.asUint8List());
        });
      }
      await tester.tap(find.byTooltip(StringsIt().insightFlip));
      await tester.pumpAndSettle();
      expect(find.byTooltip(StringsIt().insightReturn), findsOneWidget);
      expect(
        tester
            .widgetList<EntityFlipCard>(find.byType(EntityFlipCard))
            .where((card) => card.flipped),
        hasLength(1),
      );
      await tester.enterText(find.byType(TextField).first, 'Project');
      await tester.pumpAndSettle();
      expect(find.byTooltip(StringsIt().insightReturn), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      c.dispose();
    },
  );
}
