import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../settings/settings_controller.dart';
import '../settings/sky_grid_size.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// How dark the Sky goes behind its controls sheet — light on purpose, so the
/// list/grid above the sheet stays easy to judge while it changes.
const Color kSkyViewSheetBarrier = Color(0x33000000);

/// The "View" section of the Sky's controls sheet, on one row: a two-way
/// list/grid switch (same look as the level switch above the search field)
/// and, beside it, the card size slider — live only in grid. Writes straight
/// to [settings], which the Sky listens to, so the view behind updates as it
/// changes.
class SkyViewModeSection extends StatelessWidget {
  const SkyViewModeSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final sizeNames = [
      strings.skyViewSizeCompact,
      strings.skyViewSizeMedium,
      strings.skyViewSizeLarge,
      strings.skyViewSizeExtraLarge,
    ];
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final grid = settings.skyGridView;
        final step = settings.skyGridSizeStep;
        return Row(
          children: [
            SizedBox(
              width: 104,
              child: AnimatedToggleSwitch<bool>.rolling(
                height: 40,
                current: grid,
                values: const [false, true],
                onChanged: settings.setSkyGridView,
                borderWidth: kBorderWidth,
                iconOpacity: 1.0,
                iconBuilder: (value, size) => Tooltip(
                  message: value ? strings.skyViewGrid : strings.skyViewList,
                  child: Icon(
                    value
                        ? Icons.grid_view_rounded
                        : Icons.view_agenda_outlined,
                    size: 20,
                    color: value == grid ? colors.night : colors.muted,
                  ),
                ),
                style: ToggleStyle(
                  backgroundColor: colors.nightPanel,
                  indicatorColor: colors.gold,
                  borderColor: colors.nightBorder,
                  borderRadius: BorderRadius.circular(kRadiusField),
                  indicatorBorderRadius: BorderRadius.circular(kRadiusField),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: grid ? 1 : 0.45,
                child: Slider(
                  value: step.toDouble(),
                  min: 0,
                  max: (kSkyGridTileExtents.length - 1).toDouble(),
                  divisions: kSkyGridTileExtents.length - 1,
                  label: sizeNames[step],
                  onChanged: grid
                      ? (v) => settings.setSkyGridSizeStep(v.round())
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
