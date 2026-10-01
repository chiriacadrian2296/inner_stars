import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// The one fact unique to a star's kind — a photo, a target date, a death
/// date, or a streak — shown centered between the description and the
/// intensity/date block, always in the same spot across every card. When
/// the kind doesn't have one to show (e.g. no photo attached), pass
/// [dimmed] true with a "no X" [label] instead of omitting the badge
/// entirely — every card keeps the same layout either way.
class StarExtraBadge extends StatelessWidget {
  const StarExtraBadge({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;

  /// Appended after [label] (e.g. a date or a streak count) — omitted for
  /// a badge that's just "this is true" (the photo badge has no value of
  /// its own beyond its presence) or when [dimmed].
  final String? value;

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = dimmed ? colors.muted : colors.gold;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 6),
            Text(
              value!,
              style: TextStyle(
                fontSize: 14,
                fontFamily: kFontMono,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
