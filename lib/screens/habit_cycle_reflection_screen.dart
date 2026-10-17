import 'package:flutter/material.dart';

import '../data/habit_cycle_repository.dart';
import '../data/habit_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/habit_cycle.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../widgets/app_field.dart';
import '../widgets/cycle_length_field.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/victory_fields.dart';

/// How the user wants to go on after finishing a cycle.
enum HabitCycleChoice { restart, change, close }

/// The moment a pulsar's cycle is completed: a congratulation, a few optional
/// guided questions, and the choice of what comes next — start again as it
/// was, change the length and reward, or wrap the habit up.
///
/// The reward is already earned by the time this opens (see
/// [HabitCycleRepository.sync]); leaving with "Later" just keeps the cycle
/// unresolved so the page can be reopened from the pulsar. Pops `true` once
/// the user has chosen how to continue, `false`/null otherwise.
class HabitCycleReflectionScreen extends StatefulWidget {
  const HabitCycleReflectionScreen({
    super.key,
    required this.habit,
    required this.cycle,
    required this.habitRepository,
    required this.cycleRepository,
  });

  final Habit habit;
  final HabitCycle cycle;
  final HabitRepository habitRepository;
  final HabitCycleRepository cycleRepository;

  @override
  State<HabitCycleReflectionScreen> createState() =>
      _HabitCycleReflectionScreenState();
}

class _HabitCycleReflectionScreenState
    extends State<HabitCycleReflectionScreen> {
  final _helped = TextEditingController();
  final _hard = TextEditingController();
  final _feel = TextEditingController();

  HabitCycleChoice _choice = HabitCycleChoice.restart;
  late int _length = widget.habit.cycleLength;
  late bool _lengthCustom = !kCyclePresets.contains(_length);
  late int _reward = widget.habit.intensity;
  bool _rewardTouched = false;
  bool _saving = false;

  /// Changing course needs the reward chosen again (see the reward field).
  bool get _canConfirm =>
      !_saving && (_choice != HabitCycleChoice.change || _rewardTouched);

  @override
  void initState() {
    super.initState();
    _helped.text = widget.cycle.whatHelped ?? '';
    _hard.text = widget.cycle.whatWasHard ?? '';
    _feel.text = widget.cycle.howItFeels ?? '';
  }

  @override
  void dispose() {
    _helped.dispose();
    _hard.dispose();
    _feel.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final cycle = widget.cycle;
    await widget.cycleRepository.resolve(
      cycle.id,
      whatHelped: _helped.text,
      whatWasHard: _hard.text,
      howItFeels: _feel.text,
    );
    switch (_choice) {
      case HabitCycleChoice.close:
        await widget.habitRepository.delete(widget.habit.id);
      case HabitCycleChoice.restart:
      case HabitCycleChoice.change:
        final changing = _choice == HabitCycleChoice.change;
        final done = cycle.completedDate;
        await widget.habitRepository.startNextCycle(
          widget.habit.id,
          // Days done between reaching the goal and deciding carry over into
          // the next cycle: nothing the user did is thrown away.
          start: DateTime(done.year, done.month, done.day + 1),
          cycleLength: changing ? _length : widget.habit.cycleLength,
          intensity: changing ? _reward : widget.habit.intensity,
        );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final type = context.typography;
    final closing = _choice == HabitCycleChoice.close;

    Widget option(HabitCycleChoice value, String title, String body) {
      final selected = _choice == value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => setState(() => _choice = value),
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: selectableDecoration(colors, selected: selected),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? colors.text : colors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: type.supporting),
              ],
            ),
          ),
        ),
      );
    }

    Widget question(String label, TextEditingController controller) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFieldLabel(label, requirement: FieldRequirement.optional),
            const SizedBox(height: kFieldLabelGap),
            AppTextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              showCounter: false,
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: colors.night,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredEntrance(
                      index: 0,
                      child: Text(
                        strings.cycleDoneTitle,
                        style: type.immersivePageTitle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredEntrance(
                      index: 1,
                      child: Text(
                        widget.habit.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredEntrance(
                      index: 1,
                      child: Text(
                        strings.cycleDoneBody(widget.cycle.length),
                        style: type.supporting,
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggeredEntrance(
                      index: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.cycleRewardEarned,
                            style: type.sectionHeading,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: IntensityBolts(
                              intensity: widget.cycle.intensity,
                              size: 26,
                              spacing: 6,
                              emphasizeLast: true,
                              emphasizedScale: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    StaggeredEntrance(
                      index: 3,
                      child: Text(
                        strings.cycleReflectionIntro,
                        style: type.supporting,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggeredEntrance(
                      index: 3,
                      child: question(strings.cycleQuestionHelped, _helped),
                    ),
                    StaggeredEntrance(
                      index: 4,
                      child: question(strings.cycleQuestionHard, _hard),
                    ),
                    StaggeredEntrance(
                      index: 4,
                      child: question(strings.cycleQuestionFeel, _feel),
                    ),
                    const SizedBox(height: 16),
                    StaggeredEntrance(
                      index: 5,
                      child: Text(
                        strings.cycleNextTitle,
                        style: type.sectionHeading,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaggeredEntrance(
                      index: 5,
                      child: Column(
                        children: [
                          option(
                            HabitCycleChoice.restart,
                            strings.cycleOptionRestartTitle,
                            strings.cycleOptionRestartBody,
                          ),
                          option(
                            HabitCycleChoice.change,
                            strings.cycleOptionChangeTitle,
                            strings.cycleOptionChangeBody,
                          ),
                          option(
                            HabitCycleChoice.close,
                            strings.cycleOptionCloseTitle,
                            strings.cycleOptionCloseBody,
                          ),
                        ],
                      ),
                    ),
                    if (_choice == HabitCycleChoice.change) ...[
                      const SizedBox(height: 16),
                      CycleLengthField(
                        length: _length,
                        custom: _lengthCustom,
                        onPreset: (value) => setState(() {
                          _length = value;
                          _lengthCustom = false;
                        }),
                        onCustom: () => setState(() => _lengthCustom = true),
                        onLengthChanged: (value) => setState(
                          () => _length = value.clamp(
                            kMinCycleLength,
                            kMaxCycleLength,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Starts on the current reward, shown inactive: it
                      // says where it was, but changing course means
                      // choosing it again on purpose.
                      IntensityField(
                        label: strings.habitRewardLabel,
                        intensity: _reward,
                        touched: _rewardTouched,
                        showUntouchedValue: true,
                        onChanged: (value) => setState(() {
                          _rewardTouched = true;
                          _reward = value;
                        }),
                        onReset: () => setState(() {
                          _rewardTouched = false;
                          _reward = widget.habit.intensity;
                        }),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Align(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: AppButtonLabel(strings.cycleLaterAction),
                          ),
                          ElevatedButton(
                            onPressed: _canConfirm ? _confirm : null,
                            child: AppButtonLabel(
                              closing
                                  ? strings.cycleArchiveAction
                                  : strings.cycleContinueAction,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
