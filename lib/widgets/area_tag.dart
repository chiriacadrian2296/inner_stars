import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import 'area_icon.dart';

/// The standard way a [LifeArea] is shown wherever it appears as a small
/// piece of context (win cards, the reader, the add/edit form): icon + name
/// in bold, deliberately louder than [ProjectTag] — the area is the more
/// stable, top-level fact about a win, and should read as such at a glance
/// no matter which screen it's on.
class AreaTag extends StatelessWidget {
  const AreaTag({
    super.key,
    required this.area,
    this.iconSize = 16,
    this.fontSize = 15,
    this.textColor,
    this.iconColor,
  });

  final LifeArea area;
  final double iconSize;
  final double fontSize;

  /// Defaults to the theme's primary text color — bold weight and the gold
  /// icon already make this read as the "loud" fact described above without
  /// needing gold text too. Overridable for screens that want a different
  /// tone (e.g. the reflection-screen gradient).
  final Color? textColor;

  /// Defaults to gold. Overridable for a card that deliberately shows no
  /// gold anywhere (e.g. [DeadStarCard]'s fully-muted look), so it can still
  /// reuse this widget instead of a bespoke plain-text fallback.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AreaIcon(area: area, size: iconSize, color: iconColor),
        const SizedBox(width: 6),
        Text(
          area.displayName(context.strings),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: textColor ?? colors.text,
          ),
        ),
      ],
    );
  }
}
