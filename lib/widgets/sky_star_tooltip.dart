import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../utils/date_format.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

class SkyStarTooltip extends StatelessWidget {
  const SkyStarTooltip({
    super.key,
    required this.star,
    required this.project,
    required this.onClose,
    required this.onView,
    required this.onEdit,
    this.onLight,
    this.onShare,
    this.onDelete,
  });

  final Star star;
  final Project? project;
  final VoidCallback onClose;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback? onLight;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final kind = star.kind;
    final metrics = switch (kind) {
      StarKind.lit => [
        SearchCardMetric(
          icon: Icons.bolt_rounded,
          value: '${star.intensity ?? 0}',
        ),
        if (star.photoPath != null)
          const SearchCardMetric(icon: Icons.photo_camera_rounded),
      ],
      StarKind.unlit => [
        SearchCardMetric(
          icon: Icons.calendar_month_rounded,
          value: star.targetDate == null
              ? '—'
              : formatDisplayDate(star.targetDate!, strings),
        ),
      ],
      StarKind.dead => [
        SearchCardMetric(
          icon: Icons.cancel_outlined,
          value: star.deadDate == null
              ? '—'
              : formatDisplayDate(star.deadDate!, strings),
        ),
      ],
      StarKind.pulsar || StarKind.nascent => const <SearchCardMetric>[],
    };
    return SkySearchTooltipCard(
      menuId: 'tooltip-star:${star.id}',
      onTap: onView,
      visual: SearchStarVisual(kind: kind),
      content: SearchCardTextContent(
        eyebrow: kind.label(strings),
        title: star.title,
        breadcrumb: project == null
            ? null
            : '${project!.area.displayName(strings)} → ${project!.name}',
        metrics: metrics,
      ),
      actions: [
        if (star.dead)
          SearchCardAction(
            icon: Icons.model_training,
            label: strings.actionReignite,
            onTap: onEdit,
          )
        else if (onLight != null)
          SearchCardAction(
            icon: Icons.power_settings_new_rounded,
            label: strings.actionLight,
            onTap: onLight!,
          ),
        if (onShare != null)
          SearchCardAction(
            icon: Icons.share_outlined,
            label: strings.starQuickLookShareAction,
            onTap: onShare!,
          ),
        if (!star.dead)
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
