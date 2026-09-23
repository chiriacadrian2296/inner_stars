import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'live_markdown_controller.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class VisionMarkdown extends StatelessWidget {
  const VisionMarkdown({super.key, required this.data, this.color});
  final String data;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.colors.text;
    final theme = Theme.of(context);
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      inlineSyntaxes: [VisionUnderlineSyntax()],
      blockSyntaxes: [const VisionUnderlineParagraphSyntax()],
      builders: {'u': _UnderlineBuilder()},
      styleSheet:
          MarkdownStyleSheet.fromTheme(
            theme.copyWith(
              textTheme: theme.textTheme.apply(
                fontFamily: kFontStarTitle,
                bodyColor: foreground,
                displayColor: foreground,
              ),
            ),
          ).copyWith(
            p: TextStyle(
              fontFamily: kFontStarTitle,
              fontStyle: FontStyle.normal,
              color: foreground,
              fontSize: 16,
              height: 1.6,
            ),
          ),
    );
  }
}

class VisionUnderlineSyntax extends md.InlineSyntax {
  VisionUnderlineSyntax() : super(r'<u>(.+?)</u>');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('u', match[1]!));
    return true;
  }
}

/// A paragraph beginning with <u> is text, rather than an HTML block.
class VisionUnderlineParagraphSyntax extends md.ParagraphSyntax {
  const VisionUnderlineParagraphSyntax();
  @override
  bool canParse(md.BlockParser parser) =>
      parser.current.content.trimLeft().startsWith('<u>');
}

class _UnderlineBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style =
        (preferredStyle ?? parentStyle ?? DefaultTextStyle.of(context).style)
            .copyWith(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        children: markdownInlineSpans(
          element.textContent,
          style,
          preserveMarkers: false,
        ),
      ),
    );
  }
}
