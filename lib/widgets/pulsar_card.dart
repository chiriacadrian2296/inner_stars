import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import 'area_tag.dart';
import 'intensity_bolts.dart';
import 'navigate_here_button.dart';
import 'press_scale.dart';
import 'project_tag.dart';
import 'star_created_at.dart';
import 'star_extra_badge.dart';
import 'star_kind_label.dart';

/// A pulsar (a habit) in a flat star list — a streak badge alongside the
/// intensity block every burning star carries. [isLit] is the one thing on
/// this card that changes with the day: it flips the kind label between the
/// gold and the no-light family, and dims the title, exactly the way the
/// pulsar itself flips in the sky.
class PulsarCard extends StatelessWidget {
  const PulsarCard({
    super.key,
    required this.habit,
    required this.currentStreak,
    required this.isLit,
    this.onTap,
    this.project,
    this.onNavigateTo,
  });

  final Habit habit;
  final int currentStreak;
  final bool isLit;
  final VoidCallback? onTap;
  final Project? project;

  /// Shows a "take me there" corner button when non-null — only passed by
  /// the Sky's search popup, which can actually jump its sky camera
  /// to this habit's constellation.
  final VoidCallback? onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final borderRadius = BorderRadius.circular(kRadiusCard);

    final card = PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            decoration: panelDecoration(colors),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StarKindLabel(kind: StarKind.pulsar, lit: isLit),
                  if (project != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AreaTag(
                            area: project!.area,
                            iconSize: 18,
                            fontSize: 15,
                          ),
                          const SizedBox(width: 14),
                          ProjectTag(
                            project: project!,
                            iconSize: 15,
                            fontSize: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    habit.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontStarTitle,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      fontSize: 25,
                      color: isLit ? colors.text : colors.muted,
                    ),
                  ),
                  if (habit.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      habit.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  StarExtraBadge(
                    icon: Icons.local_fire_department,
                    label: strings.streakBadgeLabel,
                    value: '$currentStreak',
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: IntensityBolts(
                      intensity: habit.intensity,
                      size: 20,
                      spacing: 4,
                      emphasizeLast: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  StarCreatedAt(createdAt: habit.createdAt),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (onNavigateTo == null) return card;
    return Stack(
      children: [
        card,
        Positioned(
          top: 0,
          bottom: 0,
          right: 6,
          child: Center(
            child: NavigateHereButton(
              onTap: onNavigateTo!,
              tooltip: strings.takeMeThereAction,
            ),
          ),
        ),
      ],
    );
  }
}
