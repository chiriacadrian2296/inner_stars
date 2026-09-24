import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../utils/date_format.dart';
import 'area_tag.dart';
import 'navigate_here_button.dart';
import 'press_scale.dart';
import 'project_tag.dart';
import 'star_created_at.dart';
import 'star_extra_badge.dart';
import 'star_kind_label.dart';

/// An unlit star (a goal) in a flat star list — [star] is always expected
/// to satisfy [Star.isUnlit].
class UnlitStarCard extends StatelessWidget {
  const UnlitStarCard({
    super.key,
    required this.star,
    this.onTap,
    this.project,
    this.onNavigateTo,
  });

  final Star star;
  final VoidCallback? onTap;
  final Project? project;

  /// Shows a "take me there" corner button when non-null — only passed by
  /// the Sky's search popup, which can actually jump its sky camera
  /// to this star's constellation.
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
                  const StarKindLabel(kind: StarKind.unlit),
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
                    star.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontStarTitle,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      fontSize: 25,
                      color: colors.text,
                    ),
                  ),
                  if (star.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      star.description!,
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
                    icon: Icons.event_outlined,
                    label: star.targetDate == null
                        ? strings.noTargetDateLabel
                        : strings.targetDateBadgeLabel,
                    value: star.targetDate == null
                        ? null
                        : formatDisplayDate(star.targetDate!, strings),
                    dimmed: star.targetDate == null,
                  ),
                  const SizedBox(height: 18),
                  StarCreatedAt(createdAt: star.createdAt),
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
