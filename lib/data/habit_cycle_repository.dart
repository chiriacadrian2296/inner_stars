import 'package:uuid/uuid.dart';

import 'repository_write.dart';

import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_cycle.dart';
import '../utils/habit_stats.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

/// Reads and writes every pulsar's completed cycles as a single JSON-encoded
/// list under one [SharedPreferences] key — kept apart from [Habit] so a
/// pulsar's own record stays small however many cycles it has finished.
///
/// A cycle exists the moment its goal is reached (see [sync]); the reward is
/// real from then on, whether or not the reflection page was ever opened.
class HabitCycleRepository extends ChangeNotifier with SyncableRepository {
  HabitCycleRepository(this._prefs);

  static const _storageKey = 'habit-cycles-v1';

  final SharedPreferences _prefs;

  @override
  String get syncName => 'habit-cycles';

  @override
  late final LocalCollection syncCollection = LocalCollection(
    _prefs,
    _storageKey,
  );

  static Future<HabitCycleRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return HabitCycleRepository(prefs);
  }

  List<HabitCycle> getAll({bool includeDeleted = false}) {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => HabitCycle.fromJson(entry as Map<String, dynamic>))
          .where((record) => includeDeleted || !record.deleted)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Newest first.
  List<HabitCycle> getAllForHabit(String habitId) {
    return getAll().where((c) => c.habitId == habitId).toList()
      ..sort((a, b) => b.completedDate.compareTo(a.completedDate));
  }

  /// The cycle of [habitId] whose goal was reached but whose reflection
  /// hasn't been finished yet, if any.
  HabitCycle? pendingFor(String habitId) {
    for (final cycle in getAll()) {
      if (cycle.habitId == habitId && !cycle.resolved) return cycle;
    }
    return null;
  }

  /// Reconciles [habit]'s current cycle with its [completions], right after
  /// a check-in was added or undone:
  ///
  /// - the goal is newly reached -> records the cycle (unresolved) and
  ///   returns it, so the caller can open the reflection page;
  /// - the user undid the check-in that had completed it, before finishing
  ///   the reflection -> takes the cycle back, the way un-lighting a star
  ///   takes its intensity back. A resolved cycle is never taken back.
  ///
  /// Returns null when nothing new was created.
  Future<HabitCycle?> sync(
    Habit habit,
    List<HabitCompletion> completions, {
    DateTime? now,
  }) async {
    if (!habit.isActive) return null;
    final counts = habitCompletionCountsByDay(
      completions.where((c) => c.habitId == habit.id).toList(),
    );
    final start = habit.currentCycleStart;
    final all = getAll();
    final existingIndex = all.indexWhere(
      (c) => c.habitId == habit.id && c.startDate == start,
    );
    final completedDay = habitCycleCompletedDay(habit, counts, now: now);

    if (existingIndex != -1) {
      final existing = all[existingIndex];
      final progress = habitCycleProgress(habit, counts, now: now);
      if (!existing.resolved && progress < existing.length) {
        await _saveAll([...all]..removeAt(existingIndex));
      }
      return null;
    }
    if (completedDay == null) return null;

    final cycle = HabitCycle(
      id: const Uuid().v4(),
      habitId: habit.id,
      startDate: start,
      completedDate: completedDay,
      length: habit.cycleLength,
      intensity: habit.intensity,
    );
    final savedRecords = await _saveAll([cycle, ...all]);
    return savedRecords.firstWhere((record) => record.id == cycle.id);
  }

  /// Writes already-built cycles — for sample data, which backdates whole
  /// histories.
  Future<void> addMany(Iterable<HabitCycle> cycles) async {
    final added = cycles.toList();
    if (added.isEmpty) return;
    await _saveAll([...added, ...getAll()]);
  }

  /// Marks [cycleId] as reflected on, saving the optional answers.
  Future<HabitCycle> resolve(
    String cycleId, {
    String? whatHelped,
    String? whatWasHard,
    String? howItFeels,
  }) async {
    final all = getAll();
    final index = all.indexWhere((c) => c.id == cycleId);
    if (index == -1) {
      throw StateError('No habit cycle found with id $cycleId');
    }
    String? clean(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final updated = HabitCycle(
      id: all[index].id,
      habitId: all[index].habitId,
      startDate: all[index].startDate,
      completedDate: all[index].completedDate,
      length: all[index].length,
      intensity: all[index].intensity,
      resolved: true,
      whatHelped: clean(whatHelped),
      whatWasHard: clean(whatWasHard),
      howItFeels: clean(howItFeels),
    );
    final savedRecords = await _saveAll([...all]..[index] = updated);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Deletes the cycles of a permanently deleted project's habits for sync.
  Future<void> deleteAllForHabits(Iterable<String> habitIds) async {
    final ids = habitIds.toSet();
    if (ids.isEmpty) return;
    final all = getAll();
    await _saveAll(all.where((c) => !ids.contains(c.habitId)).toList());
  }

  Future<void> clear() async {
    await _saveAll([]);
  }

  Future<List<HabitCycle>> _saveAll(List<HabitCycle> cycles) async {
    final saved = await writeSyncList<HabitCycle>(
      _prefs,
      _storageKey,
      cycles,
      encode: (record) => record.toJson(),
      decode: HabitCycle.fromJson,
    );
    notifyListeners();
    return saved;
  }
}
