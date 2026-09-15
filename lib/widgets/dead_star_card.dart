import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../utils/date_format.dart';
import 'area_tag.dart';
import 'navigate_here_button.dart';
import 'project_tag.dart';
import 'star_created_at.dart';
import 'star_extra_badge.dart';
import 'star_kind_label.dart';

/// A dead star in a flat star list. The title stays muted so it visibly
/// reads as "spent" next to lit and unlit stars; everything else matches
/// every other card's look. Tapping it opens the flow that reignites it.
///
/// Built from either a tombstoned [Star] or a tombstoned [Habit] — both
/// really are dead stars, and both render identically here except for
/// [wasPulsar], which is the whole reason they're kept apart: a dead star
/// can only ever be reignited as the kind it was, so the card has to say
/// which that is.
class DeadStarCard extends StatelessWidget {
  const DeadStarCard._({
    required this.title,
    required this.createdAt,
    required this.deadDate,
    required this.wasPulsar,
    this.onTap,
    this.project,
    this.onNavigateTo,
  });

  /// [star] is always expected to satisfy `star.dead`.
  factory DeadStarCard.fromStar({
    required Star star,
    Project? project,
    VoidCallback? onTap,
    VoidCallback? onNavigateTo,
  }) {
    return DeadStarCard._(
      title: star.title,
      createdAt: star.createdAt,
      deadDate: star.deadDate,
      wasPulsar: false,
      project: project,
      onTap: onTap,
      onNavigateTo: onNavigateTo,
    );
  }

  /// [habit] is always expected to satisfy `habit.dead`.
  factory DeadStarCard.fromHabit({
    required Habit habit,
    Project? project,
    VoidCallback? onTap,
    VoidCallback? onNavigateTo,
  }) {
    return DeadStarCard._(
      title: habit.title,
      createdAt: habit.createdAt,
      deadDate: habit.deadDate,
      wasPulsar: true,
      project: project,
      onTap: onTap,
      onNavigateTo: onNavigateTo,
    );
  }

  final String title;
  final DateTime createdAt;
  final DateTime? deadDate;

  /// Whether this used to be a pulsar rather than a star on a
  /// constellation's shape — which is exactly what it will come back as.
  final bool wasPulsar;

  final VoidCallback? onTap;
  final Project? project;

  /// Shows a "take me there" corner button when non-null — only passed by
  /// the Sky's search popup, which can actually jump its camera to this
  /// star's constellation.
  final VoidCallback? onNavigateTo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final borderRadius = BorderRadius.circular(kRadiusCard);

    final card = Material(
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
                const StarKindLabel(kind: StarKind.dead),
                if (wasPulsar) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      StarKind.pulsar.label(strings),
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  ),
                ],
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
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kFontStarTitle,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    fontSize: 25,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                StarExtraBadge(
                  icon: Icons.church,
                  label: deadDate == null
                      ? strings.noDeadDateLabel
                      : strings.deadDateBadgeLabel,
                  value: deadDate == null
                      ? null
                      : formatDisplayDate(deadDate!, strings),
                  dimmed: deadDate == null,
                ),
                const SizedBox(height: 18),
                StarCreatedAt(createdAt: createdAt),
              ],
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
