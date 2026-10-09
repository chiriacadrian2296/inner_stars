import 'package:flutter/material.dart';

import 'badge_icon_ink.dart';

/// Every icon a badge uses. The ink measurements in `badge_icon_ink.dart` are
/// generated for exactly this set (`test/widgets/badge_icon_ink_test.dart`
/// fails when they are out of date): add a new badge icon here and rerun it.
const List<IconData> kBadgeIconSet = [
  Icons.bolt_rounded,
  Icons.calendar_month_rounded,
  Icons.delete_outline_rounded,
  Icons.hide_source,
  Icons.star_rounded,
  Icons.star_outline_rounded,
  Icons.circle_outlined,
  Icons.local_fire_department_rounded,
  Icons.event_outlined,
  Icons.photo_library_outlined,
  Icons.insights_outlined,
  Icons.auto_stories_outlined,
  Icons.edit_outlined,
  Icons.mic_none_rounded,
  Icons.videocam_outlined,
  Icons.link_rounded,
  Icons.date_range,
  Icons.import_export,
];

/// The height of an icon's drawing as a fraction of the badge icon's [size];
/// every icon is scaled so its ink is exactly this tall.
const double kBadgeIconInkHeight = 0.86;

/// How far an icon is centred on its weight rather than on its bounding box
/// (0 = the box, 1 = the centre of mass). A star or a flame is heavier below
/// the middle of its box, so centred by the box alone it looks too low.
const double kBadgeIconMassWeight = 1;

/// Icons drawn smaller than the rest, as a fraction of the common size,
/// still centred in their space.
final Map<IconData, double> kBadgeIconRelativeSize = {
  // Areas and Constellations
  Icons.circle_outlined: 0.94,
  // Victories
  Icons.mic_none_rounded: 0.90,
  Icons.photo_library_outlined: 0.85,
  Icons.videocam_outlined: 0.85,
  Icons.link_rounded: 1.00,
};

/// A last vertical nudge for an icon that still looks off, as a fraction of
/// the badge icon's size (negative = up).
final Map<IconData, double> kBadgeIconNudgeY = {
  // Areas and Constellations
  Icons.photo_library_outlined: 0.025,
};

/// The width of the fixed space every badge icon has, as a fraction of its
/// [size]. An icon is centred in it (and a very wide one, the link, stops
/// growing at its edges), so all icons take exactly the same room.
const double kBadgeIconSlotWidth = 1;

/// A badge's icon, drawn so every icon has the same visual size and no empty
/// margin around it: the Material glyph is scaled until its painted part
/// (measured from the font, see [kBadgeIconInk]) is [kBadgeIconInkHeight] of
/// [size] tall, then centred in a fixed space of [kBadgeIconSlotWidth] x
/// [size] (horizontally by its drawing, vertically by its weight). The space
/// is the same for every icon, so gaps to the text and between badges are the
/// same whatever the icon.
///
/// With [endColor] the left half of the drawing is [color] and the right half
/// that colour, with a hard edge down the middle.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon(
    this.icon, {
    super.key,
    required this.size,
    this.color,
    this.endColor,
    this.raw = false,
    this.alignStart = false,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? endColor;

  /// Draw the Material glyph as is, in a [size] square (the badge lab
  /// compares the two).
  final bool raw;

  /// Instead of centring the drawing in the fixed space, start it exactly at
  /// the left edge and make the box only as wide as the drawing: for an icon
  /// that must line up with the text above or below it (the intensity).
  final bool alignStart;

  /// The width of the space every icon takes at [size].
  static double slotWidth(double size) => size * kBadgeIconSlotWidth;

  static double _em(BadgeIconInk ink, double size) {
    final byHeight = size * kBadgeIconInkHeight / ink.height;
    final byWidth = slotWidth(size) / ink.width;
    return byHeight < byWidth ? byHeight : byWidth;
  }

  @override
  Widget build(BuildContext context) {
    final ink = kBadgeIconInk[icon.codePoint];
    final end = endColor;
    if (raw || ink == null) {
      return SizedBox(
        width: slotWidth(size),
        height: size,
        child: Center(
          child: _tinted(Icon(icon, size: size, color: color), 0.5, size, size),
        ),
      );
    }
    final em = _em(ink, size) * (kBadgeIconRelativeSize[icon] ?? 1);
    return SizedBox(
      width: alignStart ? em * ink.width : slotWidth(size),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: alignStart
                ? -em * ink.left
                : (slotWidth(size) - em * ink.width) / 2 - em * ink.left,
            top:
                size / 2 +
                size * (kBadgeIconNudgeY[icon] ?? 0) -
                em *
                    ((ink.top + ink.bottom) / 2 * (1 - kBadgeIconMassWeight) +
                        ink.massY * kBadgeIconMassWeight),
            width: em,
            height: em,
            child: end == null
                ? Icon(icon, size: em, color: color)
                : _tinted(
                    Icon(icon, size: em, color: color),
                    (ink.left + ink.right) / 2,
                    em,
                    em,
                  ),
          ),
        ],
      ),
    );
  }

  /// [glyph] as is, or split down [edge] (a fraction of its width) into the
  /// two colours.
  Widget _tinted(Icon glyph, double edge, double width, double height) {
    final end = endColor;
    if (end == null) return glyph;
    final start = color ?? Colors.white;
    return SizedBox(
      width: width,
      height: height,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [start, start, end, end],
          stops: [0, edge, edge, 1],
        ).createShader(bounds),
        child: Icon(glyph.icon, size: glyph.size, color: Colors.white),
      ),
    );
  }
}
