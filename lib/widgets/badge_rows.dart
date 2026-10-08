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

  /// The smallest gap between two badges (a slot's width includes it).
  static const double _gap = 8;

  /// The scale the badges are drawn at in [availableWidth].
  static double scaleFor(double availableWidth, double maxScale) =>
      math.min(maxScale, availableWidth / kBadgeReferenceWidth);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = scaleFor(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : kBadgeReferenceWidth * maxScale,
          maxScale,
        );
        final width = constraints.maxWidth;
        // The gap between two badges of a victory's row at this width.
        final victory = kBadgeRows[BadgeCardKind.victory]!.single;
        final victoryGap = width.isFinite
            ? math.max(
                _gap * scale,
                (width -
                        victory.fold<double>(
                          0,
                          (sum, slot) => sum + (slot.width - _gap) * scale,
                        )) /
                    (victory.length - 1),
              )
            : _gap * scale;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap * scale),
              // Each badge keeps its own size; whatever width is left over is
              // shared out as equal gaps between them, edge to edge. A row of
              // only two badges keeps the gap a victory's row has instead of
              // stretching them apart.
              Row(
                mainAxisAlignment: rows[i].length == 2 && width.isFinite
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceBetween,
                mainAxisSize: width.isFinite
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  for (var j = 0; j < rows[i].length; j++) ...[
                    if (j > 0 && rows[i].length == 2 && width.isFinite)
                      SizedBox(width: victoryGap),
                    SizedBox(
                      width: (rows[i][j].slot.width - _gap) * scale,
                      child: _BadgeCell(
                        badge: rows[i][j],
                        scale: scale,
                        first: j == 0,
                      ),
                    ),
                  ],
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
    final cell = Row(
      children: [
        BadgeIcon(
          badge.icon,
          size: BadgeRows.iconSize * scale,
          color: badge.iconColor,
          trimLeading: first,
        ),
        SizedBox(width: 2 * scale),
        Expanded(
          // Only a freakishly large number ever shrinks; a normal one
          // fills its cell at full size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              badge.value,
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
    );
    final label = badge.semanticLabel;
    return label == null ? cell : Semantics(label: label, child: cell);
  }
}

/// A card's intensity, drawn bigger than the other badges above the card's
/// first text: the gold bolt and the number.
class IntensityBadge extends StatelessWidget {
  const IntensityBadge({super.key, required this.badge, this.scale = 1});

  final CardBadge badge;

  /// 1 = the tooltip's own size.
  final double scale;

  static const double iconSize = 19;
  static const double textSize = 15;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BadgeIcon(
          badge.icon,
          size: iconSize * scale,
          color: badge.iconColor,
          trimLeading: true,
        ),
        SizedBox(width: 3 * scale),
        Text(
          badge.value,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: textSize * scale,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: badge.valueColor,
          ),
        ),
      ],
    );
    final label = badge.semanticLabel;
    return label == null ? row : Semantics(label: label, child: row);
  }
}
