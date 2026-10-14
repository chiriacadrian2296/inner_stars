import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'app_field.dart';

/// A pulsar's cycle length: 7 / 30 / 90 distinct days as quick picks, or a
/// custom number set with a stepper. Reaching it earns the reward (the
/// intensity) once; there is no deadline.
///
/// Stateless on purpose — the owner keeps [length] and [custom], so the same
/// field serves the pulsar form and the end-of-cycle reflection page.
class CycleLengthField extends StatelessWidget {
  const CycleLengthField({
    super.key,
    required this.length,
    required this.custom,
    required this.onPreset,
    required this.onCustom,
    required this.onLengthChanged,
    this.canReset = false,
    this.onReset,
    this.showLabel = true,
  });

  final int length;
  final bool custom;
  final bool canReset;
  final VoidCallback? onReset;
  final bool showLabel;
  final ValueChanged<int> onPreset;
  final VoidCallback onCustom;
  final ValueChanged<int> onLengthChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    Widget step(String label, int delta) {
      final next = length + delta;
      final enabled = next >= kMinCycleLength && next <= kMaxCycleLength;
      return TextButton(
        onPressed: enabled ? () => onLengthChanged(next) : null,
        child: Text(label),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          AppFieldLabel(
            strings.habitCycleLabel,
            canReset: canReset,
            onReset: onReset,
            requirement: FieldRequirement.required,
          ),
          const SizedBox(height: kFieldLabelGap),
        ],
        Row(
          children: [
            for (final preset in kCyclePresets) ...[
              Expanded(
                child: _CycleChip(
                  label: '$preset',
                  selected: !custom && length == preset,
                  onTap: () => onPreset(preset),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _CycleChip(
                label: strings.habitCycleCustom,
                selected: custom,
                onTap: onCustom,
              ),
            ),
          ],
        ),
        if (custom) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              step('-10', -10),
              step('-1', -1),
              SizedBox(
                width: 56,
                child: Text(
                  '$length',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              step('+1', 1),
              step('+10', 10),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: Text(
            strings.habitCycleSummary(length),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Same selectable look ([selectableDecoration]) as the star form's other
/// "pick one of a few" controls.
class _CycleChip extends StatelessWidget {
  const _CycleChip({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: selectableDecoration(colors, selected: selected),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.text : colors.muted,
          ),
        ),
      ),
    );
  }
}
