import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/date_format.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'project_tag.dart';

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
                  Icon(Icons.star_border, size: 44, color: colors.text),
                  const SizedBox(height: 28),
                  Text(
                    star.targetDate == null
                        ? strings.noTargetDateLabel
                        : formatDisplayDate(star.targetDate!, strings),
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
                  if (star.intensity != null) ...[
                    const SizedBox(height: 28),
                    IntensityBolts(
                      intensity: star.intensity!,
                      size: 30,
                      spacing: 6,
                      emphasizeLast: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
