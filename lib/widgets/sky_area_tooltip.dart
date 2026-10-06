import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../utils/area_hero_art.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

class SkyAreaTooltip extends StatelessWidget {
  const SkyAreaTooltip({
    super.key,
    required this.area,
    required this.starCount,
    required this.onClose,
    required this.onView,
    required this.onVision,
    required this.onMoodboard,
    required this.onReflections,
    required this.onNewConstellation,
  });

  final LifeArea area;
  final int starCount;
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
      menuId: 'tooltip-area:${area.name}',
      onTap: onView,
      visual: SearchArtworkVisual(
        asset: kAreaHeroArt[area]?.skyAsset,
        fallbackIcon: Icons.flare,
      ),
      content: SearchCardTextContent(
        title: area.displayName(strings),
        metrics: [
          SearchCardMetric(
            icon: Icons.star_outline_rounded,
            value: '$starCount',
          ),
        ],
      ),
      actions: [
        SearchCardAction(
          icon: Icons.edit_outlined,
          label: strings.visionPageTitle,
          onTap: onVision,
        ),
        SearchCardAction(
          icon: Icons.photo_library_outlined,
          label: strings.moodboardTitle,
          onTap: onMoodboard,
        ),
        SearchCardAction(
          icon: Icons.auto_stories_outlined,
          label: strings.areaQuickLookReflectionsAction,
          onTap: onReflections,
        ),
        SearchCardAction(
          icon: Icons.insights,
          label: strings.areaQuickLookNewConstellationAction,
          onTap: onNewConstellation,
        ),
      ],
    );
  }
}
