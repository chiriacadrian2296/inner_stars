import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'project_tag.dart';
import 'share_arrangement.dart';

/// A static duplicate of the pulsar layout (see [ShareableLitStarCard], the
/// lit-star original this family follows) — exists only to be captured as
/// an image via a [RepaintBoundary] wrapped around it (see `SkyScreen`'s
/// own creation share flow). Only ever built for a freshly created pulsar,
/// so its streak is always zero — there's been no day for it to keep the
/// rhythm on yet.
class ShareablePulsarCard extends StatelessWidget {
  const ShareablePulsarCard({super.key, required this.habit, this.project});

  final Habit habit;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ShareableStoryLayout(
      title: habit.title,
      description: habit.description,
      hero: Icon(StarKind.pulsar.icon, size: 44, color: colors.gold),
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
        intensity: habit.intensity,
        size: 24,
        spacing: 5,
        emphasizeLast: true,
      ),
    );
  }
}
