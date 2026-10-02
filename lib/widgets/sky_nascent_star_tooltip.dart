import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import 'search_result_card.dart';
import 'sky_search_tooltip_card.dart';

class SkyNascentStarTooltip extends StatelessWidget {
  const SkyNascentStarTooltip({
    super.key,
    required this.project,
    required this.onClose,
    required this.onView,
    required this.onConfigure,
  });

  final Project project;
  final VoidCallback onClose;
  final VoidCallback onView;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SkySearchTooltipCard(
      menuId: 'tooltip-nascent:${project.id}',
      onTap: onView,
      visual: const SearchStarVisual(kind: StarKind.nascent),
      content: SearchCardTextContent(
        eyebrow: strings.starKindNascentName,
        title: strings.starKindNascentMeaning,
        breadcrumb: '${project.area.displayName(strings)} → ${project.name}',
        metrics: const [],
      ),
      actions: [
        SearchCardAction(
          icon: Icons.auto_awesome,
          label: strings.nascentStarQuickLookConfigureAction,
          onTap: onConfigure,
        ),
      ],
    );
  }
}
