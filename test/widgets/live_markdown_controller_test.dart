import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/live_markdown_controller.dart';
import 'package:inner_stars/widgets/vision_markdown.dart';

Iterable<TextSpan> flatten(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? <InlineSpan>[]) {
    if (child is TextSpan) yield* flatten(child);
  }
}

void main() {
  test('combines bold and italic in the same inline span', () {
    const style = TextStyle(fontFamily: 'Newsreader', fontSize: 17);
    final span = TextSpan(
      children: markdownInlineSpans('***Both***', style),
    );
    final both = flatten(span).firstWhere((item) => item.text == 'Both');

    expect(both.style!.fontWeight, FontWeight.bold);
    expect(both.style!.fontStyle, FontStyle.italic);
    expect(both.style!.fontVariations, isNotEmpty);
  });

  testWidgets(
    'keeps Markdown markers hidden and preserves source offsets and composing',
    (tester) async {
      final controller = LiveMarkdownController(
        text: '# Heading\n**Bold** and <u>underlined</u>\nLast',
      );
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      const style = TextStyle(fontSize: 17, color: Colors.white);
      TextSpan render() => controller.buildTextSpan(
        context: context,
        style: style,
        withComposing: true,
      );
      expect(render().toPlainText(), controller.text);
      expect(
        flatten(render())
            .where((s) => s.text == '**')
            .every((s) => s.style!.fontSize == 0),
        isTrue,
      );
      expect(
        flatten(render()).firstWhere((s) => s.text == 'Bold').style!.fontWeight,
        FontWeight.bold,
      );
      expect(
        flatten(render())
            .firstWhere((s) => s.text == 'underlined')
            .style!
            .decoration,
        TextDecoration.underline,
      );
      controller.focused = true;
      controller.selection = const TextSelection.collapsed(offset: 12);
      expect(
        flatten(render())
            .where((s) => s.text == '**')
            .every((s) => s.style!.fontSize == 0),
        isTrue,
      );
      expect(
        flatten(render()).firstWhere((s) => s.text == '<u>').style!.fontSize,
        0,
      );
      expect(
        flatten(render()).firstWhere((s) => s.text == '# ').style!.fontSize,
        0,
      );
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      expect(
        flatten(render())
            .where((s) => s.text == '**')
            .every((s) => s.style!.fontSize == 0),
        isTrue,
      );
      controller.value = controller.value.copyWith(
        composing: const TextRange(start: 10, end: 15),
      );
      expect(render().toPlainText(), controller.text);
      expect(
        flatten(render())
            .any((s) => s.style?.decoration == TextDecoration.underline),
        isTrue,
      );
    },
  );

  testWidgets('keeps inline formats hidden on the same line', (
    tester,
  ) async {
    final controller = LiveMarkdownController(
      text: 'Start **bold word**, *italic words*',
    );
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    const style = TextStyle(fontSize: 17, color: Colors.white);
    TextSpan render() => controller.buildTextSpan(
      context: context,
      style: style,
      withComposing: true,
    );
    bool markersAreVisible(String marker) => flatten(
      render(),
    ).where((span) => span.text == marker).every(
      (span) => span.style!.fontSize != 0,
    );

    controller.focused = true;
    controller.selection = const TextSelection.collapsed(offset: 2);
    expect(markersAreVisible('**'), isFalse);
    expect(markersAreVisible('*'), isFalse);

    controller.selection = const TextSelection.collapsed(offset: 10);
    expect(markersAreVisible('**'), isFalse);
    expect(markersAreVisible('*'), isFalse);

    controller.selection = const TextSelection.collapsed(offset: 25);
    expect(markersAreVisible('**'), isFalse);
    expect(markersAreVisible('*'), isFalse);
  });

  testWidgets('saved underline renders with nested bold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VisionMarkdown(data: '<u>**Strong** words</u>')),
      ),
    );
    await tester.pumpAndSettle();
    final spans = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .where((w) => w.textSpan != null)
        .expand((w) => flatten(w.textSpan!));
    final strong = spans.where((s) => s.text == 'Strong');
    expect(strong, isNotEmpty);
    expect(strong.first.style!.decoration, TextDecoration.underline);
    expect(strong.first.style!.fontWeight, FontWeight.bold);
    expect(tester.takeException(), isNull);
  });
}
