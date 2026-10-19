import 'package:uuid/uuid.dart';

import 'repository_write.dart';

import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';
import '../models/project.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

/// Reads and writes the user's projects as a single JSON-encoded list under
/// one [SharedPreferences] key, newest first — mirrors [StarRepository]'s
/// shape exactly, since the same "small list, always read/written whole"
/// reasoning applies here.
class ProjectRepository extends ChangeNotifier with SyncableRepository {
  ProjectRepository(this._prefs);

  static const _storageKey = 'projects-list';

  final SharedPreferences _prefs;

  @override
  String get syncName => 'projects';

  @override
  late final LocalCollection syncCollection = LocalCollection(
    _prefs,
    _storageKey,
  );

  static Future<ProjectRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProjectRepository(prefs);
  }

  /// All projects currently stored, newest first.
  List<Project> getAll({bool includeDeleted = false}) {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => Project.fromJson(entry as Map<String, dynamic>))
          .where((record) => includeDeleted || !record.deleted)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Projects in [area], newest first.
  List<Project> getProjectsForArea(LifeArea area) {
    return getAll().where((p) => p.area == area).toList();
  }

  Future<Project> add({
    required String name,
    required LifeArea area,
    required String iconSlug,
    String? starsShapeId,
    String? description,
  }) async {
    final projects = getAll();
    final trimmedDescription = description?.trim();
    final project = Project(
      id: const Uuid().v4(),
      name: name.trim(),
      area: area,
      iconSlug: iconSlug,
      starsShapeId: starsShapeId,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: DateTime.now(),
    );

    final savedRecords = await _saveAll([project, ...projects]);
    return savedRecords.firstWhere((record) => record.id == project.id);
  }

  /// Backfills a [Project] that predates the hand-drawn constellation editor
  /// (or was seeded without one) with a [StarsShape] created for
  /// it — see `backfillMissingConstellations`, the only caller. Keeps the
  /// project's position in the list. Throws if [projectId] doesn't match
  /// anything saved.
  Future<Project> assignStarsShape({
    required String projectId,
    required String starsShapeId,
  }) async {
    final projects = getAll();
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      throw StateError('No project found with id $projectId');
    }

    final updated = projects[index].copyWith(starsShapeId: starsShapeId);
    projects[index] = updated;
    final savedRecords = await _saveAll(projects);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Renames a project in place, keeping its id (and every star/habit tied
  /// to it) intact — used by `seedSampleData` when the app's language has
  /// changed since a project was last seeded, so it switches over to the
  /// new locale's name instead of spawning a duplicate under it. Throws if
  /// [projectId] doesn't match anything saved.
  Future<Project> renameProject({
    required String projectId,
    required String name,
  }) async {
    final projects = getAll();
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      throw StateError('No project found with id $projectId');
    }

    final updated = projects[index].copyWith(name: name);
    projects[index] = updated;
    final savedRecords = await _saveAll(projects);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Updates a constellation without changing its identity or its position in
  /// the newest-first list. Its stars and pulsars remain attached by id.
  Future<Project> update({
    required String projectId,
    required String name,
    required LifeArea area,
    required String iconSlug,
    required String? starsShapeId,
    String? description,
  }) async {
    final projects = getAll();
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index == -1) throw StateError('No project found with id $projectId');
    final trimmedDescription = description?.trim();
    final existing = projects[index];
    final updated = Project(
      id: existing.id,
      name: name.trim(),
      area: area,
      iconSlug: iconSlug,
      starsShapeId: starsShapeId,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    projects[index] = updated;
    final savedRecords = await _saveAll(projects);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Deletes this project from the UI and keeps a sync tombstone. Related records are
  /// removed by the coordinating screen/repositories, where their photos and
  /// completion history can be cleaned up too.
  Future<void> delete(String projectId) async {
    final projects = getAll();
    await _saveAll(projects.where((p) => p.id != projectId).toList());
  }

  /// Deletes every project from the UI, retaining tombstones for synchronization.
  Future<void> clear() async {
    await _saveAll([]);
  }

  Future<List<Project>> _saveAll(List<Project> projects) async {
    final saved = await writeSyncList<Project>(
      _prefs,
      _storageKey,
      projects,
      encode: (record) => record.toJson(),
      decode: Project.fromJson,
    );
    notifyListeners();
    return saved;
  }
}
