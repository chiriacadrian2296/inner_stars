import '../models/display_text.dart';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_colors.dart';
import '../utils/icon_for_slug.dart';

/// The standard way a [Project] is shown wherever it appears as a small
/// piece of context: icon + name, deliberately quieter than [AreaTag] —
/// the area is the headline fact, the project is supporting detail.
/// [textColor] defaults to the theme's muted color for the night
/// background; pass the reflection screens' muted color instead there.
class ProjectTag extends StatelessWidget {
  const ProjectTag({
    super.key,
    required this.project,
    this.iconSize = 13,
    this.fontSize = 13,
    this.textColor,
    this.iconColor,
  });

  final Project project;
  final double iconSize;
  final double fontSize;
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
        Icon(
          iconForSlug(project.iconSlug),
          size: iconSize,
          color: iconColor ?? colors.gold,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            project.displayName,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor ?? colors.muted,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
