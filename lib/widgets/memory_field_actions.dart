import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

/// The two buttons under every photo/memories content zone, centered: a
/// Reset (clears just that field) and Add, both secondary. One widget
/// so the main photo and every Memories field carry the exact same pair.
class MemoryFieldActions extends StatelessWidget {
  const MemoryFieldActions({
    super.key,
    required this.addIcon,
    required this.onAdd,
    required this.onReset,
    this.canAdd = true,
    this.canReset = true,
  });

  final IconData addIcon;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  /// Off once the field is full.
  final bool canAdd;

  /// Off while the field holds nothing.
  final bool canReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: canReset ? onReset : null,
            style: TextButton.styleFrom(
              foregroundColor: colors.gold,
              disabledForegroundColor: colors.muted,
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: AppButtonLabel(strings.resetExtraAction),
          ),
          TextButton.icon(
            onPressed: canAdd ? onAdd : null,
            style: TextButton.styleFrom(
              foregroundColor: colors.gold,
              disabledForegroundColor: colors.muted,
            ),
            icon: Icon(addIcon, size: 18),
            label: AppButtonLabel(strings.addExtraAction),
          ),
        ],
      ),
    );
  }
}
