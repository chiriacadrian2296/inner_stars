import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'project_tag.dart';

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

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(decoration: BoxDecoration(gradient: colors.nightlightGradient)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(StarKind.pulsar.icon, size: 44, color: colors.gold),
                  const SizedBox(height: 28),
                  if (project != null) ...[
                    AreaTag(area: project!.area, iconSize: 24, fontSize: 21),
                    const SizedBox(height: 8),
                    ProjectTag(
                      project: project!,
                      textColor: colors.nightlightMuted,
                      iconSize: 17,
                      fontSize: 17,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    habit.title,
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
                  if (habit.description != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      habit.description!,
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
                    intensity: habit.intensity,
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
