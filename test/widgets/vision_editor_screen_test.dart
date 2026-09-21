import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/vision_editor_screen.dart';
import 'package:inner_stars/widgets/vision_markdown.dart';

void main() {
  testWidgets('fits a narrow screen with keyboard and long text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues({});
    final repository = await AreaVisionRepository.create();
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          home: VisionEditorScreen(
            area: LifeArea.physical,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      List.filled(100, 'Un paragrafo lungo.\n').join(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Anteprima'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Future<AreaVisionRepository> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await AreaVisionRepository.create();
    await repository.setVision(LifeArea.physical, 'La mia visione');
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VisionEditorScreen(
                      area: LifeArea.physical,
                      repository: repository,
                    ),
                  ),
                ),
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('formats selection, previews and persists Markdown', (
    tester,
  ) async {
    final repository = await open(tester);
    await tester.enterText(find.byType(TextField), 'La mia visione');
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 14);
    await tester.tap(find.byTooltip('Grassetto'));
    await tester.pump();
    expect(controller.text, '**La mia visione**');
    await tester.tap(find.text('Anteprima'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<VisionMarkdown>(find.byType(VisionMarkdown)).data,
      '**La mia visione**',
    );
    await tester.tap(find.text('Scrivi'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '**La mia visione**',
    );
    await tester.tap(find.text(const StringsIt().saveChanges));
    await tester.pumpAndSettle();
    expect(find.text('Apri'), findsOneWidget);
    expect(repository.getVision(LifeArea.physical), '**La mia visione**');
  });

  testWidgets('back protects draft and discard preserves stored vision', (
    tester,
  ) async {
    final repository = await open(tester);
    await tester.enterText(find.byType(TextField), 'Nuova bozza');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text(const StringsIt().cancel));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Nuova bozza',
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text(const StringsIt().discardChangesAction));
    await tester.pumpAndSettle();
    expect(repository.getVision(LifeArea.physical), 'La mia visione');
    expect(find.text('Apri'), findsOneWidget);
  });

  testWidgets('numbers selected lines without changing following paragraph', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Uno\nDue\nAltro');
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    await tester.tap(find.byTooltip('Elenco numerato'));
    await tester.pump();
    expect(controller.text, '1. Uno\n2. Due\nAltro');
  });
}
