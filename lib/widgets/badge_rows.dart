import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/badge_schema.dart';
import '../utils/star_card_info.dart';
import 'badge_icon.dart';

/// A card's badges as an invisible grid of fixed rows and columns (see
/// [kBadgeRows]): every card of a kind has the same badges in the same places,
/// whatever its data, and the icons of a column line up one under the other.
///
/// The size never depends on how many badges there are. It is the smaller of
/// [maxScale] and what the available width allows the *widest row any card
/// has* ([kBadgeReferenceWidth]), so the same width always gives the same
/// badge size for every kind of card. Nothing wraps and nothing is scaled to
/// fit its own content.
class BadgeRows extends StatelessWidget {
  const BadgeRows({super.key, required this.rows, this.maxScale = 1});

  final List<List<CardBadge>> rows;

  /// The largest scale to draw at (1 = the tooltip's own size).
  final double maxScale;

  /// A badge at scale 1: the icon, the value's text and the gap between rows.
  static const double iconSize = 14;
  static const double textSize = 11.5;
  static const double rowGap = 4;

  /// The scale the badges are drawn at in [availableWidth].
  static double scaleFor(double availableWidth, double maxScale) =>
      math.min(maxScale, availableWidth / kBadgeReferenceWidth);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    // One width per column, the widest cell in it across the rows, so the
    // icons of a column sit exactly one under the other.
    final columnWidths = badgeColumnWidths([
      for (final row in rows) [for (final badge in row) badge.slot],
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = scaleFor(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : kBadgeReferenceWidth * maxScale,
          maxScale,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap * scale),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var j = 0; j < rows[i].length; j++)
                    SizedBox(
                      width: columnWidths[j] * scale,
                      child: _BadgeCell(
                        badge: rows[i][j],
                        scale: scale,
                        first: j == 0,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({
    required this.badge,
    required this.scale,
    required this.first,
  });

  final CardBadge badge;
  final double scale;

  /// The first cell of a row: its icon's empty left margin is trimmed so the
  /// drawing lines up with the text above.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final check = badge.check;
    final cell = Padding(
      // The gap to the next cell is part of every slot's width.
      padding: EdgeInsets.only(right: 8 * scale),
      child: Row(
        children: [
          BadgeIcon(
            badge.icon,
            size: BadgeRows.iconSize * scale,
            color: badge.iconColor,
            trimLeading: first,
          ),
          SizedBox(width: 2 * scale),
          Expanded(
            child: check != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      check ? Icons.check_rounded : Icons.close_rounded,
                      size: BadgeRows.iconSize * scale,
                      color: badge.valueColor,
                    ),
                  )
                // Only a freakishly large number ever shrinks; a normal one
                // fills its cell at full size.
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      badge.value!,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: BadgeRows.textSize * scale,
                        fontWeight: FontWeight.w700,
                        color: badge.valueColor,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
    final label = badge.semanticLabel;
    return label == null ? cell : Semantics(label: label, child: cell);
  }
}
