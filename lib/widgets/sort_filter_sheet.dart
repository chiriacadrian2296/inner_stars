import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'staggered_entrance.dart';

/// What Sky's Constellations/Stars lists can be ordered by — the same three
/// options in both, each mapped onto whatever that mode's own data means by
/// "date"/"intensity"/"name" (see `_SkyExplorerViewState._projectSortDate`/
/// `._projectIntensity` for Constellations, `_SkyEntry.sortKey`/
/// `.intensityValue` for Stars).
enum SortField { date, intensity, name }

enum SortDirection { ascending, descending }

/// Opens the sort-order sheet shared by Sky's Constellations/Stars views —
/// a field (date/intensity/name) plus a direction, applied together. Unlike
/// the area/kind/date filters, there's no "off" state to clear back to:
/// results are always in *some* order, so this sheet always has a concrete
/// field+direction selected rather than an empty default.
///
/// Returns the new `(field, direction)`, or null if dismissed without
/// tapping Apply (caller should keep its previous sort in that case) — same
/// apply-or-keep contract as the other filter sheets.
Future<({SortField field, SortDirection direction})?> showSortFilterSheet(
  BuildContext context, {
  required SortField initialField,
  required SortDirection initialDirection,
}) {
  return showAppSheet<({SortField field, SortDirection direction})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SortFilterSheet(
      initialField: initialField,
      initialDirection: initialDirection,
    ),
  );
}

class _SortFilterSheet extends StatefulWidget {
  const _SortFilterSheet({
    required this.initialField,
    required this.initialDirection,
  });

  final SortField initialField;
  final SortDirection initialDirection;

  @override
  State<_SortFilterSheet> createState() => _SortFilterSheetState();
}

class _SortFilterSheetState extends State<_SortFilterSheet> {
  late SortField _field = widget.initialField;
  late SortDirection _direction = widget.initialDirection;

  void _toggleDirection() {
    setState(() {
      _direction = _direction == SortDirection.ascending
          ? SortDirection.descending
          : SortDirection.ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Text(
                strings.sortSheetTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // The field on one side, a single icon button flipping the
            // direction on the other — same "picker beside a stepper" shape
            // as the date-range sheet's duration chips + step arrows.
            Row(
              children: [
                Expanded(
                  child: StaggeredEntrance(
                    index: 0,
                    axis: Axis.horizontal,
                    child: _SortFieldChip(
                      label: strings.sortFieldDate,
                      selected: _field == SortField.date,
                      onTap: () => setState(() => _field = SortField.date),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StaggeredEntrance(
                    index: 1,
                    axis: Axis.horizontal,
                    child: _SortFieldChip(
                      label: strings.sortFieldIntensity,
                      selected: _field == SortField.intensity,
                      onTap: () => setState(() => _field = SortField.intensity),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StaggeredEntrance(
                    index: 2,
                    axis: Axis.horizontal,
                    child: _SortFieldChip(
                      label: strings.sortFieldName,
                      selected: _field == SortField.name,
                      onTap: () => setState(() => _field = SortField.name),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StaggeredEntrance(
                  index: 3,
                  axis: Axis.horizontal,
                  child: _DirectionButton(
                    ascending: _direction == SortDirection.ascending,
                    onTap: _toggleDirection,
                    tooltip: _direction == SortDirection.ascending
                        ? strings.sortDirectionAscending
                        : strings.sortDirectionDescending,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StaggeredEntrance(
              index: 4,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pop((field: _field, direction: _direction)),
                  child: Text(strings.applyFilterAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single-line sort-field chip — same treatment as `_PresetChip` in
/// `date_range_filter_sheet.dart`.
class _SortFieldChip extends StatelessWidget {
  const _SortFieldChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: selectableDecoration(colors, selected: selected),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.text : colors.muted,
          ),
        ),
      ),
    );
  }
}

/// Flips [SortDirection] on tap — an up or down arrow standing in for
/// ascending/descending rather than spelling either word out, since this
/// sheet is already tight on width with three field chips beside it.
class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.ascending,
    required this.onTap,
    required this.tooltip,
  });

  final bool ascending;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            width: 44,
            height: 46,
            alignment: Alignment.center,
            decoration: selectableDecoration(colors, selected: true),
            child: Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
              color: colors.gold,
            ),
          ),
        ),
      ),
    );
  }
}
