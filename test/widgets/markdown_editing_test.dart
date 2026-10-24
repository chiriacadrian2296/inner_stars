import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/utils/markdown_editing.dart';

TextEditingValue selected(String text) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: 0, extentOffset: text.length),
);

void main() {
  test(
    'blank lines containing spaces do not prevent toggling a format off',
    () {
      final value = selected('**Uno**\n   \n**Due**');
      expect(formatMarkdown(value, '**', toggle: true).text, 'Uno\n   \nDue');
    },
  );

  test(
    'all orders of bold italic and underline can be applied and removed',
    () {
      const orders = [
        ['**', '*', '<u>'],
        ['**', '<u>', '*'],
        ['*', '**', '<u>'],
        ['*', '<u>', '**'],
        ['<u>', '**', '*'],
        ['<u>', '*', '**'],
      ];
      for (final order in orders) {
        var value = selected('Caffè 👩🏽‍🚀');
        for (final marker in [...order, ...order.reversed]) {
          value = formatMarkdown(
            selected(value.text),
            marker,
            closing: marker == '<u>' ? '</u>' : null,
            toggle: true,
          );
        }
        expect(value.text, 'Caffè 👩🏽‍🚀', reason: '$order');
      }
    },
  );

  test('toolbar leaves active keyboard composition intact', () {
    final value = selected('Caffè')
        .copyWith(composing: const TextRange(start: 0, end: 5));
    expect(formatMarkdown(value, '**', toggle: true), value);
    expect(formatMarkdown(value, '• ', block: true, toggle: true), value);
    expect(insertMarkdownDivider(value), value);
  });

  test('collapsed selection cannot insert empty inline markers', () {
    const value = TextEditingValue(
      text: 'Testo',
      selection: TextSelection.collapsed(offset: 2),
    );
    for (final marker in ['**', '*', '<u>']) {
      expect(
        formatMarkdown(
          value,
          marker,
          closing: marker == '<u>' ? '</u>' : null,
          toggle: true,
        ),
        value,
      );
    }
  });

  test(
    'block formatting at a paragraph boundary leaves the next one alone',
    () {
      const value = TextEditingValue(
        text: 'Uno\nDue\nAltro',
        selection: TextSelection(baseOffset: 0, extentOffset: 8),
      );
      expect(
        formatMarkdown(value, '• ', block: true, toggle: true).text,
        '• Uno\n• Due\nAltro',
      );
    },
  );

  test('formatting headings preserves inline content and can be removed', () {
    final value = selected('**Uno**\n<u>Due</u>');
    final heading = formatMarkdown(value, '## ', block: true, toggle: true);
    expect(heading.text, '## **Uno**\n## <u>Due</u>');
    expect(
      formatMarkdown(
        selected(heading.text),
        '## ',
        block: true,
        toggle: true,
      ).text,
      value.text,
    );
  });

  test('underline round trip preserves paragraphs and list prefixes', () {
    final value = selected('• Uno\n\n---\n\n2. Due');
    final underline = formatMarkdown(
      value,
      '<u>',
      closing: '</u>',
      toggle: true,
    );
    expect(underline.text, '• <u>Uno</u>\n\n---\n\n2. <u>Due</u>');
    expect(
      formatMarkdown(underline, '<u>', closing: '</u>', toggle: true).text,
      value.text,
    );
  });

  test(
    'divider insertion preserves subsequent paragraphs and supports removal',
    () {
      const value = TextEditingValue(
        text: 'Uno\nDue',
        selection: TextSelection.collapsed(offset: 2),
      );
      final divided = insertMarkdownDivider(value);
      expect(divided.text, 'Uno\n\n---\n\nDue');
      final removed = insertMarkdownDivider(
        divided.copyWith(selection: const TextSelection.collapsed(offset: 7)),
      );
      expect(removed.text, 'Uno\n\n\n\nDue');
      expect(removed.selection.baseOffset, 5);
    },
  );
}
