import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/settings/settings_controller.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/constellation_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/system_bars.dart';
import 'package:inner_stars/widgets/balanced_title.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';

void main() {
  /// Opens a three-star constellation on a phone-sized screen and returns
  /// the on-screen size of its first star.
  Future<Size> open(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final projects = ProjectRepository(prefs);
    final stars = StarRepository(prefs);
    final shapes = StarsShapeRepository(prefs);
    final shape = await shapes.add(
      name: 'Forma',
      shape: const ConstellationShape(
        points: [Offset(0.2, 0.2), Offset(0.5, 0.5), Offset(0.8, 0.3)],
        edges: [(0, 1), (1, 2)],
      ),
    );
    final project = await projects.add(
      name: 'Casa nuova',
      area: LifeArea.values.first,
      iconSlug: '',
      starsShapeId: shape.id,
    );
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
              habitRepository: HabitRepository(prefs),
              habitCompletionRepository: HabitCompletionRepository(prefs),
              starsShapeRepository: shapes,
              settings: SettingsController(await SettingsRepository.create()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final star = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_StarButton',
    );
    return tester.getSize(star.first);
  }

  testWidgets('a phone on its side keeps the upright proportions', (
    tester,
  ) async {
    final upright = await open(tester, const Size(390, 844));
    // Drawn twice: the outline and the fill.
    expect(find.text('SWIPE'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());

    final sideways = await open(tester, const Size(844, 390));
    // Stars are drawn at the same size whichever way the phone is held.
    expect(sideways.width, closeTo(upright.width, 0.5));
    // The short map has no room for the swipe bar; the arrows remain.
    expect(find.text('SWIPE'), findsNothing);
    // The title has the full width now, so a short one stays on one line.
    final title = tester.getSize(find.byType(BalancedTitle));
    expect(title.height, lessThan(20 * 1.25 * 1.5));
    // With the system bars hidden, the header's arrows are as far from the
    // top as the dock's buttons are from the bottom.
    final arrowTop = tester
        .getRect(
          find.ancestor(
            of: find.byIcon(Icons.chevron_left),
            matching: find.byType(IconButton),
          ),
        )
        .top;
    final buttonBottom = tester.getRect(find.byTooltip('Elimina')).bottom;
    expect(arrowTop, closeTo(390 - buttonBottom, 0.5));
    // Arrows stand at the ends of a phone-wide column, as on the web,
    // leaving the title room to grow.
    final left = tester.getRect(find.byIcon(Icons.chevron_left));
    final right = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(right.left - left.right, greaterThan(300));
    // Drawn slim, each arrow still answers a thumb-sized square around it,
    // from the screen's top edge down.
    for (final (zone, arrow) in [
      ('constellation-previous-zone', left),
      ('constellation-next-zone', right),
    ]) {
      final rect = tester.getRect(find.byKey(Key(zone)));
      expect(rect.size, const Size(48, 48));
      expect(rect.top, 0);
      expect(rect.contains(arrow.center), isTrue);
    }
    // The slim header leaves the short screen to the map; the rotation
    // glyph floats over the map rather than adding to it.
    expect(tester.getRect(find.byType(ConstellationMapView)).top, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the size rail and the rotation glyph follow the phone', (
    tester,
  ) async {
    final control = find.byKey(const Key('constellation-card-size-control'));
    final slider = find.byKey(const Key('constellation-card-size-slider'));
    final hint = find.byKey(const Key('constellation-rotate-hint'));

    for (final (screen, message) in [
      (const Size(390, 844), const StringsIt().constellationRotateHint),
      (const Size(844, 390), const StringsIt().constellationRotateBackHint),
    ]) {
      await open(tester, screen);
      // Either way up: a vertical rail on the right edge, centred on the
      // map's height, between a large and a small card glyph.
      final rail = tester.getRect(slider);
      expect(rail.height, greaterThan(rail.width));
      expect(rail.right, greaterThan(screen.width - 40));
      final map = tester.getRect(find.byType(ConstellationMapView));
      expect(rail.center.dy, closeTo(map.center.dy, 1));
      expect(
        find.descendant(
          of: control,
          matching: find.byIcon(Icons.crop_portrait),
        ),
        findsNWidgets(2),
      );
      // Just a glyph, centred at the top of the map - over its vignette,
      // not in the header; its words say which way to turn: to the side
      // cards, or back upright to leave them.
      final glyph = tester.getRect(hint);
      expect(glyph.center.dx, closeTo(map.center.dx, 1));
      expect(glyph.top, greaterThanOrEqualTo(map.top));
      expect(glyph.bottom, lessThan(map.top + 30));
      expect(tester.widget<Tooltip>(hint).message, message);
      expect(find.text(message), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('sideways hides the system bars until the screen is left', (
    tester,
  ) async {
    SystemBars.reset();
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await open(tester, const Size(844, 390));
    expect(modes, [SystemUiMode.immersiveSticky.toString()]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(modes.last, SystemUiMode.edgeToEdge.toString());
  });
}
