import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../data/habit_completion_repository.dart';
import '../data/habit_cycle_repository.dart';
import '../data/habit_repository.dart';
import '../models/habit.dart';
import '../models/habit_cycle.dart';
import '../screens/habit_cycle_reflection_screen.dart';

/// Watches every check-in and edit and keeps pulsar cycles in step with them,
/// in this one place rather than at each of the many spots that can check a
/// habit in.
///
/// Whenever completions or habits change it reconciles each active pulsar
/// with [HabitCycleRepository.sync]: a cycle whose goal was just reached is
/// recorded (the reward is earned right then) and the end-of-cycle reflection
/// page opens on top of whatever the user is looking at; a check-in undone
/// before the reflection was finished takes the cycle back.
///
/// Placed above the Navigator (it is given the app's navigator key) so the
/// page opens no matter which screen the check-in happened on.
class HabitCycleHost extends StatefulWidget {
  const HabitCycleHost({
    super.key,
    required this.navigatorKey,
    required this.habitRepository,
    required this.completionRepository,
    required this.cycleRepository,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final HabitRepository habitRepository;
  final HabitCompletionRepository completionRepository;
  final HabitCycleRepository cycleRepository;
  final Widget child;

  @override
  State<HabitCycleHost> createState() => _HabitCycleHostState();
}

/// Opens the reflection page for [cycle] of [habit] on [navigator]. Used by
/// the host right after a cycle is earned and by the "Reflect on the Cycle"
/// action on a pulsar whose reflection was left for later.
Future<bool> openHabitCycleReflection({
  required NavigatorState navigator,
  required Habit habit,
  required HabitCycle cycle,
  required HabitRepository habitRepository,
  required HabitCycleRepository cycleRepository,
}) async {
  final result = await navigator.push<bool>(
    MaterialPageRoute(
      builder: (_) => HabitCycleReflectionScreen(
        habit: habit,
        cycle: cycle,
        habitRepository: habitRepository,
        cycleRepository: cycleRepository,
      ),
    ),
  );
  return result ?? false;
}

class _HabitCycleHostState extends State<HabitCycleHost> {
  final _queue = Queue<(int, int)>();
  bool _syncing = false;
  bool _syncAgain = false;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.completionRepository.addListener(_onChanged);
    widget.habitRepository.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.completionRepository.removeListener(_onChanged);
    widget.habitRepository.removeListener(_onChanged);
    super.dispose();
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Future<void> _onChanged() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        final completions = widget.completionRepository.getAll();
        for (final habit in widget.habitRepository.getAll()) {
          if (!habit.isActive) continue;
          final cycle = await widget.cycleRepository.sync(habit, completions);
          // Only a goal reached today pops the page up: a cycle found
          // complete from an earlier day (sample data, a lowered length)
          // just waits, with its "reflect" action on the pulsar.
          if (cycle != null && _isToday(cycle.completedDate)) {
            _queue.add((habit.id, cycle.id));
          }
        }
      } while (_syncAgain);
    } finally {
      _syncing = false;
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_showing) return;
    _showing = true;
    try {
      while (_queue.isNotEmpty) {
        final (habitId, cycleId) = _queue.removeFirst();
        // Let the check-in's own feedback (a closing dialog, a snackbar)
        // settle before a whole page covers it.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        final navigator = widget.navigatorKey.currentState;
        if (navigator == null) return;
        final habit = widget.habitRepository
            .getAll()
            .where((h) => h.id == habitId && h.isActive)
            .firstOrNull;
        final cycle = widget.cycleRepository
            .getAllForHabit(habitId)
            .where((c) => c.id == cycleId && !c.resolved)
            .firstOrNull;
        // Undone or already handled in the meantime.
        if (habit == null || cycle == null) continue;
        await openHabitCycleReflection(
          navigator: navigator,
          habit: habit,
          cycle: cycle,
          habitRepository: widget.habitRepository,
          cycleRepository: widget.cycleRepository,
        );
      }
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
