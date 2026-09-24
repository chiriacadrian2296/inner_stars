import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/habit_stats.dart';
import '../widgets/area_tag.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/project_tag.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/star_glyph.dart';
import '../widgets/star_heatmap.dart';
import 'star_form_screen.dart';

/// A pulsar's own detail/dashboard screen — current streak, the intensity
/// of the effort it costs each day, a [StarHeatmap] of its history, and a
/// big "mark today done" action. Not a prev/next full-bleed browser like
/// [StarReaderScreen]: a pulsar isn't one of a sequence of past moments,
/// it's a single ongoing thing.
///
/// A pulsar that's been deleted is a dead star (see [Habit.dead]) — this
/// screen then drops the whole dashboard and offers only what a dead star
/// can do: be reignited, always as a pulsar again.
class PulsarReaderScreen extends StatefulWidget {
  const PulsarReaderScreen({
    super.key,
    required this.habit,
    required this.project,
    required this.habitRepository,
    required this.habitCompletionRepository,
    required this.projectRepository,
    required this.starsShapeRepository,
  });

  final Habit habit;
  final Project? project;
  final HabitRepository habitRepository;
  final HabitCompletionRepository habitCompletionRepository;
  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  State<PulsarReaderScreen> createState() => _PulsarReaderScreenState();
}

class _PulsarReaderScreenState extends State<PulsarReaderScreen> {
  late Habit _habit = widget.habit;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The binary path — a [HabitFrequency.weekly] habit's own day is still a
  /// plain yes/no (only the week-level count has a target), and so is any
  /// daily habit whose target is exactly 1. See [_logInstance]/
  /// [_unlogInstance] for the daily-N-times stepper this doesn't cover.
  Future<void> _toggleToday(bool done) async {
    if (done) {
      await widget.habitCompletionRepository.unmarkDone(_habit.id, _today);
    } else {
      await widget.habitCompletionRepository.markDone(_habit.id);
    }
    setState(() {});
  }

  /// The stepper path — a [HabitFrequency.daily] habit whose target is more
  /// than 1 (e.g. "3 times a day"). Each tap logs one more instance today
  /// regardless of how many already exist; there's no upper cap, so
  /// exceeding the target (25 pages instead of 20) still just reads as
  /// "25/20" rather than being refused.
  Future<void> _logInstance() async {
    await widget.habitCompletionRepository.logInstance(_habit.id);
    setState(() {});
  }

