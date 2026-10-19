import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/area_detail_screen.dart';
import 'package:inner_stars/screens/moodboard_screen.dart';
import 'package:inner_stars/screens/new_project_screen.dart';
import 'package:inner_stars/screens/star_form_screen.dart';
import 'package:inner_stars/screens/vision_editor_screen.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  testWidgets('new constellation from an area opens only its dedicated form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tourStorage = InMemoryTourStorage();
    await tourStorage.markCompleted('constellation-form');

    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: TourScope(
          storage: tourStorage,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: AreaDetailScreen(
              area: LifeArea.physical,
              areaVisionRepository: AreaVisionRepository(prefs),
              reflectionAnswerRepository: ReflectionRepository(prefs),
              projectRepository: ProjectRepository(prefs),
              starRepository: StarRepository(prefs),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('+ Costellazione'));
    await tester.pumpAndSettle();

    expect(find.byType(NewProjectScreen), findsOneWidget);
    expect(find.byType(StarFormScreen), findsNothing);
    expect(find.text('Fisica'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('area has three compact sections and direct editors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final visions = AreaVisionRepository(prefs);
    await visions.setVision(
      LifeArea.physical,
      List.filled(70, 'My vision\n\n').join(),
    );
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: TourScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: AreaDetailScreen(
              area: LifeArea.physical,
              areaVisionRepository: visions,
              reflectionAnswerRepository: ReflectionRepository(prefs),
              projectRepository: ProjectRepository(prefs),
              starRepository: StarRepository(prefs),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'area detail');
    expect(find.text('Gestisci Questa Area'), findsNothing);
    await tester.tap(find.byTooltip('Vision'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'vision editor');
    expect(find.byType(VisionEditorScreen), findsOneWidget);
    final editorTheme = Theme.of(
      tester.element(find.byType(VisionEditorScreen)),
    );
    expect(editorTheme.scaffoldBackgroundColor, AppColors.dark.night);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'return from vision');
    await tester.tap(find.byTooltip('Moodboard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'moodboard');
    expect(find.byType(MoodboardScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'return from moodboard');
    await tester.tap(find.byTooltip('Riflessioni'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'reflections');
    expect(find.byType(AreaReflectionsScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reflection-new')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(const StringsIt().reflectionSuggested.toUpperCase()),
    );
    await tester.pumpAndSettle();
    final question = LifeArea.physical
        .reflectionQuestions(const StringsIt())
        .first;
    final group = LifeArea.physical.reflectionGroups(const StringsIt()).first;
    await tester.tap(find.text(group.title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(question));
    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reflection-body')),
      'Una risposta da conservare',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('reflection-save')));
    await tester.tap(find.byKey(const ValueKey('reflection-save')));
    await tester.pumpAndSettle();
    expect(
      ReflectionRepository(prefs).getForArea(LifeArea.physical).single.body,
      'Una risposta da conservare',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('moodboard adds and edits a quote and persists after reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await MoodboardRepository.create();
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MoodboardScreen(area: LifeArea.physical, repository: repo),
        ),
      ),
    );
    await tester.tap(
      find.widgetWithText(
        ElevatedButton,
        const StringsIt().moodboardAddLabel.toUpperCase(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(const StringsIt().moodboardQuote.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quote-text-field')),
      'A new direction',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-author-field')),
      'Ursula K. Le Guin',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('quote-style-aurora')),
    );
    await tester.tap(find.byKey(const ValueKey('quote-style-aurora')));
    await tester.pumpAndSettle();
    final quoteTheme = Theme.of(
      tester.element(find.byKey(const ValueKey('quote-text-field'))),
    );
    expect(quoteTheme.scaffoldBackgroundColor, AppColors.dark.night);
    await tester.tap(find.text(const StringsIt().saveChanges.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repo.getItems(LifeArea.physical).single.content, 'A new direction');
    expect(repo.getItems(LifeArea.physical).single.author, 'Ursula K. Le Guin');
    expect(
      repo.getItems(LifeArea.physical).single.quoteStyle,
      MoodboardQuoteStyle.aurora,
    );
    await tester.tap(find.text('A new direction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifica'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quote-text-field')),
      'A clearer direction',
    );
    await tester.pump();
    await tester.tap(find.text(const StringsIt().saveChanges.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      (await MoodboardRepository.create())
          .getItems(LifeArea.physical)
          .single
          .content,
      'A clearer direction',
    );
    expect(find.text('A clearer direction'), findsOneWidget);
    await tester.tap(find.text('A clearer direction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rimuovi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RIMUOVI').last);
    await tester.pumpAndSettle();
    expect(repo.getItems(LifeArea.physical), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
