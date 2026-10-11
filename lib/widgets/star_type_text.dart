import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';

/// A type label with the original type to its right when an activity is archived.
class StarTypeText extends StatelessWidget {
  const StarTypeText(
    this.text, {
    super.key,
    this.originalKind,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.compact = false,
  });

  final String text;
  final StarKind? originalKind;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Compact uppercase labels need optical sizing and alignment for the icon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
    final original = originalKind;
    if (original == null) return label;
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(effectiveStyle.fontSize ?? 14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: textAlign == TextAlign.center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        const SizedBox(width: 4),
        Transform.translate(
          offset: Offset(0, compact ? -fontSize * 0.1 : 0),
          child: Icon(
            original.icon,
            size: fontSize * (compact ? 1.4 : 1),
            color: effectiveStyle.color,
            semanticLabel: original.label(context.strings),
          ),
        ),
      ],
    );
  }
}
