import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

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
