import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'app_choice_chip.dart';
import 'results_count_row.dart';
import 'staggered_entrance.dart';

/// Opens the area filter used by Sky's Constellations/Stars views — a
/// multi-select chip grid, one chip per [LifeArea]. Nothing chosen means no
/// filter (every area shows); choosing some narrows it to just those. Chips
/// open unselected while every area is in the filter, and choosing every area
/// is the same as choosing none. Split out from what used to also carry a
/// star-kind section — that's [showKindFilterSheet] now, its own separate
/// button — so each filter button/sheet stands for exactly one thing.
///
/// [selectedAreas] and the result are the areas the filter lets through, so
/// "no filter" is the full set. Returns null if dismissed without tapping
/// Apply (caller should keep its previous filter in that case).
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
  // What is chosen on the chips: empty while the filter lets every area in.
  late Set<LifeArea> _chosen = _chosenFrom(widget.initialAreas);
  late final Set<LifeArea> _initialChosen = {..._chosen};

  static Set<LifeArea> _chosenFrom(Set<LifeArea> filter) =>
      filter.length == LifeArea.values.length ? {} : {...filter};

  /// The areas the filter lets through: all of them while nothing is chosen.
  Set<LifeArea> get _areas =>
      _chosen.isEmpty ? {...LifeArea.values} : {..._chosen};
  bool get _hasChanges => !setEquals(_chosen, _initialChosen);

  void _toggleArea(LifeArea area) {
    setState(() {
      if (!_chosen.remove(area)) _chosen.add(area);
    });
  }

  void _clear() => setState(() => _chosen = {});

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
                          selected: _chosen.contains(
                            LifeArea.values[row * 2 + col],
                          ),
                          onPressed: () =>
                              _toggleArea(LifeArea.values[row * 2 + col]),
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
                    onPressed: _chosen.isEmpty ? null : _clear,
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
