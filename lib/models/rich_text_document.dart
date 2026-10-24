import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:markdown/markdown.dart' as md;

/// Versioned native document plus the exact legacy text written alongside it.
/// The snapshot prevents an older client's text edit being masked by stale Delta.
class RichTextDocument {
  RichTextDocument._(this.operations, this.legacyText);
  final List<dynamic> operations;
  final String legacyText;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'delta': operations,
    'legacyText': legacyText,
  };

  static RichTextDocument? tryParse(Object? value) {
    try {
      if (value is! Map ||
          value['version'] != 1 ||
          value['legacyText'] is! String ||
          value['delta'] is! List) {
        return null;
      }
      final ops = jsonDecode(jsonEncode(value['delta'])) as List<dynamic>;
      if (ops.isEmpty) return null;
      for (final op in ops) {
        if (op is! Map ||
            !op.containsKey('insert') ||
            op.containsKey('delete') ||
            op.containsKey('retain')) {
          return null;
        }
        final insert = op['insert'];
        if (insert is! String && !(insert is Map && insert['_type'] == 'hr')) {
          return null;
        }
      }
      if (ops.last['insert'] is! String ||
          !(ops.last['insert'] as String).endsWith('\n')) {
        return null;
      }
      final result = RichTextDocument._(ops, value['legacyText'] as String);
      result
          .toParchment()
          .close(); // Validate attributes, embeds and line structure.
      return result;
    } catch (_) {
      return null;
    }
  }

  ParchmentDocument toParchment() => ParchmentDocument.fromJson(
    jsonDecode(jsonEncode(operations)) as List<dynamic>,
  );

  static ParchmentDocument resolve(String legacy, RichTextDocument? native) {
    if (native != null && native.legacyText == legacy) {
      try {
        return native.toParchment();
      } catch (_) {
        /* Fall back to legacy. */
      }
    }
    return importMarkdown(legacy);
  }

  factory RichTextDocument.capture(ParchmentDocument document) {
    final ops = jsonDecode(jsonEncode(document.toJson())) as List<dynamic>;
    return RichTextDocument._(ops, _legacyMarkdown(ops).trim());
  }

  static String plainText(String legacy, [RichTextDocument? native]) {
    final document = resolve(legacy, native);
    try {
      return visibleText(document);
    } finally {
      document.close();
    }
  }

  static String visibleText(ParchmentDocument document) {
    final text = document.toPlainText().replaceAll('\uFFFC', '');
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  }

  /// Parse Markdown once at the boundary. Editor operations never manipulate it.
  static ParchmentDocument importMarkdown(String source) {
    final parser = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [_UnderlineSyntax()],
      blockSyntaxes: [const _UnderlineParagraph()],
      encodeHtml: false,
    );
    final delta = Delta();
    var hasLine = false;
    void text(
      String value,
      Map<String, dynamic> attributes,
      Map<String, dynamic> line,
    ) {
      final pieces = value.split('\n');
      for (var i = 0; i < pieces.length; i++) {
        if (pieces[i].isNotEmpty) {
          delta.insert(pieces[i], attributes.isEmpty ? null : attributes);
          hasLine = true;
        }
        if (i < pieces.length - 1) {
          delta.insert('\n', line.isEmpty ? null : line);
          hasLine = false;
        }
      }
    }

    void endLine(Map<String, dynamic> line) {
      delta.insert('\n', line.isEmpty ? null : line);
      hasLine = false;
    }

    void visit(
      md.Node node,
      Map<String, dynamic> inline,
      Map<String, dynamic> line,
    ) {
      if (node is md.Text) {
        text(node.text, inline, line);
        return;
      }
      final el = node as md.Element;
      final next = {...inline};
      final block = {...line};
      switch (el.tag) {
        case 'strong':
          next['b'] = true;
        case 'em':
          next['i'] = true;
        case 'u':
          next['u'] = true;
        case 'del':
          next['s'] = true;
        case 'code':
          next['c'] = true;
        case 'a':
          next['a'] = el.attributes['href'];
        case 'blockquote':
          block['block'] = 'quote';
        case 'ul':
          block['block'] = 'ul';
        case 'ol':
          block['block'] = 'ol';
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          block['heading'] = int.parse(el.tag.substring(1));
        case 'hr':
          if (hasLine) endLine(line);
          delta.insert(BlockEmbed.horizontalRule.toJson());
          endLine({});
          return;
        case 'br':
          endLine(line);
          return;
      }
      for (final child in el.children ?? <md.Node>[]) {
        visit(child, next, block);
      }
      if (el.tag == 'p' ||
          el.tag == 'li' ||
          RegExp(r'^h[1-6]$').hasMatch(el.tag) ||
          el.tag == 'pre') {
        if (hasLine || el.children?.isEmpty == true) endLine(block);
      }
    }

    // The old editor used a typographic bullet rather than Markdown's '-'.
    final normalized = source.replaceAllMapped(
      RegExp(r'^(\s*)• ', multiLine: true),
      (m) => '${m[1]}- ',
    );
    for (final node in parser.parseLines(normalized.split('\n'))) {
      visit(node, {}, {});
    }
    if (hasLine || delta.isEmpty) endLine({});
    return ParchmentDocument.fromDelta(delta);
  }
}

class _UnderlineSyntax extends md.InlineSyntax {
  _UnderlineSyntax() : super(r'<u>(.+?)</u>');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('u', parser.document.parseInline(match[1]!)));
    return true;
  }
}

class _UnderlineParagraph extends md.ParagraphSyntax {
  const _UnderlineParagraph();
  @override
  bool canParse(md.BlockParser parser) =>
      parser.current.content.trimLeft().startsWith('<u>');
}

String _legacyMarkdown(List<dynamic> ops) {
  final output = StringBuffer();
  final line = StringBuffer();
  var number = 0;
  String escape(String s) =>
      s.replaceAllMapped(RegExp(r'[\\`*_\[\]<>]'), (m) => '\\${m[0]}');
  for (final raw in ops) {
    final op = raw as Map;
    final a = (op['attributes'] as Map?) ?? const {};
    final insert = op['insert'];
    if (insert is! String) {
      line.write('---');
      continue;
    }
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        var value = escape(parts[i]);
        if (a['b'] == true) value = '**$value**';
        if (a['i'] == true) value = '*$value*';
        if (a['u'] == true) value = '<u>$value</u>';
        if (a['s'] == true) value = '~~$value~~';
        if (a['a'] is String) value = '[$value](${a['a']})';
        line.write(value);
      }
      if (i < parts.length - 1) {
        var prefix = '';
        if (a['heading'] is int) prefix = '${'#' * (a['heading'] as int)} ';
        if (a['block'] == 'ul') prefix = '- ';
        if (a['block'] == 'ol') {
          number++;
          prefix = '$number. ';
        } else {
          number = 0;
        }
        if (a['block'] == 'quote') prefix = '> ';
        output.writeln('$prefix$line');
        // Separate regular paragraphs so legacy Markdown preserves line breaks.
        if (a['block'] == null) output.writeln();
        line.clear();
      }
    }
  }
  return output.toString();
}
