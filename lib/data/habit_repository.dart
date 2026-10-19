import 'package:uuid/uuid.dart';

import 'repository_write.dart';

import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'constellation_layout.dart';
import 'habit_completion_repository.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

/// Reads and writes the user's pulsars (habits) as a single JSON-encoded
/// list under one [SharedPreferences] key — mirrors [StarRepository]'s shape
/// exactly, tombstoning included.
class HabitRepository extends ChangeNotifier with SyncableRepository {
  HabitRepository(this._prefs);

  static const _storageKey = 'habits-list-v1';

  final SharedPreferences _prefs;

  @override
  String get syncName => 'habits';

  @override
  late final LocalCollection syncCollection = LocalCollection(
    _prefs,
    _storageKey,
  );

  static Future<HabitRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return HabitRepository(prefs);
  }

  /// Every pulsar ever created, dead ones included — a dead pulsar still
  /// has a place in the sky (as a dead star), so most callers want this and
  /// tell the two apart via [Habit.dead].
  List<Habit> getAll({bool includeDeleted = false}) {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => Habit.fromJson(entry as Map<String, dynamic>))
          .where((record) => includeDeleted || !record.deleted)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<Habit> getAllForProject(String projectId) {
    return getAll().where((h) => h.projectId == projectId).toList();
  }

  /// Only the pulsars still beating — what "how many pulsars does this
  /// constellation have" means everywhere it's counted.
  List<Habit> getActiveForProject(String projectId) {
    return getAllForProject(projectId).where((h) => h.isActive).toList();
  }

  /// Whether [projectId]'s constellation can take no more pulsars. Dead ones
  /// still hold their scattered spot, so they count.
  bool isFull(String projectId) =>
      getAllForProject(projectId).length >= kMaxConstellationPulsars;

  Future<Habit> add({
    required String title,
    String? iconSlug,
    String? description,
    required String projectId,
    int intensity = 3,
    int cycleLength = kDefaultCycleLength,
    HabitFrequency frequency = HabitFrequency.daily,
    int targetPerPeriod = 1,
    int? reminderHour,
    int? reminderMinute,

    /// Backdates the habit's start — only for sample data, so its history
    /// can reach back further than the moment it was seeded.
    DateTime? createdAt,
  }) async {
    final habits = getAll();
    if (isFull(projectId)) {
      throw const ConstellationFullException(pulsar: true);
    }
    final trimmedDescription = description?.trim();
    final habit = Habit(
      id: const Uuid().v4(),
      projectId: projectId,
      title: title.trim(),
      iconSlug: iconSlug ?? '',
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: createdAt ?? DateTime.now(),
      intensity: intensity,
      cycleLength: cycleLength,
      frequency: frequency,
      targetPerPeriod: targetPerPeriod,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );

    final savedRecords = await _saveAll([habit, ...habits]);
    return savedRecords.firstWhere((record) => record.id == habit.id);
  }

  Future<Habit> update({
    required String id,
    required String title,
    String? iconSlug,
    String? description,
    required String projectId,
    int intensity = 3,
    int? cycleLength,
    HabitFrequency frequency = HabitFrequency.daily,
    int targetPerPeriod = 1,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final habits = getAll();
    final index = habits.indexWhere((h) => h.id == id);
    if (index == -1) {
      throw StateError('No habit found with id $id');
    }
    final existing = habits[index];
    final trimmedDescription = description?.trim();
    final updated = Habit(
      id: existing.id,
      projectId: projectId,
      title: title.trim(),
      iconSlug: iconSlug ?? existing.iconSlug,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      intensity: intensity,
      cycleLength: cycleLength ?? existing.cycleLength,
      cycleStart: existing.cycleStart,
      frequency: frequency,
      targetPerPeriod: targetPerPeriod,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      dead: existing.dead,
      deadDate: existing.deadDate,
    );

    final nextHabits = [...habits]..[index] = updated;
    final savedRecords = await _saveAll(nextHabits);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// "Deletes" the pulsar identified by [id] — but never actually removes
  /// its record, exactly like [StarRepository.delete]: only [Habit.dead]
  /// flips, so it stays in the sky as a dead star that still knows it was a
  /// pulsar, and [resurrect] can bring it back as one.
  ///
  /// Its completion history is left untouched here — that's [resurrect]'s
  /// job to clear, since a reignited pulsar is a *new* pulsar.
  Future<Habit> delete(String id) async {
    final habits = getAll();
    final index = habits.indexWhere((h) => h.id == id);
    if (index == -1) {
      throw StateError('No habit found with id $id');
    }
    final now = DateTime.now();
    final updated = habits[index].copyWith(
      dead: true,
      deadDate: now,
      updatedAt: now,
    );
    final nextHabits = [...habits]..[index] = updated;
    final savedRecords = await _saveAll(nextHabits);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Brings a dead pulsar back to life as a brand new pulsar — same [id]
  /// (so its scattered spot in the sky never moves), everything else fresh.
  /// Always a pulsar again: what a dead star can be reignited as is decided
  /// by what it was, never chosen anew.
  ///
  /// "Brand new" includes its history: its old check-ins are wiped via
  /// [completionRepository], so a reignited pulsar starts from zero rather
  /// than inheriting a run it broke long ago. Cycles it already completed
  /// stay, though: that reward was earned and is never taken back.
  Future<Habit> resurrect(
    String id, {
    required String title,
    String? iconSlug,
    String? description,
    required String projectId,
    int intensity = 3,
    int cycleLength = kDefaultCycleLength,
    HabitFrequency frequency = HabitFrequency.daily,
    int targetPerPeriod = 1,
    int? reminderHour,
    int? reminderMinute,
    required HabitCompletionRepository completionRepository,
  }) async {
    final habits = getAll();
    final index = habits.indexWhere((h) => h.id == id);
    if (index == -1) {
      throw StateError('No habit found with id $id');
    }
    final existing = habits[index];
    final trimmedDescription = description?.trim();
    final updated = Habit(
      id: existing.id,
      projectId: projectId,
      title: title.trim(),
      iconSlug: iconSlug ?? existing.iconSlug,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      intensity: intensity,
      cycleLength: cycleLength,
      cycleStart: DateTime.now(),
      frequency: frequency,
      targetPerPeriod: targetPerPeriod,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );

    final nextHabits = [...habits]..[index] = updated;
    final savedRecords = await _saveAll(nextHabits);
    await completionRepository.deleteAllForHabit(id);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Opens the pulsar's next cycle after the user finished the reflection on
  /// the last one. [start] is the first day that counts toward it; the
  /// length and reward default to the current ones, and the user may change
  /// either (or keep both for a plain restart).
  Future<Habit> startNextCycle(
    String id, {
    required DateTime start,
    int? cycleLength,
    int? intensity,
  }) async {
    final habits = getAll();
    final index = habits.indexWhere((h) => h.id == id);
    if (index == -1) {
      throw StateError('No habit found with id $id');
    }
    final existing = habits[index];
    final updated = existing.copyWith(
      cycleStart: DateTime(start.year, start.month, start.day),
      cycleLength: cycleLength,
      intensity: intensity,
      updatedAt: DateTime.now(),
    );
    final savedRecords = await _saveAll([...habits]..[index] = updated);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  Future<void> clear() async {
    await _saveAll([]);
  }

  /// Marks a project's habits deleted for sync. Their completion history
  /// is cleaned by the caller, which has access to its separate repository.
  Future<List<String>> deleteAllForProject(String projectId) async {
    final habits = getAll();
    final removed = habits
        .where((habit) => habit.projectId == projectId)
        .toList();
    await _saveAll(
      habits.where((habit) => habit.projectId != projectId).toList(),
    );
    return removed.map((habit) => habit.id).toList();
  }

  Future<List<Habit>> _saveAll(List<Habit> habits) async {
    final saved = await writeSyncList<Habit>(
      _prefs,
      _storageKey,
      habits,
      encode: (record) => record.toJson(),
      decode: Habit.fromJson,
    );
    notifyListeners();
    return saved;
  }
}
