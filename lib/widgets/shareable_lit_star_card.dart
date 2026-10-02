import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../utils/date_format.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'photo_image.dart';
import 'project_tag.dart';
import 'share_arrangement.dart';

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
    return ShareableStoryLayout(
      title: star.title,
      description: star.description,
      meta: formatDisplayDateTime(star.achievedDate!, strings),
      background: photoPath == null
          ? null
          : PhotoImage(photoPath: photoPath, fit: BoxFit.cover),
      hero: Icon(Icons.star, size: 44, color: colors.gold),
      context: project == null
          ? null
          : Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AreaTag(area: project!.area, iconSize: 20, fontSize: 16),
                ProjectTag(
                  project: project!,
                  textColor: colors.muted,
                  iconSize: 15,
                  fontSize: 14,
                ),
              ],
            ),
      footer: IntensityBolts(
        intensity: star.intensity!,
        size: 24,
        spacing: 5,
        emphasizeLast: true,
      ),
    );
  }
}
