import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../utils/app_modals.dart';
import 'app_choice_chip.dart';
import 'app_toggle_chip.dart';
import 'staggered_entrance.dart';
import 'star_glyph.dart';

/// Opens the star-kind filter used by Sky's Stars view — a multi-select
/// chip grid, one chip per [kListableStarKinds] entry, each in its own
/// family's color so the filter reads the same way the sky does. Tapping a
/// chip *adds* it to the filter; every kind starts checked, matching the
/// unfiltered result set. Sibling to [showAreaFilterSheet] (split
/// into its own button/sheet rather than a second section bolted onto that
/// one, so each filter stands for exactly one thing) — same shape, same
/// apply-or-keep contract, just for kinds instead of areas.
///
/// Returns the new selection, or null if dismissed without tapping Apply
/// (caller should keep its previous filter in that case). An empty result
/// is valid and means that no kind matches.
Future<Set<StarKind>?> showKindFilterSheet(
  BuildContext context, {
  required Set<StarKind> selectedKinds,
}) {
  return showAppSheet<Set<StarKind>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _KindFilterSheet(initialKinds: selectedKinds),
  );
}

class _KindFilterSheet extends StatefulWidget {
  const _KindFilterSheet({required this.initialKinds});

  final Set<StarKind> initialKinds;

  @override
  State<_KindFilterSheet> createState() => _KindFilterSheetState();
}

class _KindFilterSheetState extends State<_KindFilterSheet> {
  late Set<StarKind> _kinds = {...widget.initialKinds};
  late final Set<StarKind> _initialKinds = {...widget.initialKinds};

  bool get _allKindsSelected => _kinds.length == kListableStarKinds.length;
  bool get _hasChanges => !setEquals(_kinds, _initialKinds);

  void _toggleAllKinds() {
    setState(() => _kinds = _allKindsSelected ? {} : {...kListableStarKinds});
  }

  void _toggleKind(StarKind kind) {
    setState(() {
      if (!_kinds.remove(kind)) _kinds.add(kind);
    });
  }

  void _clear() => setState(() => _kinds = {...kListableStarKinds});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppSheetTitle(strings.filterKindSectionTitle),
              ),
            ),
            const SizedBox(height: 10),
            StaggeredEntrance(
              index: 1,
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
                      // Left-to-right within a row, and each row a step
                      // after the one above, so the grid fills in diagonally.
                      child: StaggeredEntrance(
                        index: 2 + row + col,
                        axis: Axis.horizontal,
                        child: AppChoiceChip(
                          icon: kListableStarKinds[row * 2 + col].icon,
                          iconColor: starKindColor(
                            kListableStarKinds[row * 2 + col],
                            colors,
                          ),
                          label: kListableStarKinds[row * 2 + col].plural(
                            strings,
                          ),
                          selected: _kinds.contains(
                            kListableStarKinds[row * 2 + col],
                          ),
                          onPressed: () =>
                              _toggleKind(kListableStarKinds[row * 2 + col]),
                          showCheck: true,
                          expand: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 2 + (kListableStarKinds.length + 1) ~/ 2 + 1,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _allKindsSelected ? null : _clear,
                    child: Text(strings.clearFilterAction),
                  ),
                  ElevatedButton(
                    onPressed: _hasChanges
                        ? () => Navigator.of(context).pop(_kinds)
                        : null,
                    child: Text(strings.applyFilterAction),
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
