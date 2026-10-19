import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Writes a complete local collection. Only changed records get a new clock;
/// omissions become deletion records, and existing tombstones survive later saves.
/// All persisted and returned timestamps are assigned through this path.
Future<List<T>> writeSyncList<T>(
  SharedPreferences prefs,
  String key,
  List<T> records, {
  required Map<String, dynamic> Function(T) encode,
  required T Function(Map<String, dynamic>) decode,
}) async {
  final raw = prefs.getString(key);
  final previous = <String, Map<String, dynamic>>{};
  for (final value in raw == null ? const [] : jsonDecode(raw) as List) {
    final normalized = encode(decode(Map<String, dynamic>.from(value as Map)));
    final id = normalized['id'] as String;
    if (previous.containsKey(id)) throw StateError('Duplicate stored identity');
    previous[id] = normalized;
  }
  final incoming = <String, Map<String, dynamic>>{};
  for (final record in records) {
    final value = encode(record);
    final id = value['id'] as String;
    if (incoming.containsKey(id)) throw StateError('Duplicate record identity');
    incoming[id] = value;
  }
  final saved = reconcileLocalRecords(previous, incoming);
  await writeRepositoryValue(prefs, key, jsonEncode(saved.values.toList()));
  return saved.values.map(decode).toList();
}

/// The map counterpart for records whose identity is the persisted map key.
Future<void> writeSyncMap<T>(
  SharedPreferences prefs,
  String key,
  Map<String, T> records, {
  required Map<String, dynamic> Function(T) encode,
  required T Function(Map<String, dynamic>) decode,
}) async {
  final raw = prefs.getString(key);
  final previous = <String, Map<String, dynamic>>{};
  if (raw != null) {
    for (final entry in (jsonDecode(raw) as Map<String, dynamic>).entries) {
      previous[entry.key] = encode(
        decode(Map<String, dynamic>.from(entry.value as Map)),
      );
    }
  }
  final incoming = records.map((id, record) => MapEntry(id, encode(record)));
  await writeRepositoryValue(
    prefs,
    key,
    jsonEncode(reconcileLocalRecords(previous, incoming)),
  );
}

Map<String, Map<String, dynamic>> reconcileLocalRecords(
  Map<String, Map<String, dynamic>> previous,
  Map<String, Map<String, dynamic>> incoming,
) {
  final now = DateTime.now().toUtc();
  final result = <String, Map<String, dynamic>>{};
  Map<String, dynamic> content(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(value)..remove('updatedAt');
  Map<String, dynamic> stamp(
    Map<String, dynamic> value,
    Map<String, dynamic>? old,
  ) {
    final previousTime = old == null
        ? null
        : DateTime.parse(old['updatedAt'] as String);
    final next = previousTime == null || now.isAfter(previousTime)
        ? now
        : previousTime.add(const Duration(microseconds: 1));
    return {...value, 'updatedAt': next.toIso8601String()};
  }

  for (final entry in incoming.entries) {
    final old = previous[entry.key];
    result[entry.key] =
        old != null &&
            jsonEncode(content(old)) == jsonEncode(content(entry.value))
        ? old
        : stamp(entry.value, old);
  }
  for (final entry in previous.entries) {
    if (incoming.containsKey(entry.key)) continue;
    result[entry.key] = entry.value['deleted'] == true
        ? entry.value
        : stamp({...entry.value, 'deleted': true}, entry.value);
  }
  return result;
}

/// SharedPreferences updates its memory cache before the platform acknowledges
/// a write. Restore that cache on failure so readers never show a false save.
Future<void> writeRepositoryValue(
  SharedPreferences prefs,
  String key,
  String? value,
) async {
  final previous = prefs.getString(key);
  try {
    final saved = value == null
        ? await prefs.remove(key)
        : await prefs.setString(key, value);
    if (!saved) throw StateError('Could not save repository');
  } catch (_) {
    try {
      if (previous == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
    } catch (_) {
      // The cache is restored before this platform operation is attempted.
    }
    rethrow;
  }
}
