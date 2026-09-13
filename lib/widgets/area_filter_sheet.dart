import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'app_toggle_chip.dart';
import 'star_glyph.dart';

/// Opens the filter modal used by Sky's Constellations/Stars views. Always
/// has an area section (the "All areas" toggle + area-chip grid, same
/// interaction as [AdmireStarsScreen]'s picker, restyled to the app's normal
/// night/gold palette instead of that screen's crisis gradient). When
/// [selectedKinds] is non-null (Stars mode), a second section of star-kind
/// chips is shown below it; passing null (Constellations mode, where a kind
/// filter doesn't apply) omits that section entirely.
///
/// Returns the new selections, or null if dismissed without tapping Apply
/// (caller should keep its previous filters in that case). `kinds` in the
/// result mirrors whatever was passed in — null when no kind section was
/// shown.
Future<({Set<LifeArea> areas, Set<StarKind>? kinds})?> showAreaFilterSheet(
  BuildContext context, {
  required Set<LifeArea> selectedAreas,
  Set<StarKind>? selectedKinds,
}) {
  return showModalBottomSheet<({Set<LifeArea> areas, Set<StarKind>? kinds})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AreaFilterSheet(
      initialAreas: selectedAreas,
      initialKinds: selectedKinds,
    ),
  );
}

class _AreaFilterSheet extends StatefulWidget {
  const _AreaFilterSheet({required this.initialAreas, this.initialKinds});

  final Set<LifeArea> initialAreas;
  final Set<StarKind>? initialKinds;

  @override
  State<_AreaFilterSheet> createState() => _AreaFilterSheetState();
}

class _AreaFilterSheetState extends State<_AreaFilterSheet> {
  late Set<LifeArea> _areas = {...widget.initialAreas};
  late final Set<StarKind>? _kinds = widget.initialKinds == null
      ? null
      : {...widget.initialKinds!};

  bool get _allAreasSelected => _areas.length == LifeArea.values.length;

  void _toggleAllAreas() {
    setState(() => _areas = _allAreasSelected ? {} : {...LifeArea.values});
  }

  void _toggleArea(LifeArea area) {
    setState(() {
      if (!_areas.remove(area)) _areas.add(area);
    });
  }

  void _toggleKind(StarKind kind) {
    final kinds = _kinds;
    if (kinds == null) return;
    setState(() {
      if (!kinds.remove(kind)) kinds.add(kind);
    });
  }

  bool get _allKindsSelected =>
      (_kinds?.length ?? 0) == kListableStarKinds.length;

  void _toggleAllKinds() {
    final kinds = _kinds;
    if (kinds == null) return;
    final selectAll = !_allKindsSelected;
    setState(() {
      kinds.clear();
      if (selectAll) kinds.addAll(kListableStarKinds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final kinds = _kinds;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionTitle(strings.skyModeSupernovas),
            const SizedBox(height: 10),
            HintTarget(
              tour: 'search-stars',
              order: 4,
              pulse: true,
              showArrow: true,
              title: strings.searchTourAllAreasTitle,
              description: strings.searchTourAllAreasBody,
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
                  ],
                ],
              ),
            ],
            if (kinds != null) ...[
              const SizedBox(height: 16),
              Divider(color: colors.nightBorder, height: 1),
              const SizedBox(height: 16),
              _SectionTitle(strings.filterKindSectionTitle),
              const SizedBox(height: 10),
              HintTarget(
                tour: 'search-stars',
                order: 5,
                pulse: true,
                showArrow: true,
                title: strings.searchTourAllKindsTitle,
                description: strings.searchTourAllKindsBody,
                child: AppToggleChip(
                  label: strings.allKindsLabel,
                  value: _allKindsSelected,
                  onChanged: (_) => _toggleAllKinds(),
                ),
              ),
              const SizedBox(height: 16),
              // Two per row, in [kListableStarKinds] order — one chip per
              // kind, each in its own family's color, so the filter reads
              // the same way the sky does.
              for (var row = 0; row * 2 < kListableStarKinds.length; row++) ...[
                if (row > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _FilterChip(
                          icon: kListableStarKinds[row * 2 + col].icon,
                          iconColor: starKindColor(
                            kListableStarKinds[row * 2 + col],
                            colors,
                          ),
                          label: kListableStarKinds[row * 2 + col].plural(
                            strings,
                          ),
                          selected: kinds.contains(
                            kListableStarKinds[row * 2 + col],
                          ),
                          onTap: () =>
                              _toggleKind(kListableStarKinds[row * 2 + col]),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            HintTarget(
              tour: 'search-stars',
              order: 6,
              pulse: true,
              showArrow: true,
              title: strings.searchTourApplyTitle,
              description: strings.searchTourApplyBody,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((areas: _areas, kinds: _kinds)),
                  child: Text(strings.applyAreaFilterAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One toggleable chip shared by both filter sections — icon, label, and a
/// trailing check that fills in once selected. Areas and star kinds both use
/// this, so the two sections read as one consistent control.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Overrides the chip's own gold/muted icon tint — passed by the star
  /// kind chips so each one carries its family's color even while
  /// deselected, since that color *is* the thing being filtered on.
  final Color? iconColor;

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
            Icon(
              icon,
              size: 16,
              color: iconColor ?? (selected ? colors.gold : colors.muted),
            ),
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

/// A simple, low-key header above each filter section — just enough to tell
/// the two groups (areas, star kinds) apart at a glance.
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

