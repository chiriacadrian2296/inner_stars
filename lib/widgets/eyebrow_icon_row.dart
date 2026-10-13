import 'package:flutter/material.dart';

import '../utils/icon_for_slug.dart';
import '../utils/star_card_info.dart' show CardBadge;
import 'badge_rows.dart';

/// How large an item's icon is drawn, as a fraction of its slot. The icons
/// are picked by the user, so there is no curated set to measure and this one
/// size serves them all.
const double _itemGlyphScale = 1.0;

/// Items' icons sit a little high in their slot, like the area's (as a
/// fraction of the slot; negative = up).
const double _itemGlyphDy = -0.0275;

/// A card's type label followed by " - ", an icon and optionally a value:
/// "AREA - icon 12", "COSTELLAZIONE - icon", "VITTORIA - icon". One widget
/// for all three levels of Sky and Galaxy cards; only the label, the icon and
/// its colour (and the area's count) change.
class EyebrowIconRow extends StatelessWidget {
  const EyebrowIconRow({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.fontSize = 9.5,
    this.scale = 1,
    this.secondLabel,
    this.glyphScale = _itemGlyphScale,
    this.glyphDy = _itemGlyphDy,
    this.value,
    this.valueColor,
  });

  /// An area's label: the constellation count after its icon, as the card's
  /// title badge describes it. Its glyph is drawn the way the badge icon
  /// draws it (`insights_outlined` is width-limited in its slot and sits a
  /// little high), but as a plain icon.
  factory EyebrowIconRow.forBadge({
    Key? key,
    required String label,
    required Color color,
    required CardBadge badge,
    double fontSize = 9.5,
    double letterSpacing = 0.7,
    double scale = 1,
  }) => EyebrowIconRow(
    key: key,
    label: Text(
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
    icon: badge.icon,
    color: badge.iconColor,
    fontSize: fontSize,
    scale: scale,
    glyphScale: 1.0861,
    glyphDy: -0.0275,
    value: badge.value,
    valueColor: badge.valueColor,
  );

  final Widget label;
  final IconData? icon;

  /// A second label after the first, joined by a dash (an archived element:
  /// "DEAD STAR - GOAL").
  final Widget? secondLabel;

  /// The icon's colour (the label's, for an element's kind).
  final Color color;

  /// The label's font size; the dash, icon and value follow it.
  final double fontSize;

  /// 1 = the tooltip's own size.
  final double scale;

  /// The icon's size as a fraction of its slot, and how far it is moved
  /// down, as a fraction of the slot.
  final double glyphScale;
  final double glyphDy;

  /// A value shown after the icon (an area's constellation count).
  final String? value;
  final Color? valueColor;

  /// The element's own icon, or null when the user picked none: the kind's
  /// icon is already on the card, so a fallback would only repeat it.
  static IconData? chosenIcon(String slug) =>
      slug.isEmpty ? null : iconForSlug(slug);

  @override
  Widget build(BuildContext context) {
    // The slot is the size of a badge icon at this text size.
    final slot = fontSize * BadgeRows.iconSize / BadgeRows.textSize;
    final dash = [
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
    ];
    final glyph = icon;
    return Row(
      children: [
        Flexible(child: label),
        if (secondLabel != null) ...[...dash, Flexible(child: secondLabel!)],
        if (glyph != null) ...[
          ...dash,
          SizedBox(
            width: slot,
            height: slot,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, glyphDy * slot),
                child: Icon(glyph, size: slot * glyphScale, color: color),
              ),
            ),
          ),
        ],
        if (value != null) ...[
          SizedBox(width: 4 * scale),
          Text(
            value!,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: valueColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
