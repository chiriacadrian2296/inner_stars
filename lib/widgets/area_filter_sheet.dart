import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/app_modals.dart';
import 'app_toggle_chip.dart';
import 'staggered_entrance.dart';

/// Opens the area filter used by Sky's Constellations/Stars views — a
/// multi-select chip grid, one chip per [LifeArea]. Tapping a chip *adds* it
/// to the filter; none checked (the default) means no restriction, i.e.
/// every area, restyled to the app's normal night/gold palette instead of
/// [AdmireStarsScreen]'s Nightlight gradient (same interaction as that
/// screen's own area picker). Split out from what used to also carry a
/// star-kind section — that's [showKindFilterSheet] now, its own separate
/// button — so each filter button/sheet stands for exactly one thing.
///
/// Returns the new selection, or null if dismissed without tapping Apply
/// (caller should keep its previous filter in that case). An empty result
/// is a valid, meaningful answer — it's [SkyExplorerView]'s own default
/// (see `_areaFilter`'s doc there) — this sheet has no opinion of its own on
/// what "nothing checked" means, it just reports back whatever's checked.
Future<Set<LifeArea>?> showAreaFilterSheet(
  BuildContext context, {
  required Set<LifeArea> selectedAreas,
}) {
  return showAppSheet<Set<LifeArea>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AreaFilterSheet(initialAreas: selectedAreas),
  );
}

class _AreaFilterSheet extends StatefulWidget {
  const _AreaFilterSheet({required this.initialAreas});

  final Set<LifeArea> initialAreas;

  @override
  State<_AreaFilterSheet> createState() => _AreaFilterSheetState();
}

class _AreaFilterSheetState extends State<_AreaFilterSheet> {
  late Set<LifeArea> _areas = {...widget.initialAreas};

  bool get _allAreasSelected => _areas.length == LifeArea.values.length;

  void _toggleAllAreas() {
    setState(() => _areas = _allAreasSelected ? {} : {...LifeArea.values});
  }

  void _toggleArea(LifeArea area) {
    setState(() {
      if (!_areas.remove(area)) _areas.add(area);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Row(
                children: [
                  Expanded(child: _SectionTitle(strings.skyModeSupernovas)),
                  if (_areas.isNotEmpty)
                    StaggeredEntrance(
                      index: 0,
                      axis: Axis.horizontal,
                      child: TextButton(
                        onPressed: () => setState(() => _areas = {}),
                        child: Text(strings.clearFilterAction),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            HintTarget(
              tour: 'search-stars',
              order: 5,
              showArrow: true,
              contentBuilder: appTourStepCard,
              title: strings.searchTourAllAreasTitle,
              description: strings.searchTourAllAreasBody,
              child: StaggeredEntrance(
                index: 1,
                child: AppToggleChip(
                  label: strings.allAreasLabel,
                  value: _allAreasSelected,
                  onChanged: (_) => _toggleAllAreas(),
                ),
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
                        child: _FilterChip(
                          icon: LifeArea.values[row * 2 + col].icon,
                          label: LifeArea.values[row * 2 + col].displayName(
                            strings,
                          ),
                          selected: _areas.contains(
                            LifeArea.values[row * 2 + col],
                          ),
                          onTap: () =>
                              _toggleArea(LifeArea.values[row * 2 + col]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            HintTarget(
              tour: 'search-stars',
              order: 7,
              showArrow: true,
              contentBuilder: appTourStepCard,
              title: strings.searchTourApplyTitle,
              description: strings.searchTourApplyBody,
              child: StaggeredEntrance(
                index: 2 + (LifeArea.values.length + 1) ~/ 2 + 1,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_areas),
                    child: Text(strings.applyFilterAction),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One toggleable chip in the area grid — icon, label, and a trailing check
/// that fills in once selected.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: selectableDecoration(colors, selected: selected),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? colors.gold : colors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? colors.text : colors.muted,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? colors.gold : colors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple, low-key header above the chip grid.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.muted,
        ),
      ),
    );
  }
}
