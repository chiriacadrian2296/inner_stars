import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'habit_completion_repository.dart';

/// Reads and writes the user's pulsars (habits) as a single JSON-encoded
/// list under one [SharedPreferences] key — mirrors [StarRepository]'s shape
/// exactly, tombstoning included.
class HabitRepository {
  HabitRepository(this._prefs);

  static const _storageKey = 'habits-list-v1';

  final SharedPreferences _prefs;

  static Future<HabitRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return HabitRepository(prefs);
  }

  /// Every pulsar ever created, dead ones included — a dead pulsar still
  /// has a place in the sky (as a dead star), so most callers want this and
  /// tell the two apart via [Habit.dead].
  List<Habit> getAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => Habit.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<Habit> getAllForProject(int projectId) {
    return getAll().where((h) => h.projectId == projectId).toList();
  }

  /// Only the pulsars still beating — what "how many pulsars does this
  /// constellation have" means everywhere it's counted.
  List<Habit> getActiveForProject(int projectId) {
    return getAllForProject(projectId).where((h) => h.isActive).toList();
  }

  Future<Habit> add({
    required String title,
    String? description,
    required int projectId,
    int intensity = 3,
    HabitFrequency frequency = HabitFrequency.daily,
    int targetPerPeriod = 1,
    int? reminderHour,
    int? reminderMinute,

    /// Backdates the habit's start — only for sample data, so its history
    /// can reach back further than the moment it was seeded.
    DateTime? createdAt,
  }) async {
    final habits = getAll();
    final trimmedDescription = description?.trim();
    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch,
      projectId: projectId,
      title: title.trim(),
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: createdAt ?? DateTime.now(),
      intensity: intensity,
      frequency: frequency,
      targetPerPeriod: targetPerPeriod,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );

    await _saveAll([habit, ...habits]);
    return habit;
  }

  Future<Habit> update({
    required int id,
    required String title,
    String? description,
    required int projectId,
    int intensity = 3,
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
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: existing.createdAt,
      intensity: intensity,
      frequency: frequency,
      targetPerPeriod: targetPerPeriod,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      dead: existing.dead,
      deadDate: existing.deadDate,
    );

    final nextHabits = [...habits]..[index] = updated;
    await _saveAll(nextHabits);
    return updated;
  }

  /// "Deletes" the pulsar identified by [id] — but never actually removes
  /// its record, exactly like [StarRepository.delete]: only [Habit.dead]
  /// flips, so it stays in the sky as a dead star that still knows it was a
  /// pulsar, and [resurrect] can bring it back as one.
  ///
  /// Its completion history is left untouched here — that's [resurrect]'s
  /// job to clear, since a reignited pulsar is a *new* pulsar.
  Future<Habit> delete(int id) async {
    final habits = getAll();
    final index = habits.indexWhere((h) => h.id == id);
    if (index == -1) {
      throw StateError('No habit found with id $id');
    }
    final updated = habits[index].copyWith(
      dead: true,
      deadDate: DateTime.now(),
    );
    final nextHabits = [...habits]..[index] = updated;
    await _saveAll(nextHabits);
    return updated;
  }

  /// Brings a dead pulsar back to life as a brand new pulsar — same [id]
  /// (so its scattered spot in the sky never moves), everything else fresh.
  /// Always a pulsar again: what a dead star can be reignited as is decided
  /// by what it was, never chosen anew.
  ///
  /// "Brand new" includes its history: the old streak is wiped via
  /// [completionRepository], so a reignited pulsar starts from zero rather
  /// than inheriting a run it broke long ago.
  Future<Habit> resurrect(
    int id, {
    required String title,
    String? description,
    required int projectId,
    int intensity = 3,
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
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: existing.createdAt,
      intensity: intensity,
      frequency: frequency,
      targetPerPeriod: targetPerPeriod,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );

    final nextHabits = [...habits]..[index] = updated;
    await _saveAll(nextHabits);
    await completionRepository.deleteAllForHabit(id);
    return updated;
  }

  Future<void> clear() async {
    await _prefs.remove(_storageKey);
  }

  /// Physically removes a constellation's pulsars. Their completion history
  /// is cleaned by the caller, which has access to its separate repository.
  Future<List<int>> deleteAllForProject(int projectId) async {
    final habits = getAll();
    final removed = habits.where((habit) => habit.projectId == projectId).toList();
    await _saveAll(habits.where((habit) => habit.projectId != projectId).toList());
    return removed.map((habit) => habit.id).toList();
  }

  Future<void> _saveAll(List<Habit> habits) async {
    final encoded = jsonEncode(habits.map((h) => h.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