  Future<void> _unlogInstance() async {
    await widget.habitCompletionRepository.unlogLastInstance(
      _habit.id,
      _today,
    );
    setState(() {});
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingHabit: _habit,
          contextProject: widget.project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;

    // A tombstone, not an erasure — the pulsar stays in the sky as a dead
    // star. Popping back out is still right: what's left isn't this
    // dashboard, and the caller reloads either way.
    if (result is StarFormDeleteRequested) {
      await widget.habitRepository.delete(_habit.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final formResult = result as StarFormResult;
    final updated = await widget.habitRepository.update(
      id: _habit.id,
      title: formResult.title,
      description: formResult.description,
      projectId: formResult.projectId,
      intensity: formResult.intensity ?? _habit.intensity,
      frequency: formResult.habitFrequency ?? _habit.frequency,
      targetPerPeriod:
          formResult.habitTargetPerPeriod ?? _habit.targetPerPeriod,
      reminderHour: formResult.reminderHour,
      reminderMinute: formResult.reminderMinute,
    );
    setState(() => _habit = updated);
  }

  /// Brings this dead pulsar back — as a pulsar, never as anything else.
  /// What a dead star can become is decided by what it was, so the form
  /// opens locked to [StarKind.pulsar] with no kind switch at all.
  Future<void> _reignite() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingHabit: _habit,
          contextProject: widget.project,
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
          hideDelete: true,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    final updated = await widget.habitRepository.resurrect(
      _habit.id,
      title: result.title,
      description: result.description,
      projectId: result.projectId,
      intensity: result.intensity ?? _habit.intensity,
      frequency: result.habitFrequency ?? _habit.frequency,
      targetPerPeriod: result.habitTargetPerPeriod ?? _habit.targetPerPeriod,
      reminderHour: result.reminderHour,
      reminderMinute: result.reminderMinute,
      completionRepository: widget.habitCompletionRepository,
    );
    if (mounted) setState(() => _habit = updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final completions = widget.habitCompletionRepository.getAllForHabit(
      _habit.id,
    );
    final countsByDay = habitCompletionCountsByDay(completions);
    final streak = habitCurrentStreak(_habit, countsByDay);
    final isWeekly = _habit.frequency == HabitFrequency.weekly;
    final isDailyStepper =
        !isWeekly && _habit.targetPerPeriod > 1;
    final todayCount = habitDailyProgress(_habit, countsByDay);
    final doneToday = countsByDay.containsKey(_today);
    final weekProgress = isWeekly
        ? habitWeeklyProgress(_habit, countsByDay)
        : 0;

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          // The scrollable itself spans the full window width (so its
          // auto-attached Scrollbar sits at the true page edge on wide
          // viewports); only its content is capped/centered.
          children: [
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.arrow_back, color: colors.muted),
                        ),
                        Expanded(
                          child: Text(
                            _habit.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: colors.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_habit.dead)
                          StaggeredEntrance(
                            index: 0,
                            axis: Axis.horizontal,
                            child: IconButton(
                              onPressed: _edit,
                              icon: Icon(
                                Icons.edit_outlined,
                                color: colors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.project != null) ...[
                    const SizedBox(height: 8),
                    StaggeredEntrance(
                      index: 1,
                      child: AreaTag(
                        area: widget.project!.area,
                        iconSize: 20,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StaggeredEntrance(
                      index: 1,
                      child: ProjectTag(project: widget.project!, fontSize: 14),
                    ),
                  ],
                  if (_habit.description != null) ...[
                    const SizedBox(height: 14),
                    StaggeredEntrance(
                      index: 1,
                      child: Text(
                        _habit.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (_habit.dead) ...[
                    const SizedBox(height: 36),
                    StaggeredEntrance(
                      index: 1,
                      replayKey: _habit.dead,
                      child: Center(
                        child: StarGlyph(kind: StarKind.dead, size: 44),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StaggeredEntrance(
                      index: 2,
                      replayKey: _habit.dead,
                      child: Text(
                        StarKind.dead.label(strings),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaggeredEntrance(
                      index: 3,
                      replayKey: _habit.dead,
                      child: Text(
                        strings.deadPulsarBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: colors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    StaggeredEntrance(
                      index: 4,
                      replayKey: _habit.dead,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _reignite,
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(strings.reigniteAction),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Dead and alive share these positions, so each block
                    // below replays when a reignite flips [_habit.dead].
                    const SizedBox(height: 24),
                    StaggeredEntrance(
                      index: 2,
                      replayKey: _habit.dead,
                      child: Center(
                        child: Column(
                          children: [
                            StaggeredEntrance(
                              index: 0,
                              child: Text(
                                '$streak',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: colors.gold,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            StaggeredEntrance(
                              index: 1,
                              child: Text(
                                strings.habitCurrentStreakLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.muted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            if (isWeekly) ...[
                              const SizedBox(height: 6),
                              StaggeredEntrance(
                                index: 2,
                                child: Text(
                                  strings.habitProgressThisWeek(
                                    weekProgress,
                                    _habit.targetPerPeriod,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            // What keeping this up costs you on any given day —
                            // the same 1-5 scale every other kind of star
                            // carries, and the reason a two-minute habit and a
                            // punishing one don't read as the same thing.
                            StaggeredEntrance(
                              index: 3,
                              child: IntensityBolts(
                                intensity: _habit.intensity,
                                size: 20,
                                spacing: 4,
                                emphasizeLast: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggeredEntrance(
                      index: 3,
                      replayKey: _habit.dead,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        clipBehavior: Clip.antiAlias,
                        decoration: panelDecoration(colors),
                        child: StarHeatmap(
                          countsByDay: countsByDay,
                          intensityByDay: countsByDay,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isDailyStepper) ...[
                      // A daily habit whose target is more than 1 (e.g. "3
                      // times a day") isn't a plain done/not-done toggle —
                      // each tap logs one more instance, with no cap on
                      // exceeding the target.
                      StaggeredEntrance(
                        index: 4,
                        replayKey: _habit.dead,
                        child: Center(
                          child: Text(
                            strings.habitProgressToday(
                              todayCount,
                              _habit.targetPerPeriod,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StaggeredEntrance(
                            index: 4,
                            axis: Axis.horizontal,
                            child: IconButton(
                              onPressed: todayCount > 0 ? _unlogInstance : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: colors.gold,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          StaggeredEntrance(
                            index: 5,
                            axis: Axis.horizontal,
                            child: IconButton(
                              onPressed: _logInstance,
                              icon: Icon(
                                Icons.add_circle,
                                color: colors.gold,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      StaggeredEntrance(
                        index: 4,
                        replayKey: _habit.dead,
                        child: SizedBox(
                          width: double.infinity,
                          // Done today reads as the secondary (outlined) form
                          // of the same action: the pulsar is already burning,
                          // so the button stops being the thing to reach for.
                          child: doneToday
                              ? OutlinedButton.icon(
                                  onPressed: () => _toggleToday(true),
                                  icon: const Icon(Icons.check_circle),
                                  label: Text(strings.habitDoneTodayLabel),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => _toggleToday(false),
                                  icon: const Icon(
                                    Icons.radio_button_unchecked,
                                  ),
                                  label: Text(strings.markHabitDoneAction),
                                ),
                        ),
                      ),
                      if (doneToday) ...[
                        const SizedBox(height: 8),
                        StaggeredEntrance(
                          index: 5,
                          replayKey: _habit.dead,
                          child: Center(
                            child: TextButton(
                              onPressed: () => _toggleToday(true),
                              child: Text(
                                strings.undoHabitTodayAction,
                                style: TextStyle(color: colors.muted),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
