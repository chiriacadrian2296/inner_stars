import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/live_markdown_controller.dart';

void type(LiveMarkdownController controller, String inserted) {
  final old = controller.value;
  final selection = old.selection.isValid
      ? old.selection
      : TextSelection.collapsed(offset: old.text.length);
  final next = TextEditingValue(
    text: old.text.replaceRange(selection.start, selection.end, inserted),
    selection: TextSelection.collapsed(
      offset: selection.start + inserted.length,
    ),
  );
  controller.value = controller.typingFormatter.formatEditUpdate(old, next);
}

void main() {
  test(
    'deleting the last formatted character leaves no visible delimiters',
    () {
      final controller = LiveMarkdownController();
      addTearDown(controller.dispose);
      controller.format('**', toggle: true);
      type(controller, 'A');
      final caret = controller.selection.extentOffset;
      controller.selection = TextSelection(
        baseOffset: caret - 1,
        extentOffset: caret,
      );
      type(controller, '');
      expect(controller.text, isEmpty);
      type(controller, 'B');
      expect(controller.text, '**B**');
    },
  );

  test('formatting cannot truncate content at the source limit', () {
    final controller = LiveMarkdownController(
      text: '123456',
      maxSourceLength: 8,
    );
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 6);
    controller.format('**', toggle: true);
    type(controller, 'Z');
    expect(controller.text, '123456');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    controller.format('**', toggle: true);
    expect(controller.text, '123456');
  });

  test('selected formatted text reports each active style', () {
    final controller = LiveMarkdownController(text: '<u>***Ciao***</u>');
    addTearDown(controller.dispose);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    expect(controller.activeFormats, {'**', '*', '<u>'});
  });

  for (final (marker, closing) in [('**', '**'), ('*', '*'), ('<u>', '</u>')]) {
    test('$marker can be armed, typed in and disabled without selecting', () {
      final controller = LiveMarkdownController();
      addTearDown(controller.dispose);
      controller.format(marker, closing: closing, toggle: true);
      expect(controller.isFormatActive(marker), isTrue);
      expect(controller.text, isEmpty);
      type(controller, 'Ciao');
      expect(controller.text, '${marker}Ciao$closing');
      type(controller, '!');
      expect(controller.text, '${marker}Ciao!$closing');
      controller.format(marker, closing: closing, toggle: true);
      expect(controller.isFormatActive(marker), isFalse);
      type(controller, ' normale');
      expect(controller.text, '${marker}Ciao!$closing normale');
    });
  }

  test('a style disabled inside a word preserves formatting on both sides', () {
    final controller = LiveMarkdownController(text: '**abcd**');
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 4);
    controller.format('**', toggle: true);
    type(controller, 'X');
    expect(controller.text, '**ab**X**cd**');
  });

  test('spaces and line breaks do not invalidate an armed style', () {
    final controller = LiveMarkdownController();
    addTearDown(controller.dispose);
    controller.format('**', toggle: true);
    type(controller, 'Uno');
    type(controller, ' ');
    expect(controller.text, '**Uno** ');
    expect(controller.isFormatActive('**'), isTrue);
    type(controller, 'due');
    type(controller, '\n');
    type(controller, 'Tre');
    expect(controller.text, '**Uno** **due**\n**Tre**');
    expect(controller.isFormatActive('**'), isTrue);
  });

  test(
    'moving the caret resets an explicit typing style to its new context',
    () {
      final controller = LiveMarkdownController(text: 'Testo');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.format('**', toggle: true);
      controller.selection = const TextSelection.collapsed(offset: 0);
      type(controller, 'Prima ');
      expect(controller.text, 'Prima Testo');
      expect(controller.isFormatActive('**'), isFalse);
    },
  );

  test('keyboard composition is formatted only when committed', () {
    final controller = LiveMarkdownController();
    addTearDown(controller.dispose);
    controller.format('<u>', closing: '</u>', toggle: true);
    final composing = TextEditingValue(
      text: 'Caffè',
      selection: const TextSelection.collapsed(offset: 5),
      composing: const TextRange(start: 0, end: 5),
    );
    controller.value = controller.typingFormatter.formatEditUpdate(
      controller.value,
      composing,
    );
    expect(controller.value.composing, const TextRange(start: 0, end: 5));
    controller.value = controller.typingFormatter.formatEditUpdate(
      controller.value,
      controller.value.copyWith(composing: TextRange.empty),
    );
    expect(controller.text, '<u>Caffè</u>');
    expect(controller.value.composing, TextRange.empty);
  });
}
