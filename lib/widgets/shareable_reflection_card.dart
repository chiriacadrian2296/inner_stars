import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/reflection.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'area_icon.dart';
import 'share_arrangement.dart';

/// Sharing never alters the saved reflection. Long text is an excerpt in the card.
class ShareableReflectionCard extends StatelessWidget {
  const ShareableReflectionCard({
    super.key,
    required this.reflection,
    this.bodyOverride,
    this.showBody = true,
  });
  final Reflection reflection;
  final String? bodyOverride;
  final bool showBody;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final arrangement = ShareArrangementScope.of(context);
    final centered = arrangement == ShareArrangement.statement;
    return ColoredBox(
      color: colors.night,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final body = bodyOverride ?? reflection.body;
            // Allocate a bounded excerpt even with very long titles or accessibility text.
            final bodyLines = ((bounds.maxHeight - 250) / 27).floor().clamp(
              1,
              14,
            );
            return Column(
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  'INNER STARS',
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                AreaIcon(
                  area: reflection.area,
                  size: arrangement == ShareArrangement.photographic ? 60 : 36,
                ),
                const SizedBox(height: 14),
                Text(
                  reflection.area.displayName(context.strings),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.gold,
                    fontFamily: kFontMono,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  reflection.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontStarTitle,
                    fontSize: 26,
                    height: 1.25,
                  ),
                ),
                if (showBody && body.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Flexible(
                    child: Text(
                      body,
                      maxLines: bodyLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 17,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}
