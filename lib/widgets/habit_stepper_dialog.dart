import 'package:flutter/material.dart';

import '../data/habit_completion_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../utils/habit_stats.dart';

/// The popup behind a counting habit's single button ("3/10 today"): the
/// day's count in type with a minus and a plus at its sides, tappable as many
/// times as needed. Nothing is written until Save, which is only available
/// once the count actually differs from what it was on opening; Cancel
/// discards. [onChanged] runs after a save, so whatever opened it can refresh.
Future<void> showHabitStepperDialog({
  required BuildContext context,
  required Habit habit,
  required HabitCompletionRepository repository,
  VoidCallback? onChanged,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _HabitStepperDialog(
      habit: habit,
      repository: repository,
      onChanged: onChanged,
    ),
  );
}

class _HabitStepperDialog extends StatefulWidget {
  const _HabitStepperDialog({
    required this.habit,
    required this.repository,
    this.onChanged,
  });

  final Habit habit;
  final HabitCompletionRepository repository;
  final VoidCallback? onChanged;

  @override
  State<_HabitStepperDialog> createState() => _HabitStepperDialogState();
}

class _HabitStepperDialogState extends State<_HabitStepperDialog> {
  late final int _initial = habitDailyProgress(
    widget.habit,
    habitCompletionCountsByDay(
      widget.repository.getAllForHabit(widget.habit.id),
    ),
  );
  late int _count = _initial;
  bool _saving = false;

  bool get _changed => _count != _initial;

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = _initial; i < _count; i++) {
      await widget.repository.logInstance(widget.habit.id);
    }
    for (var i = _initial; i > _count; i--) {
      await widget.repository.unlogLastInstance(widget.habit.id, today);
    }
    widget.onChanged?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return AppDialog(
      title: Text(
        widget.habit.title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('habit-stepper-minus'),
                tooltip: strings.undoHabitTodayAction,
                onPressed: _count > 0 && !_saving
                    ? () => setState(() => _count--)
                    : null,
                iconSize: 30,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: _count > 0 ? colors.gold : colors.muted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_count/${widget.habit.targetPerPeriod}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: colors.gold,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('habit-stepper-plus'),
                tooltip: strings.actionLight,
                onPressed: _saving ? null : () => setState(() => _count++),
                iconSize: 30,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add_circle, color: colors.gold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.habitTodayLabel,
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: colors.muted),
          child: AppButtonLabel(strings.cancel),
        ),
        ElevatedButton(
          key: const Key('habit-stepper-save'),
          onPressed: _changed && !_saving ? _save : null,
          // Off, it keeps a visible button background (the theme's off
          // colour is the dialog's own, so it would vanish).
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: colors.nightBorder,
            disabledForegroundColor: colors.muted,
          ),
          child: AppButtonLabel(strings.saveChanges),
        ),
      ],
    );
  }
}
