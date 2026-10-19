import 'repository_write.dart';

import 'package:uuid/uuid.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_constellation.dart';
import 'constellation_presets.dart';
import 'constellation_shape.dart';

/// Reads and writes the user's own constellation shapes as a single
/// JSON-encoded list under one [SharedPreferences] key, newest first —
/// mirrors [ProjectRepository]'s shape exactly, since the same "small list,
/// always read/written whole" reasoning applies here.
class StarsShapeRepository {
  StarsShapeRepository(this._prefs);

  static const _storageKey = 'custom-constellations-list';

  final SharedPreferences _prefs;

  static Future<StarsShapeRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StarsShapeRepository(prefs);
  }

  /// All saved custom shapes, newest first.
  List<StarsShape> getAll({bool includeDeleted = false}) {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => StarsShape.fromJson(entry as Map<String, dynamic>))
          .where((record) => includeDeleted || !record.deleted)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  StarsShape? getById(String id) {
    for (final shape in getAll()) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  /// The first shape saved from [presetId], or null if the library preset
  /// has never been picked. Only ever matches an *untouched* copy — [update]
  /// drops the tag as soon as the user edits one (see
  /// [StarsShape.presetId]).
  StarsShape? findByPresetId(String presetId) {
    for (final shape in getAll()) {
      if (shape.presetId == presetId) return shape;
    }
    return null;
  }

  /// The saved copy of [preset], creating it on first use. Picking the same
  /// library shape for a second project therefore reuses the first copy
  /// instead of stacking up identical entries named "Heart", "Heart",
  /// "Heart" in the user's own list.
  Future<StarsShape> materializePreset(
    StarsShapePreset preset, {
    String? languageCode,
  }) async {
    final existing = findByPresetId(preset.id);
    if (existing != null) return existing;
    return add(
      name: preset.name.of(languageCode ?? 'en'),
      shape: preset.shape,
      presetId: preset.id,
    );
  }

  Future<StarsShape> add({
    required String name,
    required ConstellationShape shape,
    String? presetId,
  }) async {
    final shapes = getAll();
    final created = StarsShape(
      id: const Uuid().v4(),
      name: name.trim(),
      shape: shape,
      createdAt: DateTime.now(),
      presetId: presetId,
    );

    final savedRecords = await _saveAll([created, ...shapes]);
    return savedRecords.firstWhere((record) => record.id == created.id);
  }

  /// Replaces the name/shape of an existing custom constellation in place,
  /// keeping its [StarsShape.id] (so any [Project.starsShapeId]
  /// referencing it keeps pointing at the right thing) and its position in
  /// the list (unlike [add], this doesn't move it to the front — editing
  /// isn't "creating something new"). Throws if [id] doesn't match anything
  /// saved.
  ///
  /// Also drops any [StarsShape.presetId]: an edited copy is the
  /// user's own shape now, and leaving the tag on would make the next
  /// project that picks that library shape silently inherit these edits.
  Future<StarsShape> update({
    required String id,
    required String name,
    required ConstellationShape shape,
  }) async {
    final shapes = getAll();
    final index = shapes.indexWhere((s) => s.id == id);
    if (index == -1) {
      throw StateError('No custom constellation found with id $id');
    }

    final updated = StarsShape(
      id: id,
      name: name.trim(),
      shape: shape,
      createdAt: shapes[index].createdAt,
    );
    shapes[index] = updated;
    final savedRecords = await _saveAll(shapes);
    return savedRecords.firstWhere((record) => record.id == updated.id);
  }

  /// Permanently deletes every custom shape. Used by the "reset all data"
  /// action — there's no undo.
  Future<void> clear() async {
    await _saveAll([]);
  }

  /// Removes an orphaned saved shape. Callers must first ensure no project
  /// still refers to it, since preset shapes may be shared.
  Future<void> delete(String id) async {
    await _saveAll(getAll().where((shape) => shape.id != id).toList());
  }

  Future<List<StarsShape>> _saveAll(List<StarsShape> shapes) async {
    final saved = await writeSyncList<StarsShape>(
      _prefs,
      _storageKey,
      shapes,
      encode: (record) => record.toJson(),
      decode: StarsShape.fromJson,
    );
    return saved;
  }
}
