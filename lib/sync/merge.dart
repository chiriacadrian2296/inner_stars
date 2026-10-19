import 'dart:convert';

/// A persisted record: a JSON map with at least `id`, `updatedAt` (ISO 8601)
/// and `deleted`.
typedef SyncRecord = Map<String, dynamic>;

enum SyncWinner { local, remote, same }

DateTime _time(SyncRecord record) =>
    DateTime.parse(record['updatedAt'] as String).toUtc();

String _canonical(SyncRecord record) {
  final keys = record.keys.toList()..sort();
  return jsonEncode({for (final key in keys) key: record[key]});
}

/// Last write wins. On an equal clock a tombstone beats a live record, and
/// otherwise the larger canonical encoding wins, so every device picks the
/// same side regardless of who merges.
SyncWinner pickWinner(SyncRecord local, SyncRecord remote) {
  final byTime = _time(local).compareTo(_time(remote));
  if (byTime != 0) return byTime > 0 ? SyncWinner.local : SyncWinner.remote;
  final localText = _canonical(local);
  final remoteText = _canonical(remote);
  if (localText == remoteText) return SyncWinner.same;
  final localDeleted = local['deleted'] == true;
  if (localDeleted != (remote['deleted'] == true)) {
    return localDeleted ? SyncWinner.local : SyncWinner.remote;
  }
  return localText.compareTo(remoteText) > 0
      ? SyncWinner.local
      : SyncWinner.remote;
}

class MergeResult {
  const MergeResult({required this.applyLocally, required this.pushRemotely});

  /// Remote records that are new or newer than the local copy.
  final List<SyncRecord> applyLocally;

  /// Local records that are new or newer than the remote copy.
  final List<SyncRecord> pushRemotely;
}

/// Compares two collections by id. Pure and idempotent: merging again after
/// applying both lists yields empty lists.
MergeResult mergeCollections(
  Iterable<SyncRecord> local,
  Iterable<SyncRecord> remote,
) {
  final localById = {for (final r in local) r['id'] as String: r};
  final remoteById = {for (final r in remote) r['id'] as String: r};
  final apply = <SyncRecord>[];
  final push = <SyncRecord>[];
  for (final entry in remoteById.entries) {
    final mine = localById[entry.key];
    if (mine == null) {
      apply.add(entry.value);
      continue;
    }
    switch (pickWinner(mine, entry.value)) {
      case SyncWinner.remote:
        apply.add(entry.value);
      case SyncWinner.local:
        push.add(mine);
      case SyncWinner.same:
        break;
    }
  }
  for (final entry in localById.entries) {
    if (!remoteById.containsKey(entry.key)) push.add(entry.value);
  }
  return MergeResult(applyLocally: apply, pushRemotely: push);
}
