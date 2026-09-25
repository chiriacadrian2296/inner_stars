import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'area_tag.dart';
import 'project_tag.dart';
import 'sky_tooltip_header.dart';

/// The content shown inside the `tooltip_card` popup after holding an
/// empty, nascent slot on a constellation's shape — same "just enough to
/// glance at, one action below" shape [SkyPulsarTooltip]/
/// [SkyConstellationTooltip] already use. There's nothing to read yet (no
/// title, no description, no badges — an empty slot has none of those),
/// so this is the plainest of the bunch: what it is, whose shape it's on,
/// and the one thing you can actually do with it.
///
/// Reached only from a hold (see `SkyScreen._openNascentStarQuickLook`).
/// [onView] opens the slot's own page, [onConfigure] goes straight to the
/// form.
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

  /// Opens the slot's own page (see `NascentStarReaderScreen`).
  final VoidCallback onView;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Column(
      mainAxisSize: MainAxisSize.min,
      // See [SkyStarTooltip]'s own doc comment on its Column for why
      // `stretch` — same reasoning, so the tag row below gets the full
      // width it needs to center itself within.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkyTooltipHeader(
          icon: StarKind.nascent.icon,
          iconColor: colors.starNascent,
          title: strings.starKindNascentName,
          titleColor: colors.muted,
          onClose: onClose,
        ),
        const SizedBox(height: 8),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ProjectTag(project: project, textColor: colors.muted, iconSize: 14, fontSize: 13),
              AreaTag(area: project.area, iconSize: 14, fontSize: 13),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          strings.starKindNascentMeaning,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 14),
        _action(
          colors,
          icon: Icons.visibility_outlined,
          label: strings.starQuickLookViewAction,
          onTap: onView,
        ),
        const SizedBox(height: 8),
        _action(
          colors,
          icon: Icons.auto_awesome,
          label: strings.nascentStarQuickLookConfigureAction,
          onTap: onConfigure,
        ),
      ],
    );
  }

  Widget _action(
    AppColors colors, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.night,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusField),
          side: BorderSide(color: colors.nightBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colors.gold, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
