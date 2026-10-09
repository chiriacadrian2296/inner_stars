import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'app_choice_chip.dart';
import 'app_toggle_chip.dart';
import 'results_count_row.dart';
import 'staggered_entrance.dart';

/// Opens the area filter used by Sky's Constellations/Stars views — a
/// multi-select chip grid, one chip per [LifeArea]. Tapping a chip *adds* it
/// to the filter; every area starts checked, matching the unfiltered result
/// set, restyled to the app's normal night/gold palette instead of
/// [AdmireStarsScreen]'s Nightlight gradient (same interaction as that
/// screen's own area picker). Split out from what used to also carry a
/// star-kind section — that's [showKindFilterSheet] now, its own separate
/// button — so each filter button/sheet stands for exactly one thing.
///
/// Returns the new selection, or null if dismissed without tapping Apply
/// (caller should keep its previous filter in that case). An empty result
/// is a valid answer and means that no area matches.
Future<Set<LifeArea>?> showAreaFilterSheet(
  BuildContext context, {
  required Set<LifeArea> selectedAreas,
  FilterPreview<Set<LifeArea>>? preview,
}) {
  return showAppSheet<Set<LifeArea>>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _AreaFilterSheet(initialAreas: selectedAreas, preview: preview),
  );
}

class _AreaFilterSheet extends StatefulWidget {
  const _AreaFilterSheet({required this.initialAreas, this.preview});

  final Set<LifeArea> initialAreas;
  final FilterPreview<Set<LifeArea>>? preview;

  @override
  State<_AreaFilterSheet> createState() => _AreaFilterSheetState();
}

class _AreaFilterSheetState extends State<_AreaFilterSheet> {
  late Set<LifeArea> _areas = {...widget.initialAreas};
  late final Set<LifeArea> _initialAreas = {...widget.initialAreas};

  bool get _allAreasSelected => _areas.length == LifeArea.values.length;
  bool get _hasChanges => !setEquals(_areas, _initialAreas);

  void _toggleAllAreas() {
    setState(() => _areas = _allAreasSelected ? {} : {...LifeArea.values});
  }

  void _toggleArea(LifeArea area) {
    setState(() {
      if (!_areas.remove(area)) _areas.add(area);
    });
  }

  void _clear() => setState(() => _areas = {...LifeArea.values});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppSheetTitle(strings.skyModeSupernovas),
              ),
            ),
            const SizedBox(height: 20),
            StaggeredEntrance(
              index: 1,
              child: AppToggleChip(
                label: strings.allAreasLabel,
                value: _allAreasSelected,
                onChanged: (_) => _toggleAllAreas(),
              ),
            ),
            const SizedBox(height: 16),
            for (var row = 0; row * 2 < LifeArea.values.length; row++) ...[
              if (row > 0) const SizedBox(height: 10),
              Row(
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 10),
                    Expanded(
                      // Left-to-right within a row, and each row a step
                      // after the one above, so the grid fills in diagonally.
                      child: StaggeredEntrance(
                        index: 2 + row + col,
                        axis: Axis.horizontal,
                        child: AppChoiceChip(
                          icon: LifeArea.values[row * 2 + col].icon,
                          label: LifeArea.values[row * 2 + col].displayName(
                            strings,
                          ),
                          selected: _areas.contains(
                            LifeArea.values[row * 2 + col],
                          ),
                          onPressed: () =>
                              _toggleArea(LifeArea.values[row * 2 + col]),
                          showCheck: true,
                          expand: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (widget.preview != null) widget.preview!.rowFor(_areas),
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 2 + (LifeArea.values.length + 1) ~/ 2 + 1,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _allAreasSelected ? null : _clear,
                    child: AppButtonLabel(strings.clearFilterAction),
                  ),
                  ElevatedButton(
                    onPressed: _hasChanges
                        ? () => Navigator.of(context).pop(_areas)
                        : null,
                    child: AppButtonLabel(strings.applyFilterAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
