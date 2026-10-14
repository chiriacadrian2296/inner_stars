import 'package:flutter/widgets.dart';

import '../data/habit_cycle_repository.dart';

/// Hands the [HabitCycleRepository] to any screen below the Navigator without
/// threading it through every constructor that already carries the habit
/// repositories. Listening to it (the default `maybeOf`/`of`) rebuilds the
/// caller whenever a cycle is earned, resolved or removed.
class HabitCycleScope extends InheritedNotifier<HabitCycleRepository> {
  const HabitCycleScope({
    super.key,
    required HabitCycleRepository repository,
    required super.child,
  }) : super(notifier: repository);

  /// Null when no scope is above [context] (e.g. a widget test that doesn't
  /// care about cycles) — callers then simply behave as if no cycle was ever
  /// earned.
  static HabitCycleRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HabitCycleScope>()?.notifier;

  /// Same as [maybeOf] but without subscribing, for event handlers.
  static HabitCycleRepository? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HabitCycleScope>()?.notifier;
}
