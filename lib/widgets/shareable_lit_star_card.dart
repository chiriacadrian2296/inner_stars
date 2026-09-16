import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/date_format.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'photo_image.dart';
import 'project_tag.dart';

/// A static duplicate of `StarReaderScreen`'s own lit-star layout, with
/// none of the close/edit/prev-next chrome — exists only to be captured as
/// an image via a [RepaintBoundary] wrapped around it (see
/// `StarReaderScreen._shareCurrent` and `SkyScreen._shareQuickLookStar`,
/// the two places that do so). Only ever built for an achieved
/// star, so [Star.achievedDate]/[Star.intensity] are always non-null here.
class ShareableLitStarCard extends StatelessWidget {
  const ShareableLitStarCard({super.key, required this.star, this.project});

  final Star star;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final photoPath = star.photoPath;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (photoPath != null)
          PhotoImage(
            photoPath: photoPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        Container(
          decoration: BoxDecoration(
            gradient: photoPath == null
                ? colors.nightlightGradient
                : RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 1.2,
                    colors: [
                      colors.nightlightGradientCenter.withValues(alpha: 0.55),
                      colors.nightlightGradientMid.withValues(alpha: 0.75),
                      colors.nightlightGradientOuter.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 44, color: colors.gold),
                  const SizedBox(height: 28),
                  Text(
                    formatDisplayDateTime(star.achievedDate!, strings),
                    style: TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 15,
                      color: colors.nightlightMuted,
                    ),
                  ),
                  if (project != null) ...[
                    const SizedBox(height: 16),
                    AreaTag(area: project!.area, iconSize: 24, fontSize: 21),
                    const SizedBox(height: 8),
                    ProjectTag(
                      project: project!,
                      textColor: colors.nightlightMuted,
                      iconSize: 17,
                      fontSize: 17,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    star.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontStarTitle,
                      fontStyle: FontStyle.italic,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: colors.text,
                    ),
                  ),
                  if (star.description != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      star.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: colors.nightlightMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  IntensityBolts(
                    intensity: star.intensity!,
                    size: 30,
                    spacing: 6,
                    emphasizeLast: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
