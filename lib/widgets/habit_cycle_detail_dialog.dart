import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit_cycle.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../utils/app_modals.dart';
import '../utils/date_format.dart';
import 'intensity_bolts.dart';

/// A finished cycle in full: its length and date, the reward it earned and
/// the answers given in its reflection, so they can be read again later.
Future<void> showHabitCycleDetail(BuildContext context, HabitCycle cycle) {
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      final strings = dialogContext.strings;
      final type = dialogContext.typography;

      Widget answer(String question, String? text) {
        if (text == null || text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question, style: type.compactSectionLabel),
              const SizedBox(height: 4),
              Text(text, style: TextStyle(color: colors.text, height: 1.4)),
            ],
          ),
        );
      }

      return AppDialog(
        scrollable: true,
        title: Text(
          '${strings.cycleHistoryItem(cycle.length)} · '
          '${formatDisplayDate(cycle.completedDate, strings)}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntensityBolts(intensity: cycle.intensity, size: 20, spacing: 4),
            answer(strings.cycleQuestionHelped, cycle.whatHelped),
            answer(strings.cycleQuestionHard, cycle.whatWasHard),
            answer(strings.cycleQuestionFeel, cycle.howItFeels),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: AppButtonLabel(strings.closeAction),
          ),
        ],
      );
    },
  );
}
