import 'package:flutter/material.dart';

import '../data/constellation_shape.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../utils/star_card_info.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

/// A constellation quick-look rendered with the same compact card used by
/// Sky's search results, including its expanding action drawer.
class SkyConstellationTooltip extends StatelessWidget {
  const SkyConstellationTooltip({
    super.key,
    required this.project,
    required this.badges,
    required this.shape,
    required this.onClose,
    required this.onView,
    required this.onAddStar,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  final Project project;

  /// The constellation's badges in their fixed rows.
  final List<List<CardBadge>> badges;
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
    return SkySearchTooltipCard(
      menuId: 'tooltip-project:${project.id}',
      onTap: onView,
      baseBodyHeight: SearchResultCard.bodyHeightForRows(badges.length),
      visual: SearchConstellationVisual(
        shape: shape,
        darkBackground: false,
        inset: 17,
      ),
      content: SearchCardTextContent(
        title: project.name,
        breadcrumb: project.area.displayName(strings),
        badgeRows: badges,
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
