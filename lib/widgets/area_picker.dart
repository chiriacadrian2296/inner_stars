import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import 'staggered_entrance.dart';

/// The canonical single-area picker shared by star and constellation forms.
/// [selected] is outlined in gold as the current choice. With [onCleared]
/// given, Reset is the only button (primary; grey while nothing is selected)
/// closes the sheet and calls it.
Future<LifeArea?> pickArea(
  BuildContext context, {
  LifeArea? selected,
  VoidCallback? onCleared,
}) {
  final strings = context.strings;

  return showAppSheet<LifeArea>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSheetTitle(strings.areaLabel),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: LifeArea.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => StaggeredEntrance(
                    index: index + 1,
                    child: AppSheetAction(
                      uppercase: false,
                      selected: LifeArea.values[index] == selected,
                      icon: LifeArea.values[index].icon,
                      label: LifeArea.values[index].displayName(strings),
                      onPressed: () =>
                          Navigator.of(sheetContext)
                              .pop(LifeArea.values[index]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (onCleared == null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: sheetContext.colors.muted,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: AppButtonLabel(strings.cancel),
                      )
                    else
                      ElevatedButton(
                        onPressed: selected == null
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop();
                                onCleared();
                              },
                        child: AppButtonLabel(strings.clearFilterAction),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
