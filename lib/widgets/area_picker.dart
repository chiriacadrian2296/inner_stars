import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../utils/app_modals.dart';
import 'staggered_entrance.dart';

/// The canonical single-area picker shared by star and constellation forms.
Future<LifeArea?> pickArea(BuildContext context) {
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
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(strings.cancel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
