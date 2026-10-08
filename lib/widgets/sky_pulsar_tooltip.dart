import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../utils/star_card_info.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';
import 'star_glyph.dart';

/// How many badges fit on the card's single row, and the body height that
/// makes room for a second one.
const int _kBadgesPerRow = 4;
const double _kTallBodyHeight = 106;

class SkyPulsarTooltip extends StatelessWidget {
  const SkyPulsarTooltip({
    super.key,
    required this.habit,
    required this.project,
    required this.countsByDay,
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

  /// The habit's completions per day (from a cache), what the badges
  /// are computed from.
  final Map<DateTime, int> countsByDay;
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
    final metrics = cardBadgeMetrics(
      habitCardBadges(habit, countsByDay, context.colors, strings),
    );
    return SkySearchTooltipCard(
      menuId: 'tooltip-habit:${habit.id}',
      onTap: onView,
      baseBodyHeight: metrics.length > _kBadgesPerRow ? _kTallBodyHeight : 88,
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
        metrics: metrics,
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
