import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/new_project_screen.dart';
import 'package:inner_stars/screens/star_form_screen.dart';
import 'package:inner_stars/theme/app_style.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/form_kind_tiles.dart';
import 'package:inner_stars/widgets/staggered_entrance.dart';
import 'package:inner_stars/widgets/app_field.dart';
import 'package:inner_stars/widgets/filters_trigger_button.dart';
import 'package:inner_stars/utils/app_modals.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget Function() home) async {
  final tourStorage = InMemoryTourStorage();
  await tourStorage.markCompleted('constellation-form');
  await tourStorage.markCompleted('star-form');
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
    expect(find.text('Project'), findsWidgets);
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
        matching: find.text('Project'),
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

  testWidgets('global create form can start with no kind selected', (
    tester,
  ) async {
    await _pump(
      tester,
      () => StarFormScreen(
        projectRepository: projects,
        starsShapeRepository: shapes,
        allowConstellation: true,
        startWithoutSelection: true,
      ),
    );

    final tiles = tester.widget<FormKindTiles>(find.byType(FormKindTiles));
    expect([...tiles.leading, ...tiles.trailing], hasLength(4));
    expect(tiles.tileEntranceAxis, Axis.horizontal);
    expect(tiles.animateDividerEntrance, isTrue);
    final dividerEntrance = tester.widget<StaggeredEntrance>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('form-kind-divider')),
            matching: find.byType(StaggeredEntrance),
          )
          .first,
    );
    expect(dividerEntrance.index, 4);
    expect(dividerEntrance.drift, 0);
    expect(dividerEntrance.extraDelay, kActionGroupDotDelay);
    expect(
      [...tiles.leading, ...tiles.trailing].where((tile) => tile.selected),
      isEmpty,
    );
    expect(find.byType(NewProjectScreen), findsNothing);
    expect(find.byType(AppTextField), findsNothing);

    expect(
      find.text('What would you like to add to your Galaxy?'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('form-kind-divider')),
          )
          .opacity,
      1,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(FormKindTiles),
        matching: find.text('Goal'),
      ),
    );
    await tester.pump();
    expect(
      find.text('What would you like to add to your Galaxy?'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('form-kind-divider')),
          )
          .opacity,
      0,
    );
    expect(find.byType(AppTextField), findsNothing);

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    expect(
      find.text('What would you like to add to your Galaxy?'),
      findsNothing,
    );
    expect(find.byType(AppTextField), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(AppTextField), findsWidgets);
    final focusedTiles = tester.widget<FormKindTiles>(
      find.byType(FormKindTiles),
    );
    expect(focusedTiles.tileEntranceAxis, Axis.vertical);
    expect([...focusedTiles.leading, ...focusedTiles.trailing], hasLength(1));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('What would you like to add to your Galaxy?'),
      findsOneWidget,
    );
    final resetTiles = tester.widget<FormKindTiles>(find.byType(FormKindTiles));
    expect([...resetTiles.leading, ...resetTiles.trailing], hasLength(4));

    await tester.tap(
      find.descendant(
        of: find.byType(FormKindTiles),
        matching: find.text('Goal'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AppTextField).first, 'A draft goal');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('CHANGE'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
    final actionCenters = [
      tester.getCenter(find.text('CANCEL')),
      tester.getCenter(find.text('CHANGE')),
      tester.getCenter(find.text('EXIT')),
    ];
    expect(
      actionCenters.map((center) => center.dy).toSet(),
      hasLength(1),
      reason: 'The shortened actions should fit on one row.',
    );

    await tester.tap(find.text('CHANGE'));
    await tester.pumpAndSettle();
    expect(
      find.text('What would you like to add to your Galaxy?'),
      findsOneWidget,
    );
    expect(find.text('A draft goal'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(FormKindTiles),
        matching: find.text('Project'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AppTextField).first, 'A draft project');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('CHANGE'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('A draft project'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('victory details stay collapsed until requested', (tester) async {
    await _pump(
      tester,
      () => StarFormScreen(
        projectRepository: projects,
        starsShapeRepository: shapes,
        allowConstellation: true,
        startWithoutSelection: true,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(FormKindTiles),
        matching: find.text('Victory'),
      ),
    );
    await tester.pumpAndSettle();

    final detailsToggle = find.byKey(const ValueKey('victory-details-toggle'));
    expect(detailsToggle, findsOneWidget);
    expect(find.text('Song'), findsNothing);

    await tester.ensureVisible(detailsToggle);
    await tester.tap(detailsToggle);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_less), findsWidgets);
    // Five named fields, each with its own reset: the photo on the left; on
    // the right the voice note (a minute at most) and a song, a place and a
    // site link — no "Main", no secondary photos or videos.
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Voice Note'), findsOneWidget);
    expect(find.text('Song'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Limit · 1:00'), findsOneWidget);
    expect(find.text('Main'), findsNothing);
    expect(find.byType(FieldResetButton), findsAtLeastNWidgets(5));
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.text('Videos'), findsNothing);
    expect(tester.takeException(), isNull);
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
        if (!icons) {
          final preview = find.widgetWithIcon(InkWell, Icons.insights).last;
          await tester.ensureVisible(preview);
          await tester.tap(preview);
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(
              const StringsEn().constellationEditorHelpClose.toUpperCase(),
            ),
          );
          await tester.pumpAndSettle();
        }
        final picker = icons
            ? find.byWidgetPredicate(
                (widget) => widget is AppPickerField && widget.iconOnly,
              )
            : find.byTooltip(const StringsEn().shapesLibraryButtonLabel);
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
