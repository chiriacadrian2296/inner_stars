import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';

/// A type label. For an archived activity ([originalKind] set) it reads the
/// archived element's whole name instead ("Archived Goal", "Obiettivo
/// Archiviato"), uppercase when [text] is.
class StarTypeText extends StatelessWidget {
  const StarTypeText(
    this.text, {
    super.key,
    this.originalKind,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final StarKind? originalKind;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final original = originalKind;
    var shown = text;
    if (original != null) {
      final name = context.strings.archivedKindName(original);
      shown = text == text.toUpperCase() ? name.toUpperCase() : name;
    }
    return Text(
      shown,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
