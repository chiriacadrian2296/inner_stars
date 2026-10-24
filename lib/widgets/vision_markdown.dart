import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

import '../models/rich_text_document.dart';
import 'app_rich_text_editor.dart';

/// Shared read-only rendering for saved documents and non-interactive exports.
/// The legacy name is retained for existing call sites accepting Markdown.
class VisionMarkdown extends StatefulWidget {
  const VisionMarkdown({
    super.key,
    required this.data,
    this.richText,
    this.color,
    this.interactive = true,
    this.fontSize = 16,
  });
  final String data;
  final RichTextDocument? richText;
  final Color? color;
  final bool interactive;
  final double fontSize;
  @override
  State<VisionMarkdown> createState() => _VisionMarkdownState();
}

class _VisionMarkdownState extends State<VisionMarkdown> {
  late FleatherController _controller;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _controller = FleatherController(
    document: RichTextDocument.resolve(widget.data, widget.richText),
  );
  @override
  void didUpdateWidget(VisionMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        jsonEncode(oldWidget.richText?.toJson()) !=
            jsonEncode(widget.richText?.toJson())) {
      final previous = _controller;
      _load();
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = appDocumentTheme(context, fontSize: widget.fontSize);
    if (widget.color != null) {
      theme = theme.copyWith(
        paragraph: TextBlockTheme(
          style: theme.paragraph.style.copyWith(color: widget.color),
          spacing: theme.paragraph.spacing,
        ),
      );
    }
    final content = FleatherTheme(
      data: theme,
      child: FleatherEditor(
        controller: _controller,
        readOnly: true,
        showCursor: false,
        scrollable: false,
        padding: EdgeInsets.zero,
        enableInteractiveSelection: widget.interactive,
        onLaunchUrl: widget.interactive ? launchDocumentLink : null,
        contextMenuBuilder: appDocumentContextMenu,
        linkActionPickerDelegate: (context, link) =>
            showDocumentLinkMenu(context, link, canRemove: false),
      ),
    );
    return widget.interactive ? content : IgnorePointer(child: content);
  }
}
