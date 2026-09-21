import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

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
