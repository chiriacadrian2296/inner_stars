import 'package:uuid/uuid.dart';

import 'repository_write.dart';

import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_completion.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Reads and writes every habit's daily completions as a single JSON-encoded
/// list under one [SharedPreferences] key — kept separate from [Habit]
/// itself (rather than embedded in it) so editing a habit's title never has
/// to read/write years of accumulated completion dates, and so stats
/// utilities can bucket by day the same way `star_stats.dart` already does
/// for stars.
class HabitCompletionRepository extends ChangeNotifier with SyncableRepository {
  HabitCompletionRepository(this._prefs);

  static const _storageKey = 'habit-completions-list-v1';

  final SharedPreferences _prefs;

  @override
  String get syncName => 'habit-completions';

  @override
  late final LocalCollection syncCollection = LocalCollection(
    _prefs,
    _storageKey,
  );

  static Future<HabitCompletionRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return HabitCompletionRepository(prefs);
  }

  List<HabitCompletion> getAll({bool includeDeleted = false}) {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (entry) => HabitCompletion.fromJson(entry as Map<String, dynamic>),
          )
          .where((record) => includeDeleted || !record.deleted)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<HabitCompletion> getAllForHabit(String habitId) {
    return getAll().where((c) => c.habitId == habitId).toList();
  }

  /// Marks [habitId] done for [date] (defaults to today), normalized to
  /// day-only. Idempotent — a habit already marked done that day is left
  /// untouched, at most one completion record per (habit, day).
  Future<void> markDone(String habitId, {DateTime? date}) async {
    final day = _dateOnly(date ?? DateTime.now());
    final completions = getAll();
    final alreadyDone = completions.any(
      (c) => c.habitId == habitId && c.date == day,
    );
    if (alreadyDone) return;

    final completion = HabitCompletion(
      id: const Uuid().v4(),
      habitId: habitId,
      date: day,
      createdAt: DateTime.now(),
    );
    await _saveAll([completion, ...completions]);
  }

  /// Writes many completions in one pass — one record per entry of [days]
  /// (a day listed twice logs two instances, like [logInstance]) — with
  /// guaranteed-unique ids. For sample data, where hundreds of one-at-a-time
  /// writes would be slow and could mint colliding ids.
  Future<void> addMany(String habitId, Iterable<DateTime> days) async {
    final added = [
      for (final day in days)
        HabitCompletion(
          id: const Uuid().v4(),
          habitId: habitId,
          date: _dateOnly(day),
          createdAt: DateTime.now(),
        ),
    ];
    if (added.isEmpty) return;
    await _saveAll([...added, ...getAll()]);
  }

  /// Undoes a mis-tap: removes [habitId]'s completion record for [date] (day
  /// granularity), if any.
  Future<void> unmarkDone(String habitId, DateTime date) async {
    final day = _dateOnly(date);
    final completions = getAll();
    final nextCompletions = completions
        .where((c) => !(c.habitId == habitId && c.date == day))
        .toList();
    await _saveAll(nextCompletions);
  }

  /// For a daily habit whose `targetPerPeriod` is more than 1 (e.g. "3 times
  /// a day") — unlike [markDone], always appends a new record for [date]
  /// (defaults to today) rather than refusing a second one; that day's count
  /// (see `habitCompletionCountsByDay`) is simply how many rows exist for it.
  /// Not idempotent on purpose — each tap is one more instance logged.
  Future<void> logInstance(String habitId, {DateTime? date}) async {
    final day = _dateOnly(date ?? DateTime.now());
    final completion = HabitCompletion(
      id: const Uuid().v4(),
      habitId: habitId,
      date: day,
      createdAt: DateTime.now(),
    );
    await _saveAll([completion, ...getAll()]);
  }

  /// [logInstance]'s own undo — removes just the most recently logged
  /// instance for [habitId] on [date], using its creation time and keeping
  /// the newest-first storage order to break ties. Leaves earlier instances
  /// alone. Unlike [unmarkDone], never clears the whole day at once.
  Future<void> unlogLastInstance(String habitId, DateTime date) async {
    final day = _dateOnly(date);
    final completions = getAll();
    HabitCompletion? latest;
    for (final completion in completions) {
      if (completion.habitId != habitId || completion.date != day) continue;
      if (latest == null || completion.createdAt.isAfter(latest.createdAt)) {
        latest = completion;
      }
    }
    if (latest == null) return;
    final target = latest;
    await _saveAll(completions.where((c) => c.id != target.id).toList());
  }

  /// Deletes a habit's completions for sync, when its project is permanently
  /// deleted or the archived habit starts afresh through resurrection.
  Future<void> deleteAllForHabit(String habitId) async {
    final completions = getAll();
    final nextCompletions = completions
        .where((c) => c.habitId != habitId)
        .toList();
    await _saveAll(nextCompletions);
  }

  Future<void> clear() async {
    await _saveAll([]);
  }

  Future<List<HabitCompletion>> _saveAll(
    List<HabitCompletion> completions,
  ) async {
    final saved = await writeSyncList<HabitCompletion>(
      _prefs,
      _storageKey,
      completions,
      encode: (record) => record.toJson(),
      decode: HabitCompletion.fromJson,
    );
    notifyListeners();
    return saved;
  }
}
