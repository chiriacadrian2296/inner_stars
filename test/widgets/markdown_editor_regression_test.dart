import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/area_reflections_screen.dart';
import 'package:inner_stars/screens/vision_editor_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  const strings = StringsIt();
  for (final reflection in [false, true]) {
    final name = reflection ? 'reflection' : 'vision';
    final field = reflection
        ? find.byKey(const ValueKey('reflection-body'))
        : find.byType(TextField);

    Future<TextEditingController> open(WidgetTester tester, String text) async {
      SharedPreferences.setMockInitialValues({});
      final screen = reflection
          ? ReflectionEditorScreen(
              area: LifeArea.physical,
              repository: await ReflectionRepository.create(),
            )
          : VisionEditorScreen(
              area: LifeArea.physical,
              repository: await AreaVisionRepository.create(),
            );
      await tester.pumpWidget(
        StringsScope(
          strings: strings,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push<void>(MaterialPageRoute(builder: (_) => screen)),
                  child: const Text('Apri Editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri Editor'));
      await tester.pumpAndSettle();
      if (reflection) {
        await tester.enterText(
          find.byKey(const ValueKey('reflection-title')),
          'Il mio pensiero',
        );
      }
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 600));
      return tester.widget<TextField>(field).controller!;
    }

    Future<void> tool(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.byTooltip(label));
      await tester.tap(find.byTooltip(label));
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets(
      '$name pastes over a selection and copies the full Markdown source',
      (tester) async {
        final controller = await open(tester, 'Uno Due');
        String clipboard = '<u>👩🏽‍🚀</u>\nNuovo';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') return {'text': clipboard};
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            if (call.method == 'Clipboard.hasStrings') {
              return {'value': clipboard.isNotEmpty};
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
        controller.selection = const TextSelection(
          baseOffset: 4,
          extentOffset: 7,
        );
        final editable = tester.state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        await editable.pasteText(SelectionChangedCause.toolbar);
        await tester.pumpAndSettle();
        expect(controller.text, 'Uno <u>👩🏽‍🚀</u>\nNuovo');
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
        editable.copySelection(SelectionChangedCause.toolbar);
        await tester.pumpAndSettle();
        expect(clipboard, controller.text);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$name keeps the typing caret above the open keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final controller = await open(
        tester,
        List.filled(30, 'Un paragrafo lungo.').join('\n'),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(field, '${controller.text}\nUltima riga');
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      final caret = editable.renderEditable.getLocalRectForCaret(
        controller.selection.extent,
      );
      final caretBottom = editable.renderEditable
          .localToGlobal(caret.bottomLeft)
          .dy;
      expect(
        caretBottom,
        lessThanOrEqualTo(640 - 300),
        reason:
            'editable=${editable.renderEditable.size}, field=${tester.getRect(field)}, focus=${tester.widget<TextField>(field).focusNode!.hasFocus}',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name saves formatted text across repository recreation', (
      tester,
    ) async {
      const text =
          '## Titolo\n\n<u>***Caffè 👩🏽‍🚀***</u>\n\n1. Uno\n2. Due\n\n---\n\nFine';
      await open(tester, text);
      final save = reflection
          ? find.byKey(const ValueKey('reflection-save'))
          : find.text(strings.saveChanges.toUpperCase());
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Apri Editor'), findsOneWidget);
      if (reflection) {
        final repo = await ReflectionRepository.create();
        expect(repo.getForArea(LifeArea.physical).single.body, text);
      } else {
        final repo = await AreaVisionRepository.create();
        expect(repo.getVision(LifeArea.physical), text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name combines and independently removes bold and italic', (
      tester,
    ) async {
      final controller = await open(tester, 'Ciao');
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 4,
      );
      await tool(tester, strings.visionBold);
      expect(controller.text, '**Ciao**');
      await tool(tester, strings.visionItalic);
      expect(controller.text, '***Ciao***');
      await tool(tester, strings.visionItalic);
      expect(controller.text, '**Ciao**');
      await tool(tester, strings.visionBold);
      expect(controller.text, 'Ciao');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name toggles italic through selected visible combined text', (
      tester,
    ) async {
      final controller = await open(tester, '***Ciao***');
      controller.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 7,
      );
      await tool(tester, strings.visionItalic);
      expect(controller.text, '**Ciao**');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name leaves surrounding whitespace outside formatting', (
      tester,
    ) async {
      final controller = await open(tester, '  Ciao  ');
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tool(tester, strings.visionBold);
      expect(controller.text, '  **Ciao**  ');
      await tool(tester, strings.visionBold);
      expect(controller.text, '  Ciao  ');
    });

    testWidgets('$name numbers items consecutively across dividers', (
      tester,
    ) async {
      final controller = await open(tester, 'Uno\n---\nDue');
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tool(tester, strings.visionNumberedList);
      expect(controller.text, '1. Uno\n---\n2. Due');
    });

    testWidgets(
      '$name preserves Unicode with reversed selections and underline',
      (tester) async {
        const text = 'Caffè 👩🏽‍🚀 e stelle';
        final controller = await open(tester, text);
        controller.selection = TextSelection(
          baseOffset: text.length,
          extentOffset: 0,
        );
        await tool(tester, strings.visionUnderline);
        expect(controller.text, '<u>$text</u>');
        expect(controller.selection.isValid, isTrue);
        await tool(tester, strings.visionUnderline);
        expect(controller.text, text);
      },
    );

    testWidgets('$name undoes and redoes toolbar edits without losing text', (
      tester,
    ) async {
      final controller = await open(tester, 'Ciao');
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 4,
      );
      await tool(tester, strings.visionBold);
      final undo = tester.widget<TextField>(field).undoController!;
      expect(undo.value.canUndo, isTrue);
      await tool(tester, strings.visionUndo);
      expect(controller.text, 'Ciao');
      expect(undo.value.canRedo, isTrue);
      await tool(tester, strings.visionRedo);
      expect(controller.text, '**Ciao**');
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    });
  }
}
