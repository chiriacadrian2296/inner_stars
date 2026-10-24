import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/app_rich_text_editor.dart';

/// Fleather uses DeltaTextInputClient: Flutter's enterText sends the older
/// updateEditingValue protocol, which is deliberately a no-op in Fleather.
Future<void> enterRichText(
  WidgetTester tester,
  AppRichTextEditor editor,
  String text, {
  bool append = false,
}) async {
  editor.editorKey.currentState!.requestKeyboard();
  await tester.pump();
  final state = editor.editorKey.currentState! as RawEditorState;
  final old = editor.controller.document.toPlainText();
  final start = append ? old.length - 1 : 0;
  state.updateEditingValueWithDeltas([
    TextEditingDeltaReplacement(
      oldText: old,
      replacedRange: TextRange(start: start, end: old.length - 1),
      replacementText: text,
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    ),
  ]);
  await tester.pump();
}

Future<void> enterEditorText(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  if (finder.evaluate().single.widget is AppRichTextEditor) {
    await enterRichText(tester, tester.widget<AppRichTextEditor>(finder), text);
  } else {
    await tester.enterText(finder, text);
  }
}
