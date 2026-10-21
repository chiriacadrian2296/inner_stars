import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository_write.dart';
import 'merge.dart';
import 'remote_store.dart';

/// What the sync engine needs from any persisted collection.
abstract interface class SyncCollection {
  List<SyncRecord> readAll();

  /// Records changed after [since] (all when null), tombstones included.
  Future<List<SyncRecord>> exportChangesSince(DateTime? since);

  /// Writes the remote records that win the merge, keeping their clock.
  /// Returns how many local records changed.
  Future<int> applyRemote(List<SyncRecord> remote);
}

enum _Shape { list, keyedMap, single }

/// Sync access to one persisted collection. Three storage shapes exist:
/// a JSON list of records (`LocalCollection`), a JSON map whose key is the
/// record identity (`LocalCollection.keyedMap`), and one bare record
/// (`LocalCollection.single`). Records are always exposed with an `id`, an
/// `updatedAt` and a `deleted` field; legacy rows without a clock count as
/// the oldest possible.
class LocalCollection implements SyncCollection {
  LocalCollection(this._prefs, this.key)
    : _shape = _Shape.list,
      _keepId = true,
      _singleId = '';

  /// Records stored as `{id: record}`. [keepId] says whether each stored
  /// record also holds its own `id` (moodboard) or not (visions).
  LocalCollection.keyedMap(this._prefs, this.key, {bool keepId = false})
    : _shape = _Shape.keyedMap,
      // ignore: prefer_initializing_formals
      _keepId = keepId,
      _singleId = '';

  /// One record stored as is, exposed under [id].
  LocalCollection.single(this._prefs, this.key, {String id = 'current'})
    : _shape = _Shape.single,
      _keepId = false,
      _singleId = id;

  final SharedPreferences _prefs;
  final String key;
  final _Shape _shape;
  final bool _keepId;
  final String _singleId;

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  ).toIso8601String();

  SyncRecord _normalize(String id, Object? value) {
    final record = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{'value': value};
    record['id'] = id;
    record['updatedAt'] ??= _epoch;
    record['deleted'] ??= false;
    return record;
  }

  Map<String, SyncRecord> _readMap() {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    switch (_shape) {
      case _Shape.list:
        return {
          for (final row in decoded as List)
            (row as Map)['id'] as String: _normalize(row['id'] as String, row),
        };
      case _Shape.keyedMap:
        return {
          for (final entry in (decoded as Map).entries)
            entry.key as String: _normalize(entry.key as String, entry.value),
        };
      case _Shape.single:
        return {_singleId: _normalize(_singleId, decoded)};
    }
  }

  @override
  List<SyncRecord> readAll() => _readMap().values.toList();

  @override
  Future<List<SyncRecord>> exportChangesSince(DateTime? since) async => [
    for (final record in readAll())
      if (since == null ||
          DateTime.parse(record['updatedAt'] as String).isAfter(since))
        record,
  ];

  String _encode(Map<String, SyncRecord> records) {
    switch (_shape) {
      case _Shape.list:
        return jsonEncode(records.values.toList());
      case _Shape.keyedMap:
        return jsonEncode({
          for (final entry in records.entries)
            entry.key: _keepId
                ? entry.value
                : (Map.of(entry.value)..remove("id")),
        });
      case _Shape.single:
        return jsonEncode(Map.of(records[_singleId]!)..remove("id"));
    }
  }

  /// Writes remote records verbatim (their clock is kept, not restamped) when
  /// they win the merge. Returns how many local records changed.
  @override
  Future<int> applyRemote(List<SyncRecord> remote) async {
    final local = _readMap();
    var changed = 0;
    for (final incoming in remote) {
      final id = incoming['id'] as String;
      if (_shape == _Shape.single && id != _singleId) continue;
      final mine = local[id];
      if (mine == null || pickWinner(mine, incoming) == SyncWinner.remote) {
        local[id] = Map<String, dynamic>.from(incoming);
        changed++;
      }
    }
    if (changed > 0) {
      await writeRepositoryValue(_prefs, key, _encode(local));
    }
    return changed;
  }
}

/// What one collection sync did.
class SyncOutcome {
  const SyncOutcome(this.pullCursor, this.pulled, this.pushed);

  /// Where the next pull resumes (the remote store's own cursor).
  final DateTime? pullCursor;
  final int pulled;
  final int pushed;
}

/// Pulls what the server has written since [pullCursor], merges it into the
/// local collection, and pushes the local changes made after [pushSince] that
/// the remote lacks. The two positions are deliberately separate: pulls follow
/// the server's clock, pushes follow this device's own clock (its records
/// are stamped with it), so a wrong clock on either side cannot hide changes.
/// First sync (both null) sends and receives everything, merged by record.
/// Set [pull] only for a listener signal. [knownRemote] remembers received and
/// acknowledged records for this session, avoiding uploads of unchanged data
/// in the push cursor's overlap window, including remote changes just applied.
Future<SyncOutcome> syncCollection({
  required String name,
  required SyncCollection local,
  required RemoteStore remote,
  DateTime? pullCursor,
  DateTime? pushSince,
  bool pull = true,
  Map<String, SyncRecord>? knownRemote,
  Map<String, String>? acknowledgedVersions,
  RemoteChanges? changes,
}) async {
  final pulled =
      changes ??
      (pull
          ? await remote.fetchChangesSince(name, pullCursor)
          : RemoteChanges(const [], pullCursor));
  for (final record in pulled.records) {
    knownRemote?[record['id'] as String] = Map.of(record);
    acknowledgedVersions?[record['id'] as String] = syncRecordVersion(record);
  }
  await local.applyRemote(pulled.records);
  final candidates = await local.exportChangesSince(
    acknowledgedVersions == null ? pushSince : null,
  );
  final merge = mergeCollections(
    candidates.where(
      (record) =>
          acknowledgedVersions == null ||
          acknowledgedVersions[record['id']] != syncRecordVersion(record),
    ),
    knownRemote?.values ?? pulled.records,
  );
  if (merge.pushRemotely.isNotEmpty) {
    await remote.push(name, merge.pushRemotely);
    for (final record in merge.pushRemotely) {
      knownRemote?[record['id'] as String] = Map.of(record);
      acknowledgedVersions?[record['id'] as String] = syncRecordVersion(record);
    }
  }
  return SyncOutcome(
    pulled.cursor,
    pulled.records.length,
    merge.pushRemotely.length,
  );
}
