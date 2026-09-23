import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/reflection_answer_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_editor_painter.dart';
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
      ReflectionAnswerRepository reflections,
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
      reflections: ReflectionAnswerRepository(prefs),
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
      ReflectionAnswerRepository reflections,
    })
    repositories,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                onNavigateTo: (_) {},
                onModeLabelChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

    await tester.tap(find.byIcon(Icons.auto_awesome));
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
  });
}
