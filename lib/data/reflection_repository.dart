import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/life_area.dart';
import '../models/rich_text_document.dart';
import '../models/reflection.dart';
import 'repository_write.dart';
import '../sync/local_collection.dart';
import '../sync/syncable_repository.dart';

class ReflectionRepository extends ChangeNotifier with SyncableRepository {
  ReflectionRepository(this._prefs);
  static const storageKey = 'reflections-v2';
  final SharedPreferences _prefs;

  @override
  String get syncName => 'reflections';

  @override
  late final LocalCollection syncCollection = LocalCollection(
    _prefs,
    storageKey,
  );

  static Future<ReflectionRepository> create() async =>
      ReflectionRepository(await SharedPreferences.getInstance());

  List<Reflection> getAll({bool includeDeleted = false}) {
    final raw = _prefs.getString(storageKey);
    return [
      for (final row in raw == null ? const [] : jsonDecode(raw) as List)
        Reflection.fromJson(Map<String, dynamic>.from(row as Map)),
    ].where((record) => includeDeleted || !record.deleted).toList();
  }

  List<Reflection> getForArea(LifeArea area) =>
      getAll().where((record) => record.area == area).toList()..sort((a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });

  Reflection? find(String id) {
    for (final record in getAll()) {
      if (record.id == id) return record;
    }
    return null;
  }

  Future<Reflection> add({
    required LifeArea area,
    required String title,
    required String body,
    RichTextDocument? richText,
    ReflectionOrigin origin = ReflectionOrigin.free,
    String? questionId,
    String? questionText,
  }) async {
    _validate(title, body);
    if (origin == ReflectionOrigin.suggested && questionId == null) {
      throw ArgumentError('A suggested reflection needs its question identity');
    }
    final now = DateTime.now().toUtc();
    final record = Reflection(
      id: const Uuid().v4(),
      area: area,
      title: title.trim(),
      body: body.trim(),
      richText: richText,
      origin: origin,
      questionId: questionId,
      questionText: questionText,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _save([...getAll(), record]);
    return saved.firstWhere((value) => value.id == record.id);
  }

  Future<Reflection> update(
    String id, {
    required String title,
    required String body,
    RichTextDocument? richText,
  }) async {
    _validate(title, body);
    final existing = find(id);
    if (existing == null) throw StateError('Reflection no longer exists');
    final saved = await _save([
      for (final record in getAll())
        if (record.id == id)
          existing.edit(
            title: title.trim(),
            body: body.trim(),
            richText: richText,
          )
        else
          record,
    ]);
    return saved.firstWhere((value) => value.id == id);
  }

  Future<void> delete(String id) async {
    await _save(getAll().where((record) => record.id != id).toList());
  }

  Future<void> clear() async {
    await _save([]);
  }

  void _validate(String title, String body) {
    if (title.trim().isEmpty || body.trim().isEmpty) {
      throw ArgumentError('Title and body are required');
    }
  }

  Future<List<Reflection>> _save(List<Reflection> records) async {
    final saved = await writeSyncList<Reflection>(
      _prefs,
      storageKey,
      records,
      encode: (record) => record.toJson(),
      decode: Reflection.fromJson,
    );
    notifyListeners();
    return saved;
  }
}
