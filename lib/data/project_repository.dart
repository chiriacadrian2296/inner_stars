import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';
import '../models/project.dart';

/// Reads and writes the user's projects as a single JSON-encoded list under
/// one [SharedPreferences] key, newest first — mirrors [StarRepository]'s
/// shape exactly, since the same "small list, always read/written whole"
/// reasoning applies here.
class ProjectRepository {
  ProjectRepository(this._prefs);

  static const _storageKey = 'projects-list';

  final SharedPreferences _prefs;

  static Future<ProjectRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProjectRepository(prefs);
  }

  /// All projects currently stored, newest first.
  List<Project> getAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => Project.fromJson(entry as Map<String, dynamic>))
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
    int? starsShapeId,
    String? description,
  }) async {
    final projects = getAll();
    final trimmedDescription = description?.trim();
    final project = Project(
      id: _nextId(projects),
      name: name.trim(),
      area: area,
      iconSlug: iconSlug,
      starsShapeId: starsShapeId,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      createdAt: DateTime.now(),
    );

    await _saveAll([project, ...projects]);
    return project;
  }

  /// Ids are millisecondsSinceEpoch, which two adds inside the same
  /// millisecond would collide on — and a duplicate id is not cosmetic here:
  /// [assignStarsShape] and [renameProject] both find their target
  /// by id, so they'd keep resolving to whichever twin comes first and the
  /// other would silently never be updated (`backfillMissingConstellations`
  /// leaving the second of two same-icon projects with no shape at all is
  /// how this first showed up). Stepping past anything already taken makes
  /// back-to-back adds safe — `seedSampleData` creates nine projects in a
  /// loop — without callers having to sleep between them.
  static int _nextId(List<Project> existing) {
    var id = DateTime.now().millisecondsSinceEpoch;
    final taken = existing.map((p) => p.id).toSet();
    while (taken.contains(id)) {
      id++;
    }
    return id;
  }

  /// Backfills a [Project] that predates the hand-drawn constellation editor
  /// (or was seeded without one) with a [StarsShape] created for
  /// it — see `backfillMissingConstellations`, the only caller. Keeps the
  /// project's position in the list. Throws if [projectId] doesn't match
  /// anything saved.
  Future<Project> assignStarsShape({
    required int projectId,
    required int starsShapeId,
  }) async {
    final projects = getAll();
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      throw StateError('No project found with id $projectId');
    }

    final updated = projects[index].copyWith(
      starsShapeId: starsShapeId,
    );
    projects[index] = updated;
    await _saveAll(projects);
    return updated;
  }

  /// Renames a project in place, keeping its id (and every star/habit tied
  /// to it) intact — used by `seedSampleData` when the app's language has
  /// changed since a project was last seeded, so it switches over to the
  /// new locale's name instead of spawning a duplicate under it. Throws if
  /// [projectId] doesn't match anything saved.
  Future<Project> renameProject({
    required int projectId,
    required String name,
  }) async {
    final projects = getAll();
    final index = projects.indexWhere((p) => p.id == projectId);
    if (index == -1) {
      throw StateError('No project found with id $projectId');
    }

    final updated = projects[index].copyWith(name: name);
    projects[index] = updated;
    await _saveAll(projects);
    return updated;
  }

  /// Updates a constellation without changing its identity or its position in
  /// the newest-first list. Its stars and pulsars remain attached by id.
  Future<Project> update({
    required int projectId,
    required String name,
    required LifeArea area,
    required String iconSlug,
    required int? starsShapeId,
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
          ? null : trimmedDescription,
      createdAt: existing.createdAt,
    );
    projects[index] = updated;
    await _saveAll(projects);
    return updated;
  }

  /// Permanently removes just this project. Related records are deliberately
  /// removed by the coordinating screen/repositories, where their photos and
  /// completion history can be cleaned up too.
  Future<void> delete(int projectId) async {
    final projects = getAll();
    await _saveAll(projects.where((p) => p.id != projectId).toList());
  }

  /// Permanently deletes every project. Used by the "reset all data" action
  /// — there's no undo.
  Future<void> clear() async {
    await _prefs.remove(_storageKey);
  }

  Future<void> _saveAll(List<Project> projects) async {
    final encoded = jsonEncode(projects.map((p) => p.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
