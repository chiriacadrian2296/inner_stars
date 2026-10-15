import 'package:flutter/material.dart';

import '../debug/frame_rate_limiter.dart';
import '../l10n/strings_scope.dart';
import '../models/galaxy_quality.dart';
import '../settings/settings_controller.dart';
import '../theme/app_colors.dart';

/// The Quality / Balanced / Performance choice for the Galaxy's sky, with
/// a line on what the lighter modes give up.
class GalaxyQualityPicker extends StatelessWidget {
  const GalaxyQualityPicker({super.key, required this.settings});

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
          SegmentedButton<GalaxyQuality>(
            segments: [
              ButtonSegment(
                value: GalaxyQuality.quality,
                label: Text(strings.galaxyQualityLabel),
              ),
              ButtonSegment(
                value: GalaxyQuality.balanced,
                label: Text(strings.galaxyQualityBalancedLabel),
              ),
              ButtonSegment(
                value: GalaxyQuality.performance,
                label: Text(strings.galaxyQualityPerformanceLabel),
              ),
            ],
            selected: {settings.galaxyQuality},
            onSelectionChanged: (selection) =>
                settings.setGalaxyQuality(selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            strings.galaxyQualityDescription,
            style: TextStyle(color: colors.muted, fontSize: 12.5),
          ),
          // TEMPORARY — 40/30 fps smoothness test, see frame_rate_limiter.
          const SizedBox(height: 16),
          Text(
            'FPS Limit (Test)',
            style: TextStyle(color: colors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: frameRateLimit,
            builder: (context, limit, _) => SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Free')),
                ButtonSegment(value: 40, label: Text('40')),
                ButtonSegment(value: 30, label: Text('30')),
              ],
              selected: {limit},
              onSelectionChanged: (selection) =>
                  frameRateLimit.value = selection.first,
            ),
          ),
        ],
      ),
    );
  }
}
