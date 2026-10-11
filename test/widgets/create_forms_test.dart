import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/new_project_screen.dart';
import 'package:inner_stars/screens/star_form_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/form_kind_tiles.dart';
import 'package:inner_stars/widgets/app_field.dart';
import 'package:inner_stars/widgets/filters_trigger_button.dart';
import 'package:inner_stars/utils/app_modals.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget Function() home) async {
  final tourStorage = InMemoryTourStorage();
  await tourStorage.markCompleted('constellation-form');
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    StringsScope(
      strings: const StringsEn(),
      child: TourScope(
        storage: tourStorage,
        child: MaterialApp(theme: buildAppTheme(), home: home()),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  late ProjectRepository projects;
  late StarsShapeRepository shapes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    projects = ProjectRepository(prefs);
    shapes = StarsShapeRepository(prefs);
  });

  testWidgets('constellation form lays out on its own', (tester) async {
    await _pump(
      tester,
      () => NewProjectScreen(
        projectRepository: projects,
        starsShapeRepository: shapes,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Constellation'), findsWidgets);
  });

  testWidgets('star form switches to the constellation tile and back', (
    tester,
  ) async {
    await _pump(
      tester,
      () => StarFormScreen(
        projectRepository: projects,
        starsShapeRepository: shapes,
        allowConstellation: true,
      ),
    );
    expect(tester.takeException(), isNull, reason: 'star form');

    await tester.tap(
      find.descendant(
        of: find.byType(FormKindTiles),
        matching: find.text('Constellation'),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull, reason: 'constellation tile');
    expect(find.byType(NewProjectScreen), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(FormKindTiles),
        matching: find.text('Goal'),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull, reason: 'back to a star');
  });

  for (final icons in [false, true]) {
    testWidgets(
      '${icons ? "icon" : "shape"} category filter combines with search and resets',
      (tester) async {
        await _pump(
          tester,
          () => NewProjectScreen(
            projectRepository: projects,
            starsShapeRepository: shapes,
          ),
        );
        final picker = icons
            ? find.byWidgetPredicate(
                (widget) => widget is AppPickerField && widget.iconOnly,
              )
            : find.ancestor(
                of: find.byIcon(Icons.draw_outlined),
                matching: find.byType(TextButton),
              );
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.text('Nature'), findsOneWidget);
        expect(find.text('Animals'), findsOneWidget);

        await tester.tap(find.byType(FiltersTriggerButton));
        await tester.pumpAndSettle();
        expect(find.text('Categories'), findsOneWidget);
        await tester.tap(find.widgetWithText(AppSheetAction, 'Animals'));
        await tester.pumpAndSettle();
        expect(find.text('Nature'), findsNothing);
        expect(find.text('Dog'), findsOneWidget);
        expect(
          tester
              .widget<FiltersTriggerButton>(find.byType(FiltersTriggerButton))
              .active,
          isTrue,
        );

        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.text('Nature'), findsNothing);
        expect(find.text('Dog'), findsOneWidget);
        expect(
          tester
              .widget<FiltersTriggerButton>(find.byType(FiltersTriggerButton))
              .active,
          isTrue,
        );

        final search = find.descendant(
          of: find.byType(AppSearchField),
          matching: find.byType(TextField),
        );
        await tester.enterText(search, 'Dog');
        await tester.pumpAndSettle();
        expect(find.text('Dog'), findsWidgets);
        expect(find.text('Bird'), findsNothing);
        await tester.enterText(search, 'Tree');
        await tester.pumpAndSettle();
        expect(find.text(const StringsEn().noSearchResults), findsOneWidget);

        await tester.tap(find.byType(FiltersTriggerButton));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            ElevatedButton,
            const StringsEn().clearFilterAction.toUpperCase(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Nature'), findsOneWidget);
        expect(
          tester
              .widget<FiltersTriggerButton>(find.byType(FiltersTriggerButton))
              .active,
          isFalse,
        );
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
