import 'package:flutter/material.dart';

import '../data/constellation_shape.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

/// A constellation quick-look rendered with the same compact card used by
/// Sky's search results, including its expanding action drawer.
class SkyConstellationTooltip extends StatelessWidget {
  const SkyConstellationTooltip({
    super.key,
    required this.project,
    required this.stars,
    required this.shape,
    required this.onClose,
    required this.onView,
    required this.onAddStar,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  final Project project;
  final List<Star> stars;
  final ConstellationShape? shape;
  final VoidCallback onClose;
  final VoidCallback onView;
  final VoidCallback onAddStar;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final litStars = stars.where((star) => star.isLit).length;
    final unlitStars = stars.where((star) => star.isUnlit).length;
    return SkySearchTooltipCard(
      menuId: 'tooltip-project:${project.id}',
      onTap: onView,
      visual: SearchConstellationVisual(shape: shape),
      content: SearchCardTextContent(
        title: project.name,
        breadcrumb: project.area.displayName(strings),
        metrics: [
          SearchCardMetric(icon: Icons.star_rounded, value: '$litStars'),
          SearchCardMetric(
            icon: Icons.star_outline_rounded,
            value: '$unlitStars',
          ),
        ],
      ),
      actions: [
        SearchCardAction(
          icon: Icons.star_rounded,
          label: strings.constellationQuickLookAddStarAction,
          onTap: onAddStar,
        ),
        SearchCardAction(
          icon: Icons.share_outlined,
          label: strings.starQuickLookShareAction,
          onTap: onShare,
        ),
        SearchCardAction(
          icon: Icons.edit_outlined,
          label: strings.starQuickLookEditAction,
          onTap: onEdit,
        ),
        SearchCardAction(
          icon: Icons.delete_outline_rounded,
          label: strings.deleteStarAction,
          onTap: onDelete,
        ),
      ],
    );
  }
}
