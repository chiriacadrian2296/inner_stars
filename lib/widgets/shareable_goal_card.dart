import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../utils/date_format.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'project_tag.dart';
import 'share_arrangement.dart';

/// A static duplicate of the unlit-star layout (see [ShareableLitStarCard],
/// its lit-star counterpart) — exists only to be captured as an image via a
/// [RepaintBoundary] wrapped around it (see `SkyScreen`'s own creation
/// share flow). Only ever built for a freshly set goal, so no photo, and
/// [Star.intensity] may still be unset — a goal only requires one once it's
/// actually lit.
class ShareableGoalCard extends StatelessWidget {
  const ShareableGoalCard({super.key, required this.star, this.project});

  final Star star;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return ShareableStoryLayout(
      title: star.title,
      description: star.description,
      meta: star.targetDate == null
          ? strings.noTargetDateLabel
          : formatDisplayDate(star.targetDate!, strings),
      hero: Icon(Icons.star_border, size: 44, color: colors.text),
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
      footer: star.intensity == null
          ? null
          : IntensityBolts(
              intensity: star.intensity!,
              size: 24,
              spacing: 5,
              emphasizeLast: true,
            ),
    );
  }
}
