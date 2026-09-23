import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_answer_repository.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/area_detail_screen.dart';
import 'package:inner_stars/screens/moodboard_screen.dart';
import 'package:inner_stars/screens/vision_editor_screen.dart';
import 'package:inner_stars/widgets/reflection_questions_section.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/theme/life_area_theme.dart';

void main() {
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
              reflectionAnswerRepository: ReflectionAnswerRepository(prefs),
              projectRepository: ProjectRepository(prefs),
              starRepository: StarRepository(prefs),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestisci Questa Area'), findsNothing);
    final edit = find.text(const StringsIt().editVisionAction);
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(VisionEditorScreen), findsOneWidget);
    final editorTheme = Theme.of(
      tester.element(find.byType(VisionEditorScreen)),
    );
    expect(editorTheme.textSelectionTheme.cursorColor, Colors.white);
    expect(
      editorTheme.inputDecorationTheme.focusedBorder!.borderSide.color,
      Colors.white,
    );
    expect(editorTheme.scaffoldBackgroundColor, Colors.black);
    expect(
      editorTheme.segmentedButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.selected,
      }),
      Colors.white,
    );
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    final open = find.text('Apri e modifica');
    await tester.ensureVisible(open.first);
    await tester.tap(open.first);
    await tester.pumpAndSettle();
    expect(find.byType(MoodboardScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(open.last);
    await tester.tap(open.last);
    await tester.pumpAndSettle();
    expect(find.byType(ReflectionQuestionsSection), findsOneWidget);
    final reflectionTheme = Theme.of(
      tester.element(find.byType(ReflectionQuestionsSection)),
    );
    expect(reflectionTheme.sliderTheme.thumbColor, Colors.white);
    expect(reflectionTheme.sliderTheme.activeTrackColor, Colors.white);
    final question = LifeArea.physical
        .reflectionQuestions(const StringsIt())
        .first;
    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Una risposta da conservare',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    expect(
      ReflectionAnswerRepository(prefs)
          .getAnswer(LifeArea.physical, '0')!
          .answerText,
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
          theme: buildLifeAreaTheme(),
          home: MoodboardScreen(area: LifeArea.physical, repository: repo),
        ),
      ),
    );
    await tester.tap(find.text('Frase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A new direction');
    final quoteTheme = Theme.of(tester.element(find.byType(TextField)));
    expect(quoteTheme.textSelectionTheme.cursorColor, Colors.white);
    expect(
      quoteTheme.inputDecorationTheme.focusedBorder!.borderSide.color,
      Colors.white,
    );
    expect(quoteTheme.dialogTheme.backgroundColor, Colors.black);
    await tester.tap(find.text(const StringsIt().saveChanges));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repo.getItems(LifeArea.physical).single.content, 'A new direction');
    await tester.tap(find.text('A new direction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifica'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A clearer direction');
    await tester.tap(find.text(const StringsIt().saveChanges));
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
    await tester.tap(find.text('Rimuovi').last);
    await tester.pumpAndSettle();
    expect(repo.getItems(LifeArea.physical), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
