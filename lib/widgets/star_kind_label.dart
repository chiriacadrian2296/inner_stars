import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import 'star_glyph.dart';
import 'star_type_text.dart';

/// The star-list cards' first row: which kind of star this is, centered and
/// large — the one thing a glance at a card should answer first, before
/// area, constellation, or title.
///
/// The kind is named *and* drawn, in its own family's color, so the card
/// and the point of light in the sky it stands for are recognizably the
/// same thing.
class StarKindLabel extends StatelessWidget {
  const StarKindLabel({
    super.key,
    required this.kind,
    this.lit = true,
    this.originalKind,
  });

  final StarKind kind;
  final StarKind? originalKind;

  /// Only meaningful for [StarKind.pulsar] — see [StarGlyph.lit].
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarGlyph(kind: kind, lit: lit, size: 20),
          const SizedBox(width: 4),
          Flexible(
            child: StarTypeText(
              kind.label(strings),
              originalKind: kind == StarKind.dead ? originalKind : null,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: starKindColor(kind, colors, lit: lit),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
