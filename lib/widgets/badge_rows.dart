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
  const BadgeRows({
    super.key,
    required this.rows,
    this.maxScale = 1,
    this.debug = false,
    this.rawIcons = false,
  });

  final List<List<CardBadge>> rows;

  /// The largest scale to draw at (1 = the tooltip's own size).
  final double maxScale;

  /// Tint the boxes of each cell, icon and text (the badge lab).
  final bool debug;

  /// Draw the icons without the optical corrections (the badge lab).
  final bool rawIcons;

  /// A badge at scale 1: the icon, the value's text and the gap between rows.
  static const double iconSize = 14;
  static const double textSize = 11.5;
  static const double rowGap = 4;

  /// The smallest gap between two badges (a slot's width includes it).
  static const double _gap = 8;

  /// A badge with a one-digit value at scale 1: the icon, its gap and a digit.
  static const double _typicalBadgeWidth = 14 + 4 + 7;

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
        final bounded = width.isFinite;
        // What a victory's row would leave between two badges at this width,
        // for values of one digit: a row of only two badges keeps that gap
        // instead of stretching them apart.
        final victoryBadges = kBadgeRows[BadgeCardKind.victory]!.single.length;
        final victoryGap = bounded
            ? math.max(
                _gap * scale,
                (width - victoryBadges * _typicalBadgeWidth * scale) /
                    (victoryBadges - 1),
              )
            : _gap * scale;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap * scale),
              // Each badge is as wide as what it shows (icon, gap, value).
              // The width left over is shared out as equal gaps *between*
              // those, edge to edge, so the space between two badges is the
              // same whatever they hold. With only two badges they keep the
              // victory gap instead; unbounded, the gap is the smallest one.
              Row(
                mainAxisAlignment: bounded && rows[i].length > 2
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  for (var j = 0; j < rows[i].length; j++) ...[
                    if (j > 0)
                      SizedBox(
                        width: rows[i].length == 2
                            ? victoryGap
                            : (bounded ? 0 : _gap * scale),
                      ),
                    _BadgeCell(
                      badge: rows[i][j],
                      scale: scale,
                      first: j == 0,
                      debug: debug,
                      rawIcons: rawIcons,
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
    this.debug = false,
    this.rawIcons = false,
  });

  /// The first badge of a row: its drawing starts at the row's left edge, in
  /// line with the texts and the intensity above it.
  final bool first;
  final bool debug;
  final bool rawIcons;
  final CardBadge badge;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cell = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tint(
          BadgeIcon(
            badge.icon,
            size: BadgeRows.iconSize * scale,
            color: badge.iconColor,
            endColor: badge.iconColorEnd,
            raw: rawIcons,
            alignStart: first,
          ),
          Colors.greenAccent,
        ),
        SizedBox(width: 4 * scale),
        _tint(
          Text(
            badge.value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: BadgeRows.textSize * scale,
              fontWeight: FontWeight.w700,
              color: badge.valueColor,
            ),
          ),
          Colors.redAccent,
        ),
      ],
    );
    final tinted = debug
        ? ColoredBox(color: Colors.blue.withValues(alpha: 0.22), child: cell)
        : cell;
    final label = badge.semanticLabel;
    return label == null ? tinted : Semantics(label: label, child: tinted);
  }

  /// In debug mode, the [child]'s box tinted with a translucent [color].
  Widget _tint(Widget child, Color color) => debug
      ? ColoredBox(color: color.withValues(alpha: 0.35), child: child)
      : child;
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
          alignStart: true,
        ),
        SizedBox(width: 4 * scale),
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

/// The kind label above a title with, after a white dash, a badge (an area's
/// number of constellations): `SUPERNOVA - ✧ 5`. The value and the dash have
/// the label's size; the icon is a little bigger than the other badges' to
/// sit well on this row.
class EyebrowWithBadge extends StatelessWidget {
  const EyebrowWithBadge({
    super.key,
    required this.label,
    required this.color,
    required this.badge,
    this.fontSize = 9.5,
    this.letterSpacing = 0.7,
    this.scale = 1,
  });

  final String label;
  final Color color;
  final CardBadge badge;
  final double fontSize;
  final double letterSpacing;

  /// 1 = the tooltip's own size.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: letterSpacing,
            ),
          ),
        ),
        SizedBox(width: 5 * scale),
        Text(
          '-',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 5 * scale),
        BadgeIcon(
          badge.icon,
          // The icon follows the value's size, like in every other badge.
          size: fontSize * BadgeRows.iconSize / BadgeRows.textSize,
          color: badge.iconColor,
        ),
        SizedBox(width: 4 * scale),
        Text(
          badge.value,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: badge.valueColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
