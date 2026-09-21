import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'app_toggle_chip.dart';
import 'star_glyph.dart';

/// Opens the star-kind filter used by Sky's Stars view — a multi-select
/// chip grid, one chip per [kListableStarKinds] entry, each in its own
/// family's color so the filter reads the same way the sky does. Tapping a
/// chip *adds* it to the filter; none checked (the default) means no
/// restriction, i.e. every kind. Sibling to [showAreaFilterSheet] (split
/// into its own button/sheet rather than a second section bolted onto that
/// one, so each filter stands for exactly one thing) — same shape, same
/// apply-or-keep contract, just for kinds instead of areas.
///
/// Returns the new selection, or null if dismissed without tapping Apply
/// (caller should keep its previous filter in that case). An empty result
/// is valid and meaningful — see [showAreaFilterSheet]'s own doc for why.
Future<Set<StarKind>?> showKindFilterSheet(
  BuildContext context, {
  required Set<StarKind> selectedKinds,
}) {
  return showModalBottomSheet<Set<StarKind>>(
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

  bool get _allKindsSelected => _kinds.length == kListableStarKinds.length;

  void _toggleAllKinds() {
    setState(() => _kinds = _allKindsSelected ? {} : {...kListableStarKinds});
  }

  void _toggleKind(StarKind kind) {
    setState(() {
      if (!_kinds.remove(kind)) _kinds.add(kind);
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
          children: [
            Row(
              children: [
                Expanded(child: _SectionTitle(strings.filterKindSectionTitle)),
                if (_kinds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _kinds = {}),
                    child: Text(strings.clearFilterAction),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            AppToggleChip(
              label: strings.allKindsLabel,
              value: _allKindsSelected,
              onChanged: (_) => _toggleAllKinds(),
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
                        selected: _kinds.contains(
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_kinds),
                child: Text(strings.applyFilterAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One toggleable chip in the kind grid — icon (tinted with that kind's own
/// family color), label, and a trailing check that fills in once selected.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
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
            Icon(icon, size: 16, color: iconColor),
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
