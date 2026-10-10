import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'app_choice_chip.dart';
import 'results_count_row.dart';
import 'staggered_entrance.dart';
import 'star_glyph.dart';

/// Opens the star-kind filter used by Sky's Stars view — a multi-select
/// chip grid, one chip per [kListableStarKinds] entry, each in its own
/// family's color so the filter reads the same way the sky does. Nothing
/// chosen means no filter (every kind shows); choosing some narrows it to
/// just those. Sibling to [showAreaFilterSheet] (split into its own
/// button/sheet rather than a second section bolted onto that one, so each
/// filter stands for exactly one thing) — same shape, same apply-or-keep
/// contract, just for kinds instead of areas: [selectedKinds] and the result
/// are the kinds the filter lets through, so "no filter" is the full set.
///
/// Returns null if dismissed without tapping Apply (caller should keep its
/// previous filter in that case).
Future<Set<StarKind>?> showKindFilterSheet(
  BuildContext context, {
  required Set<StarKind> selectedKinds,
  FilterPreview<Set<StarKind>>? preview,
}) {
  return showAppSheet<Set<StarKind>>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _KindFilterSheet(initialKinds: selectedKinds, preview: preview),
  );
}

class _KindFilterSheet extends StatefulWidget {
  const _KindFilterSheet({required this.initialKinds, this.preview});

  final Set<StarKind> initialKinds;
  final FilterPreview<Set<StarKind>>? preview;

  @override
  State<_KindFilterSheet> createState() => _KindFilterSheetState();
}

class _KindFilterSheetState extends State<_KindFilterSheet> {
  // What is chosen on the chips: empty while the filter lets every kind in.
  late Set<StarKind> _chosen = _chosenFrom(widget.initialKinds);
  late final Set<StarKind> _initialChosen = {..._chosen};

  static Set<StarKind> _chosenFrom(Set<StarKind> filter) =>
      filter.length == kListableStarKinds.length ? {} : {...filter};

  /// The kinds the filter lets through: all of them while nothing is chosen.
  Set<StarKind> get _kinds =>
      _chosen.isEmpty ? {...kListableStarKinds} : {..._chosen};
  bool get _hasChanges => !setEquals(_chosen, _initialChosen);

  void _toggleKind(StarKind kind) {
    setState(() {
      if (!_chosen.remove(kind)) _chosen.add(kind);
    });
  }

  void _clear() => setState(() => _chosen = {});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                child: AppSheetTitle(strings.filterKindSectionTitle),
              ),
            ),
            const SizedBox(height: 20),
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
                          iconColor:
                              _chosen.contains(
                                kListableStarKinds[row * 2 + col],
                              )
                              ? starKindColor(
                                  kListableStarKinds[row * 2 + col],
                                  colors,
                                )
                              : colors.muted,
                          label: kListableStarKinds[row * 2 + col].plural(
                            strings,
                          ),
                          selected: _chosen.contains(
                            kListableStarKinds[row * 2 + col],
                          ),
                          onPressed: () =>
                              _toggleKind(kListableStarKinds[row * 2 + col]),
                          expand: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (widget.preview != null) widget.preview!.rowFor(_kinds),
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 2 + (kListableStarKinds.length + 1) ~/ 2 + 1,
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
                        ? () => Navigator.of(context).pop(_kinds)
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
