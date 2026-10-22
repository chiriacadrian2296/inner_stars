import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Introduces one of the pages that belong to a life area.
class AreaSectionHeader extends StatelessWidget {
  const AreaSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.description,
    this.descriptionChild,
  }) : assert(description != null || descriptionChild != null);

  final String title;

  /// Shown after the title ("Social - icon"), sized to the title text.
  final IconData? icon;
  final String? description;
  final Widget? descriptionChild;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon, dot and area name, centred as one line. A Row (rather than an
        // inline icon in the text) keeps the icon centred on the text line.
        Builder(
          builder: (context) {
            final style = TextStyle(
              color: colors.text,
              fontFamily: kFontStarTitle,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 34, color: colors.text),
                  const SizedBox(width: 10),
                  Text('\u00b7', style: style),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(title, textAlign: TextAlign.center, style: style),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        descriptionChild ??
            Text(
              description!,
              style: TextStyle(color: colors.muted, fontSize: 15, height: 1.5),
            ),
      ],
    );
  }
}
