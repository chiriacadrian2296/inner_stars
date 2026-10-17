import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/reader_entries.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/constellation_screen.dart';
import 'package:inner_stars/screens/star_reader_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';
import 'package:inner_stars/widgets/sky_navigation_target.dart';
import 'package:inner_stars/widgets/sky_star_tooltip.dart';
import 'package:inner_stars/widgets/sky_pulsar_tooltip.dart';
import 'package:inner_stars/widgets/sky_nascent_star_tooltip.dart';

void main() {
  for (final kind in ['star', 'habit', 'nascent']) {
    testWidgets('map drawer views and flies to the exact $kind', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final projects = ProjectRepository(prefs);
      final stars = StarRepository(prefs);
      final habits = HabitRepository(prefs);
      final completions = HabitCompletionRepository(prefs);
      final shapes = StarsShapeRepository(prefs);
      final shape = await shapes.add(
        name: 'Forma',
        shape: const ConstellationShape(
          points: [Offset(0.2, 0.2), Offset(0.8, 0.8)],
          edges: [(0, 1)],
        ),
      );
      final project = await projects.add(
        name: 'Progetto',
        area: LifeArea.values.first,
        iconSlug: '',
        starsShapeId: shape.id,
      );
      final star = await stars.add(
        title: 'Obiettivo',
        projectId: project.id,
        slotSequence: 1,
      );
      final habit = await habits.add(title: 'Abitudine', projectId: project.id);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        StringsScope(
          strings: const StringsIt(),
          child: TourScope(
            child: MaterialApp(
              navigatorKey: nav,
              theme: buildAppTheme(),
              home: const Scaffold(),
            ),
          ),
        ),
      );
      final result = nav.currentState!.push<Object>(
        MaterialPageRoute(
          builder: (_) => ConstellationScreen(
            project: project,
            starRepository: stars,
            projectRepository: projects,
            habitRepository: habits,
            habitCompletionRepository: completions,
            starsShapeRepository: shapes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      final type = switch (kind) {
        'star' => SkyStarTooltip,
        'habit' => SkyPulsarTooltip,
        _ => SkyNascentStarTooltip,
      };
      final tooltip = find.byType(type);
      Future<void> tap(Finder target) async {
        final map = tester.widget<ConstellationMapView>(
          find.byType(ConstellationMapView),
        );
        final delta =
            tester.getRect(find.byType(ConstellationMapView)).center -
            tester.getCenter(target);
        final camera = map.transformation.value.clone();
        camera.setEntry(0, 3, camera.entry(0, 3) + delta.dx);
        camera.setEntry(1, 3, camera.entry(1, 3) + delta.dy);
        map.transformation.value = camera;
        await tester.pump();
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }

      Finder action(IconData icon) =>
          find.descendant(of: tooltip, matching: find.byIcon(icon));
      // An idle grid card is dimmed; the first tap selects it.
      await tap(tooltip);
      await tap(
        find.descendant(
          of: tooltip,
          matching: find.byKey(const Key('search-card-quick-menu-toggle')),
        ),
      );
      await tap(action(Icons.open_in_new_rounded));
      final reader = tester.widget<StarReaderScreen>(
        find.byType(StarReaderScreen),
      );
      final expectedKey = switch (kind) {
        'star' => 's${star.id}',
        'habit' => 'p${habit.id}',
        _ => NascentEntry(projectId: project.id, slot: 2).key,
      };
      expect(reader.initialEntries![reader.startIndex].key, expectedKey);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tap(action(Icons.navigation));
      final target = await result as SkyStarTarget;
      expect(target.project.id, project.id);
      expect(target.starId, kind == 'star' ? star.id : null);
      expect(target.habitId, kind == 'habit' ? habit.id : null);
      expect(target.nascentSlot, kind == 'nascent' ? 2 : null);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
