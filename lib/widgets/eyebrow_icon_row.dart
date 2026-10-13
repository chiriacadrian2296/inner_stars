import 'package:flutter/material.dart';

import '../models/star_kind.dart';
import '../utils/icon_for_slug.dart';

/// A card's type label followed by " - " and the element's own icon
/// ("COSTELLAZIONE - icon"), the way an area's label is followed by its count
/// (see `EyebrowWithBadge`). [label] is the already-styled label widget.
class EyebrowIconRow extends StatelessWidget {
  const EyebrowIconRow({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.fontSize = 9.5,
    this.scale = 1,
  });

  final Widget label;
  final IconData icon;

  /// The icon matches the label's colour (the kind's).
  final Color color;

  /// The label's font size; the dash and the icon follow it.
  final double fontSize;

  /// 1 = the tooltip's own size.
  final double scale;

  /// The icon of an element: its own icon when it has one, else its kind's.
  static IconData iconFor(String slug, StarKind fallbackKind) =>
      slug.isEmpty ? fallbackKind.icon : iconForSlug(slug);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: label),
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
        Icon(icon, size: fontSize * 1.4, color: color),
      ],
    );
  }
}
