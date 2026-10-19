import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/settings/settings_controller.dart';
import 'package:inner_stars/settings/sky_grid_size.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_editor_painter.dart';
import 'package:inner_stars/widgets/filter_button.dart';
import 'package:inner_stars/widgets/filters_trigger_button.dart';
import 'package:inner_stars/widgets/search_result_card.dart';
import 'package:inner_stars/widgets/sky_explorer_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<
    ({
      ProjectRepository projects,
      StarRepository stars,
      HabitRepository habits,
      HabitCompletionRepository completions,
      StarsShapeRepository shapes,
      AreaVisionRepository visions,
      ReflectionRepository reflections,
    })
  >
  repositories() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return (
      projects: ProjectRepository(prefs),
      stars: StarRepository(prefs),
      habits: HabitRepository(prefs),
      completions: HabitCompletionRepository(prefs),
      shapes: StarsShapeRepository(prefs),
      visions: AreaVisionRepository(prefs),
      reflections: ReflectionRepository(prefs),
    );
  }

  Future<void> pumpExplorer(
    WidgetTester tester,
    ({
      ProjectRepository projects,
      StarRepository stars,
      HabitRepository habits,
      HabitCompletionRepository completions,
      StarsShapeRepository shapes,
      AreaVisionRepository visions,
      ReflectionRepository reflections,
    })
    repositories, {
    SkyExplorerSession? session,
    SkyDayContext? dayContext,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    final tourStorage = InMemoryTourStorage();
    await tourStorage.markCompleted('search-stars');
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: TourScope(
          storage: tourStorage,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SkyExplorerView(
                projectRepository: repositories.projects,
                starRepository: repositories.stars,
                habitRepository: repositories.habits,
                habitCompletionRepository: repositories.completions,
                starsShapeRepository: repositories.shapes,
                areaVisionRepository: repositories.visions,
                reflectionAnswerRepository: repositories.reflections,
                settings: settings,
                session: session,
                dayContext: dayContext,
                onNavigateTo: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Statistics day reuses Sky and only shows that day', (
    tester,
  ) async {
    final repos = await repositories();
    final project = await repos.projects.add(
      name: 'Costellazione giorno',
      area: LifeArea.personal,
      iconSlug: 'star',
    );
    await repos.stars.add(
      title: 'Vittoria del giorno',
      projectId: project.id,
      achievedDate: DateTime(2026, 10, 15),
      intensity: 4,
    );
    await repos.stars.add(
      title: 'Vittoria di ieri',
      projectId: project.id,
      achievedDate: DateTime(2026, 10, 14),
      intensity: 3,
    );
    final habit = await repos.habits.add(
      title: 'Pulsar del giorno',
      projectId: project.id,
    );
    await repos.completions.markDone(habit.id, date: DateTime(2026, 10, 15));
    final session = SkyExplorerSession()..modeIndex = 2;

    await pumpExplorer(
      tester,
      repos,
      session: session,
      dayContext: SkyDayContext(day: DateTime(2026, 10, 15)),
    );

    expect(find.text('Vittoria del giorno'), findsOneWidget);
    expect(find.text('Pulsar del giorno'), findsOneWidget);
    expect(find.text('Vittoria di ieri'), findsNothing);
    expect(find.byType(AnimatedToggleSwitch), findsNothing);
    final filters = find.byType(FiltersTriggerButton);
    expect(filters, findsOneWidget);
    expect(tester.widget<FiltersTriggerButton>(filters).active, isFalse);
    expect(find.byKey(const Key('sky-primary-action')), findsOneWidget);
  });

  testWidgets('real Search closes an open quick menu when results scroll', (
    tester,
  ) async {
    final repos = await repositories();
    await pumpExplorer(tester, repos);

    final firstCard = find.byType(SearchResultCard).first;
    final firstSurface = find.descendant(
      of: firstCard,
      matching: find.byKey(const Key('search-result-card-surface')),
    );
    final firstToggle = find.descendant(
      of: firstCard,
      matching: find.byKey(const Key('search-card-quick-menu-toggle')),
    );
    expect(tester.getSize(firstSurface).height, 88);

    await tester.tap(firstToggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(firstSurface).height, 138);

    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(tester.getSize(firstSurface).height, 88);
    expect(tester.takeException(), isNull);
  }, skip: !kShowSkyListView);

  testWidgets('Sky reveals back to top and moves it beside the footer mark', (
    tester,
  ) async {
    final repos = await repositories();
    final session = SkyExplorerSession();
    await pumpExplorer(tester, repos, session: session);
    tester.view.physicalSize = const Size(390, 400);
    await tester.pumpAndSettle();

    final hitRegion = find.byKey(const Key('sky-back-to-top-hit-region'));
    final position = find.byKey(const Key('sky-back-to-top-position'));
    final scrollView = find.byType(CustomScrollView);
    expect(tester.widget<IgnorePointer>(hitRegion).ignoring, isTrue);

    await tester.drag(scrollView, const Offset(0, -270));
    await tester.pumpAndSettle();
    expect(session.scrollOffsets[0], greaterThanOrEqualTo(240));
    expect(tester.widget<AnimatedAlign>(position).alignment, Alignment.center);

    await tester.fling(scrollView, const Offset(0, -1000), 3000);
    await tester.pumpAndSettle();
    expect(session.scrollOffsets[0], greaterThan(240));
    expect(tester.widget<IgnorePointer>(hitRegion).ignoring, isFalse);
    expect(
      tester.widget<AnimatedAlign>(position).alignment,
      Alignment.centerLeft,
    );
    final button = find.byKey(const Key('sky-back-to-top-button'));
    expect(tester.getSize(button), const Size.square(32));
    final buttonMaterial = find
        .ancestor(of: button, matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(buttonMaterial).color, AppColors.dark.gold);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: button,
              matching: find.byIcon(Icons.keyboard_arrow_up),
            ),
          )
          .color,
      AppColors.dark.onGold,
    );
    for (final key in const [
      Key('sky-back-to-top-shadow'),
      Key('sky-primary-action-shadow'),
    ]) {
      final decoration =
          tester.widget<DecoratedBox>(find.byKey(key)).decoration
              as BoxDecoration;
      expect(decoration.boxShadow, hasLength(1));
      expect(
        decoration.boxShadow!.single.color,
        AppColors.dark.night.withValues(alpha: 0.9),
      );
    }
    expect(tester.getTopLeft(button).dx, closeTo(20, 0.1));
    expect(
      tester.getCenter(button).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('sky-primary-action'))).dy,
        0.1,
      ),
    );
    expect(
      tester.getCenter(find.byKey(const Key('app-footer-mark-unit'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('sky-primary-action'))).dy,
        0.5,
      ),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget<IgnorePointer>(hitRegion).ignoring, isTrue);
  });

  testWidgets('area cards expose their dock actions in the quick menu', (
    tester,
  ) async {
    final repos = await repositories();
    await pumpExplorer(tester, repos);

    final firstCard = find.byType(SearchResultCard).first;
    await tester.tap(
      find.descendant(
        of: firstCard,
        matching: find.byKey(const Key('search-card-quick-menu-toggle')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: firstCard, matching: find.text('VISION')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstCard, matching: find.text('MOODBOARD')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstCard, matching: find.text('RIFLESSIONI')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstCard, matching: find.text('+ COSTELLAZIONE')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstCard, matching: find.text('VOLA')),
      findsOneWidget,
    );
  }, skip: !kShowSkyListView);

  testWidgets('Sky controls center section titles and the sort control', (
    tester,
  ) async {
    final repos = await repositories();
    await pumpExplorer(tester, repos);

    await tester.tap(find.byIcon(Icons.insights).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(const StringsIt().filtersAction));
    await tester.pumpAndSettle();

    final sheetCenter = tester.getCenter(find.byType(BottomSheet)).dx;
    expect(
      tester.getCenter(find.text(const StringsIt().filtersAction)).dx,
      closeTo(sheetCenter, 0.5),
    );
    expect(
      tester.getCenter(find.text(const StringsIt().sortAction)).dx,
      closeTo(sheetCenter, 0.5),
    );
    final sortControl = find.ancestor(
      of: find.text('ORDINA'),
      matching: find.byType(FilterButton),
    );
    expect(tester.getCenter(sortControl).dx, closeTo(sheetCenter, 0.5));
  });

  testWidgets('real Search uses compact cards in all three result levels', (
    tester,
  ) async {
    final repos = await repositories();
    const shape = ConstellationShape(
      points: [Offset(0.1, 0.2), Offset(0.5, 0.8), Offset(0.9, 0.25)],
      edges: [(0, 1), (1, 2)],
    );
    final savedShape = await repos.shapes.add(name: 'Triangolo', shape: shape);
    final project = await repos.projects.add(
      name: 'Costellazione test',
      area: LifeArea.personal,
      iconSlug: 'star',
      starsShapeId: savedShape.id,
    );
    await repos.stars.add(
      title: 'Vittoria test',
      description: 'Questo estratto contiene la parola speciale.',
      projectId: project.id,
      achievedDate: DateTime(2026, 9, 20),
      intensity: 4,
    );
    await repos.stars.add(
      title: 'Obiettivo test',
      projectId: project.id,
      targetDate: DateTime(2026, 10, 1),
    );
    await repos.habits.add(title: 'Pulsar test', projectId: project.id);
    await pumpExplorer(tester, repos);

    expect(find.byType(SearchResultCard), findsWidgets);

    await tester.tap(find.byIcon(Icons.insights).first);
    await tester.pumpAndSettle();
    expect(find.text('Costellazione test'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is ConstellationEditorPainter,
      ),
      findsOneWidget,
    );

    final constellationCard = find.byType(SearchResultCard).first;
    await tester.tap(
      find.descendant(
        of: constellationCard,
        matching: find.byKey(const Key('search-card-quick-menu-toggle')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+ STELLA'), findsOneWidget);
    expect(find.text('CONDIVIDI'), findsOneWidget);
    expect(find.text('VOLA'), findsOneWidget);
    expect(find.text('MODIFICA'), findsOneWidget);
    expect(find.text('ELIMINA'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: constellationCard,
        matching: find.byKey(const Key('search-card-quick-menu-toggle')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star).first);
    await tester.pumpAndSettle();
    expect(find.text('Vittoria test'), findsOneWidget);
    expect(find.text('Obiettivo test'), findsOneWidget);
    expect(find.text('Pulsar test'), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'speciale');
    await tester.pumpAndSettle();
    expect(
      find.text('“Questo estratto contiene la parola speciale.”'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, skip: !kShowSkyListView);
}
