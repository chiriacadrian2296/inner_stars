import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/galaxy_navigation_mode.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';

/// Chooses how strongly Galaxy follows a manual drag.
class GalaxyNavigationModePicker extends StatelessWidget {
  const GalaxyNavigationModePicker({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<GalaxyNavigationMode>(
            segments: [
              ButtonSegment(
                value: GalaxyNavigationMode.direct,
                label: Text(strings.galaxyNavigationDirectLabel),
              ),
              ButtonSegment(
                value: GalaxyNavigationMode.cinematic,
                label: Text(strings.galaxyNavigationCinematicLabel),
              ),
            ],
            selected: {settings.galaxyNavigationMode},
            onSelectionChanged: (selection) =>
                settings.setGalaxyNavigationMode(selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            settings.galaxyNavigationMode == GalaxyNavigationMode.cinematic
                ? strings.galaxyNavigationCinematicDescription
                : strings.galaxyNavigationDirectDescription,
            style: TextStyle(color: colors.muted, fontSize: 12.5),
          ),
          if (settings.galaxyNavigationMode ==
              GalaxyNavigationMode.cinematic) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.galaxyNavigationGravityLabel,
                    style: TextStyle(color: colors.text, fontSize: 13),
                  ),
                ),
                Text(
                  '${(settings.galaxyCinematicGravity * 100).round()}%',
                  style: TextStyle(
                    color: colors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.galaxyCinematicGravity,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(settings.galaxyCinematicGravity * 100).round()}%',
              onChanged: settings.setGalaxyCinematicGravity,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0 G',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                Text(
                  '1 G',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.galaxyNavigationGravityDescription,
              style: TextStyle(color: colors.muted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
