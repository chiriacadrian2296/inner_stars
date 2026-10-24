import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/app_rich_text_editor.dart';
import 'package:fleather/fleather.dart';

void main() {
  Future<AppRichTextEditor> open(WidgetTester tester) async {
    final controller = AppRichTextController(inputUsesDeltaModel: false);
    final focus = FocusNode();
    final editorKey = GlobalKey<EditorState>();
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Column(
              children: [
                AppRichTextToolbar(
                  controller: controller,
                  focusNode: focus,
                  editorKey: editorKey,
                ),
                Expanded(
                  child: AppRichTextEditor(
                    controller: controller,
                    focusNode: focus,
                    editorKey: editorKey,
                    hint: 'Testo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<AppRichTextEditor>(
      find.byType(AppRichTextEditor),
    );
    editor.editorKey.currentState!.requestKeyboard();
    await tester.pump();
    return editor;
  }

  testWidgets(
    'full input protocol accepts values and preserves toggled formats',
    (tester) async {
      final editor = await open(tester);
      expect(tester.testTextInput.setClientArgs!['enableDeltaModel'], false);
      editor.controller.formatSelection(ParchmentAttribute.bold);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'asd\n',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      expect(editor.controller.plainText, 'asd');
      expect(
        editor.controller.document
            .collectStyle(0, 3)
            .containsSame(ParchmentAttribute.bold),
        true,
      );
      editor.controller.formatSelection(ParchmentAttribute.italic);
      editor.controller.formatSelection(ParchmentAttribute.underline);
      // A toolbar refocus can echo the current value before the next keystroke.
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: editor.controller.document.toPlainText(),
          selection: editor.controller.selection,
        ),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'asdasd\n',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      for (final attr in [
        ParchmentAttribute.bold,
        ParchmentAttribute.italic,
        ParchmentAttribute.underline,
      ]) {
        expect(
          editor.controller.document.collectStyle(3, 3).containsSame(attr),
          true,
        );
        editor.controller.formatSelection(attr.unset);
      }
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'asdasd normal\n',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );
      await tester.pump();
      expect(editor.controller.plainText, 'asdasd normal');
      expect(
        editor.controller.document.collectStyle(7, 6).inlineAttributes,
        isEmpty,
      );
      expect(
        editor.controller.document
            .collectStyle(0, 3)
            .containsSame(ParchmentAttribute.bold),
        true,
      );
      await tester.pumpWidget(const SizedBox());
      editor.controller.dispose();
      editor.focusNode.dispose();
    },
  );

  testWidgets(
    'full input protocol supports replacements, composing input and undo',
    (tester) async {
      final editor = await open(tester);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'caffe\n',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'caffè\n',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(editor.controller.plainText, 'caffè');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'caffè 😀\n',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'caffè 😃\n',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(editor.controller.plainText, 'caffè 😃');
      editor.controller.undo();
      await tester.pump();
      expect(editor.controller.plainText, 'caffè 😀');
      editor.controller.redo();
      await tester.pump();
      expect(editor.controller.plainText, 'caffè 😃');
      await tester.pumpWidget(const SizedBox());
      editor.controller.dispose();
      editor.focusNode.dispose();
    },
  );
}
