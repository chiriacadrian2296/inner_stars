import 'package:inner_stars/widgets/search_result_card.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/constellation_screen.dart';
import 'package:inner_stars/screens/star_form_screen.dart';
import 'package:inner_stars/settings/settings_controller.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';
import 'package:inner_stars/widgets/constellation_painter.dart';
import 'package:inner_stars/widgets/entity_insights_scope.dart';
import 'package:inner_stars/widgets/sky_star_tooltip.dart';
import 'package:inner_stars/widgets/sky_pulsar_tooltip.dart';
import 'package:inner_stars/widgets/sky_nascent_star_tooltip.dart';

void main() {
  testWidgets(
    'map actions persist habit state, archive and configure the exact slot',
    (tester) async {
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
      final settings = SettingsController(await SettingsRepository.create());
      final shape = await shapes.add(
        name: 'Forma',
        shape: const ConstellationShape(
          points: [Offset(0.2, 0.2), Offset(0.5, 0.5), Offset(0.8, 0.8)],
          edges: [(0, 1), (1, 2)],
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
      await tester.pumpWidget(
        StringsScope(
          strings: const StringsIt(),
          child: TourScope(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: ConstellationScreen(
                project: project,
                starRepository: stars,
                projectRepository: projects,
                habitRepository: habits,
                habitCompletionRepository: completions,
                starsShapeRepository: shapes,
                settings: settings,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final vignette = find.byKey(const Key('constellation-edge-vignette'));
      expect(vignette, findsOneWidget);
      expect(tester.widget<IgnorePointer>(vignette).ignoring, isTrue);
      final sizeSlider = find.byKey(
        const Key('constellation-card-size-slider'),
      );
      expect(sizeSlider, findsOneWidget);
      expect(
        tester
            .widget<ConstellationMapView>(find.byType(ConstellationMapView))
            .tooltipScale,
        0.58,
      );
      final openingMap = tester.widget<ConstellationMapView>(
        find.byType(ConstellationMapView),
      );
      expect(
        openingMap.transformation.value.entry(0, 0) / openingMap.fitScale,
        closeTo(1.0, 0.001),
      );
      // Card size is the only choice left: the layout follows the screen
      // (side columns on a desktop) and its tabs always face the shape.
      expect(find.byType(Switch), findsNothing);
      expect(
        tester
            .widget<ConstellationMapView>(find.byType(ConstellationMapView))
            .cardLayout,
        ConstellationCardLayout.sideColumns,
      );
      tester.widget<Slider>(sizeSlider).onChanged!(3);
      await tester.pump();
      expect(settings.constellationCardSizeStep, 3);
      expect(
        tester
            .widget<ConstellationMapView>(find.byType(ConstellationMapView))
            .tooltipScale,
        0.72,
      );
      for (final (type, icon) in [
        (SkyStarTooltip, StarKind.unlit.icon),
        (SkyPulsarTooltip, StarKind.pulsar.icon),
        (SkyNascentStarTooltip, StarKind.nascent.icon),
      ]) {
        for (final element in find.byType(type).evaluate()) {
          expect(
            find.descendant(
              of: find.byWidget(element.widget),
              matching: find.byIcon(icon),
            ),
            // The card visual repeats the kind glyph beside the title row's.
            findsNWidgets(2),
          );
        }
      }
      expect(tester.widget<Text>(find.text('Obiettivo')).maxLines, 1);
      Finder action(Type tooltip, IconData icon) => find.descendant(
        of: find.descendant(
          of: find.byType(tooltip).first,
          matching: find.byKey(const Key('search-card-quick-menu')),
        ),
        matching: find.byIcon(icon),
      );
      Future<void> tap(Finder finder) async {
        if (find
            .ancestor(of: finder, matching: find.byType(ConstellationMapView))
            .evaluate()
            .isNotEmpty) {
          final map = tester.widget<ConstellationMapView>(
            find.byType(ConstellationMapView),
          );
          final delta =
              tester.getRect(find.byType(ConstellationMapView)).center -
              tester.getCenter(finder);
          final matrix = map.transformation.value.clone();
          matrix.setEntry(0, 3, matrix.entry(0, 3) + delta.dx);
          matrix.setEntry(1, 3, matrix.entry(1, 3) + delta.dy);
          map.transformation.value = matrix;
          await tester.pump();
        }
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 500));
      }

      void expectOpenDrawers(int count) {
        final cards = tester.widgetList<SearchResultCard>(
          find.byType(SearchResultCard),
        );
        expect(
          cards.where((card) => card.menuController.isOpen(card.menuId)),
          hasLength(count),
        );
      }

      // Selecting a card fades the others (and the rest of the structure).
      Iterable<Element> fadedCards() => find
          .ancestor(
            of: find.byType(SearchResultCard),
            matching: find.byWidgetPredicate(
              (w) => w is AnimatedOpacity && w.opacity == 0.32,
            ),
          )
          .evaluate();

      Finder toggle(Finder tooltip) => find.descendant(
        of: tooltip,
        matching: find.byKey(const Key('search-card-quick-menu-toggle')),
      );

      // An idle card is dimmed: select it first, then open its drawer.
      Future<void> openDrawer(Finder tooltip) async {
        await tap(tooltip);
        await tap(toggle(tooltip));
      }

      expectOpenDrawers(0);
      expect(
        tester
            .widget<ConstellationMapView>(find.byType(ConstellationMapView))
            .fadeStructureOnFocus,
        isTrue,
      );
      expect(
        tester
            .widget<ConstellationMapView>(find.byType(ConstellationMapView))
            .selectionEnabled,
        isTrue,
      );
      await tap(find.text('Obiettivo'));
      expect(find.byType(StarFormScreen), findsNothing);
      expect(fadedCards(), hasLength(3));
      await tap(find.text('Abitudine'));
      expect(fadedCards(), hasLength(3));
      await tester.tapAt(
        tester.getRect(find.byType(ConstellationMapView)).topLeft +
            const Offset(5, 5),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(fadedCards(), isEmpty);
      await openDrawer(find.byType(SkyPulsarTooltip));
      expectOpenDrawers(1);
      await tap(action(SkyPulsarTooltip, Icons.local_fire_department_rounded));
      expect(completions.getAllForHabit(habit.id), hasLength(1));
      await tap(action(SkyPulsarTooltip, Icons.local_fire_department_rounded));
      expect(completions.getAllForHabit(habit.id), isEmpty);
      await openDrawer(find.byType(SkyStarTooltip));
      expectOpenDrawers(1);
      final habitCard = tester.widget<SearchResultCard>(
        find.descendant(
          of: find.byType(SkyPulsarTooltip),
          matching: find.byType(SearchResultCard),
        ),
      );
      expect(habitCard.menuController.isOpen(habitCard.menuId), isFalse);
      await tap(action(SkyStarTooltip, Icons.delete_outline_rounded));
      await tap(find.text(const StringsIt().archiveAction.toUpperCase()));
      expect(stars.getAllForProject(project.id).single.dead, isTrue);
      expect(stars.getAllForProject(project.id).single.id, star.id);
      expect(action(SkyStarTooltip, Icons.model_training), findsOneWidget);
      expect(find.byType(SkyNascentStarTooltip), findsNWidgets(2));
      await openDrawer(find.byType(SkyNascentStarTooltip).first);
      expectOpenDrawers(1);
      await openDrawer(find.byType(SkyNascentStarTooltip).last);
      expectOpenDrawers(1);
      final firstNascent = tester.widget<SearchResultCard>(
        find.descendant(
          of: find.byType(SkyNascentStarTooltip).first,
          matching: find.byType(SearchResultCard),
        ),
      );
      expect(firstNascent.menuController.isOpen(firstNascent.menuId), isFalse);
      await openDrawer(find.byType(SkyNascentStarTooltip).first);
      await tap(action(SkyNascentStarTooltip, Icons.auto_awesome));
      final form = tester.widget<StarFormScreen>(find.byType(StarFormScreen));
      expect(form.slotSequence, 2);
      expect(form.lockedProject?.id, project.id);
      expect(form.allowPulsar, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 0.45]) {
    testWidgets(
      'real tooltip at scale $scale keeps drawer and flip interactive',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final insights = EntityInsightsController(
          projects: ProjectRepository(prefs),
          stars: StarRepository(prefs),
          habits: HabitRepository(prefs),
          completions: HabitCompletionRepository(prefs),
          shapes: StarsShapeRepository(prefs),
        );
        final camera = TransformationController(
          Matrix4.identity()..translateByDouble(300, 250, 0, 1),
        );
        addTearDown(camera.dispose);
        final star = Star(
          id: 1,
          projectId: 1,
          slotSequence: 1,
          title: 'Obiettivo',
          iconSlug: scale == 0.45 ? 'home' : '',
          createdAt: DateTime(2026),
        );
        var viewed = 0;
        var edited = 0;
        var lit = 0;
        var nodeTapped = 0;
        await tester.pumpWidget(
          StringsScope(
            strings: const StringsIt(),
            child: EntityInsightsScope(
              controller: insights,
              child: MaterialApp(
                theme: buildAppTheme(),
                home: Scaffold(
                  body: ConstellationMapView(
                    stars: const [
                      ConstellationStar(
                        entityId: 1,
                        position: Offset(0.5, 0.5),
                        kind: StarKind.unlit,
                        lit: false,
                        label: 'Obiettivo',
                        slotSequence: 1,
                      ),
                    ],
                    edges: const [],
                    transformation: camera,
                    canvasSize: const Size(500, 500),
                    fitScale: 1,
                    tooltipScale: scale,
                    onStarTap: (_) => nodeTapped++,
                    cardBuilder: (_, _) => SkyStarTooltip(
                      star: star,
                      project: null,
                      onClose: () {},
                      onView: () => viewed++,
                      onEdit: () => edited++,
                      onLight: () => lit++,
                      onShare: () {},
                      onDelete: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        void expectPlacementMatchesTooltip() {
          final placement = find.ancestor(
            of: find.byType(SkyStarTooltip),
            matching: find.byType(Positioned),
          );
          final frame = find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 8,
          );
          final allocated = tester.getRect(placement);
          final actual = tester.getRect(frame);
          expect(allocated.left, closeTo(actual.left, 0.01));
          expect(allocated.top, closeTo(actual.top, 0.01));
          expect(allocated.width, closeTo(actual.width, 0.01));
          expect(allocated.height, closeTo(actual.height, 0.01));
        }

        expectPlacementMatchesTooltip();
        expect(
          find.descendant(
            of: find.byType(SkyStarTooltip),
            matching: find.byIcon(
              scale == 0.45 ? Icons.home : StarKind.unlit.icon,
            ),
          ),
          findsOneWidget,
        );
        final body = find.byKey(const Key('search-result-card-body'));
        final surface = find.byKey(const Key('search-result-card-surface'));
        // Map-only tooltip: remove the 88 px visual column, keeping text space.
        expect(tester.getSize(body).width, 376);
        final render = tester.renderObject<RenderBox>(body);
        final visibleWidth =
            (render.localToGlobal(const Offset(376, 0)) -
                    render.localToGlobal(Offset.zero))
                .distance;
        expect(visibleWidth, closeTo(376 * scale, 0.01));
        final closedHeight = tester.getSize(surface).height;
        final toggle = find.byKey(const Key('search-card-quick-menu-toggle'));
        expect(find.byType(SearchStarVisual), findsNothing);
        final resultCard = tester.widget<SearchResultCard>(
          find.byType(SearchResultCard),
        );
        expect(resultCard.menuController.isOpen(resultCard.menuId), isFalse);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.color == tester.element(body).colors.night &&
                widget.elevation == 8,
          ),
          findsOneWidget,
        );
        final frame = tester.widget<Material>(
          find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 8,
          ),
        );
        final border = (frame.shape! as RoundedRectangleBorder).side;
        expect(border.width, 0.0);
        expect(border.style, BorderStyle.none);
        final ink = tester.widget<Ink>(body);
        expect(
          (ink.decoration! as BoxDecoration).color,
          tester.element(body).colors.nightPanel,
        );
        resultCard.menuController.toggle(resultCard.menuId);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(tester.getSize(surface).height, greaterThan(closedHeight));
        expect(tester.getSize(surface).height, lessThan(closedHeight + 50));
        expectPlacementMatchesTooltip();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        final openHeight = tester.getSize(surface).height;
        expect(openHeight, closedHeight + 50);
        expectPlacementMatchesTooltip();
        await tester.tap(find.byIcon(Icons.edit_rounded));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(edited, 1);
        expect(viewed, 0);
        expect(nodeTapped, 0);
        await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(lit, 1);
        resultCard.menuController.toggle(resultCard.menuId);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(tester.getSize(surface).height, greaterThan(closedHeight));
        expect(tester.getSize(surface).height, lessThan(openHeight));
        expectPlacementMatchesTooltip();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).height, openHeight - 50);
        expectPlacementMatchesTooltip();
        await tester.tap(toggle);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).height, openHeight);
        await tester.tap(find.byTooltip(const StringsIt().insightFlip));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byTooltip(const StringsIt().insightReturn), findsOneWidget);
        expectPlacementMatchesTooltip();
        // Panning must keep the same card state, including its back face.
        camera.value = camera.value.clone()..translateByDouble(20, 0, 0, 1);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byTooltip(const StringsIt().insightReturn), findsOneWidget);
        await tester.tap(find.byTooltip(const StringsIt().insightReturn));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        insights.dispose();
      },
    );
  }
}
