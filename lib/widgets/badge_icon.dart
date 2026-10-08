import 'package:flutter/material.dart';

/// Material icons all sit in the same 24 px box but fill it very differently
/// (a bolt is thin, a calendar nearly square, "insights" almost edge to
/// edge), so at the same nominal size they read as different sizes. Each
/// badge icon gets a factor that evens out what the eye sees.
///
/// The factors come from measuring the painted glyph of each icon (its ink
/// box inside the em square) and aiming every one at the same visual size —
/// half its longest side plus half the geometric mean of its two sides —
/// kept between 0.8 and 1.35. An icon not listed here is drawn at its
/// nominal size; add its factor when a new badge icon is introduced.
final Map<IconData, double> kBadgeIconScale = {
  Icons.bolt_rounded: 1.1,
  Icons.calendar_month_rounded: 0.96,
  Icons.cancel_outlined: 0.94,
  Icons.star_rounded: 1.10,
  Icons.star_outline_rounded: 1.10,
  Icons.circle_outlined: 0.94,
  Icons.local_fire_department_rounded: 1.10,
  Icons.event_outlined: 0.96,
  Icons.photo_library_outlined: 0.75,
  Icons.insights_outlined: 0.90,
  Icons.auto_stories_outlined: 0.87,
  Icons.edit_outlined: 1.04,
  Icons.mic_none_rounded: 1.06,
  Icons.videocam_outlined: 1.15,
  Icons.link_rounded: 0.65,
  Icons.date_range: 0.96,
  Icons.import_export: 1.11,
};

/// How far each icon's drawing starts from the left edge of its box, as a
/// fraction of the box (measured like [kBadgeIconScale]). The first icon of a
/// row is pulled left by this much so its drawing — not its empty margin —
/// lines up with the text above it.
final Map<IconData, double> kBadgeIconLeftInset = {
  Icons.bolt_rounded: 0.2875,
  Icons.calendar_month_rounded: 0.125,
  Icons.cancel_outlined: 0.0833,
  Icons.star_rounded: 0.1417,
  Icons.star_outline_rounded: 0.1417,
  Icons.circle_outlined: 0.0833,
  Icons.local_fire_department_rounded: 0.1625,
  Icons.event_outlined: 0.125,
  Icons.photo_library_outlined: 0.0833,
  Icons.insights_outlined: 0.0375,
  Icons.auto_stories_outlined: 0.0375,
  Icons.edit_outlined: 0.125,
  Icons.mic_none_rounded: 0.2083,
  Icons.videocam_outlined: 0.125,
  Icons.link_rounded: 0.0833,
  Icons.date_range: 0.125,
  Icons.import_export: 0.2083,
};

/// A badge's icon at [size], corrected so it looks the same size as every
/// other badge icon (see [kBadgeIconScale]). With [trimLeading] the empty
/// margin to the left of its drawing is cut off (it still paints where it
/// would have), so the first icon of a row starts on the same line as the
/// text around it.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon(
    this.icon, {
    super.key,
    required this.size,
    this.color,
    this.trimLeading = false,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final bool trimLeading;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      icon,
      size: size * (kBadgeIconScale[icon] ?? 1),
      color: color,
    );
    if (!trimLeading) return glyph;
    final inset = kBadgeIconLeftInset[icon] ?? 0;
    return Align(
      alignment: Alignment.centerRight,
      widthFactor: 1 - inset,
      child: glyph,
    );
  }
}
