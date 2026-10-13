import '../utils/area_section_icons.dart';
import '../utils/entity_insights.dart';

import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../models/life_area.dart';
import '../utils/area_hero_art.dart';
import '../utils/star_card_info.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

class SkyAreaTooltip extends StatelessWidget {
  const SkyAreaTooltip({
    super.key,
    required this.area,
    required this.badges,
    required this.onClose,
    required this.onView,
    required this.onVision,
    required this.onMoodboard,
    required this.onReflections,
    required this.onNewConstellation,
  });

  final LifeArea area;

  /// The area's badges.
  final CardBadges badges;
  final VoidCallback onClose;
  final VoidCallback onView;
  final VoidCallback onVision;
  final VoidCallback onMoodboard;
  final VoidCallback onReflections;
  final VoidCallback onNewConstellation;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SkySearchTooltipCard(
      entity: InsightEntity.area(area),
      menuId: 'tooltip-area:${area.name}',
      onTap: onView,
      baseBodyHeight: SearchResultCard.bodyHeightFor(badges),
      fillVisualHeight: true,
      centerVisual: true,
      visual: SearchArtworkVisual(
        asset: kAreaHeroArt[area]?.skyAsset,
        fallbackIcon: Icons.flare,
        framed: true,
      ),
      content: SearchCardTextContent(
        eyebrow: strings.galaxyAreaLabel,
        eyebrowColor: context.colors.gold,
        title: area.displayName(strings),
        breadcrumb: strings.galaxyLabel,
        badges: badges,
      ),
      actions: [
        SearchCardAction(
          icon: Icons.insights,
          label: strings.areaQuickLookNewConstellationAction,
          onTap: onNewConstellation,
          isNew: true,
        ),
        SearchCardAction(
          icon: kAreaVisionIcon,
          label: strings.visionPageTitle,
          onTap: onVision,
          group: 1,
        ),
        SearchCardAction(
          icon: kAreaMoodboardIcon,
          label: strings.moodboardTitle,
          onTap: onMoodboard,
          group: 1,
        ),
        SearchCardAction(
          icon: kAreaReflectionsIcon,
          label: strings.areaQuickLookReflectionsAction,
          onTap: onReflections,
          group: 1,
        ),
      ],
    );
  }
}
