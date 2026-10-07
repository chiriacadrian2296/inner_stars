import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';
import 'star_glyph.dart';

class SkyPulsarTooltip extends StatelessWidget {
  const SkyPulsarTooltip({
    super.key,
    required this.habit,
    required this.project,
    required this.currentStreak,
    required this.isLit,
    required this.onClose,
    required this.onView,
    required this.onToday,
    this.onTodayDecrement,
    this.stepperText,
    required this.todayActionIcon,
    required this.todayActionLabel,
    required this.onEdit,
    this.onDelete,
    this.onShare,
  });

  final Habit habit;
  final Project? project;
  final int currentStreak;
  final bool isLit;
  final VoidCallback onClose;
  final VoidCallback onView;
  final VoidCallback onToday;

  /// For a habit done several times a day: takes one instance back (null
  /// when there is none to take). With [stepperText] it draws as a grouped
  /// minus / count / plus.
  final VoidCallback? onTodayDecrement;
  final String? stepperText;
  final IconData todayActionIcon;
  final String todayActionLabel;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SkySearchTooltipCard(
      menuId: 'tooltip-habit:${habit.id}',
      onTap: onView,
      visual: SearchStarVisual(kind: StarKind.pulsar, pulsarLit: isLit),
      content: SearchCardTextContent(
        eyebrow: StarKind.pulsar.label(strings),
        eyebrowColor: habit.dead
            ? starKindColor(StarKind.dead, context.colors)
            : starKindColor(StarKind.pulsar, context.colors, lit: isLit),
        title: habit.title,
        breadcrumb: project == null
            ? null
            : '${project!.area.displayName(strings)} → ${project!.name}',
        metrics: [
          SearchCardMetric(
            icon: Icons.local_fire_department_rounded,
            value: '$currentStreak',
          ),
          SearchCardMetric(
            icon: Icons.bolt_rounded,
            value: '${habit.intensity}',
          ),
        ],
      ),
      actions: [
        if (habit.dead)
          SearchCardAction(
            icon: Icons.model_training,
            label: strings.actionReignite,
            onTap: onEdit,
          )
        else
          SearchCardAction(
            icon: todayActionIcon,
            label: todayActionLabel,
            onTap: onToday,
            onDecrement: onTodayDecrement,
            stepperText: stepperText,
          ),
        if (onShare != null)
          SearchCardAction(
            icon: Icons.share_outlined,
            label: strings.starQuickLookShareAction,
            onTap: onShare!,
          ),
        if (!habit.dead)
          SearchCardAction(
            icon: Icons.edit_rounded,
            label: strings.starQuickLookEditAction,
            onTap: onEdit,
          ),
        if (onDelete != null)
          SearchCardAction(
            icon: Icons.delete_outline_rounded,
            label: strings.deleteStarAction,
            onTap: onDelete!,
          ),
      ],
    );
  }
}
