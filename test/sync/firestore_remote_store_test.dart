import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/sync/firestore_remote_store.dart';

class _FakePort implements FirestorePort {
  final docs = <String, Map<String, RemoteDoc>>{};
  var clock = DateTime.utc(2026, 10, 19);
  final batches = <int>[];
  final deleted = <int>[];

  @override
  Stream<void> watchNewest(String collection) => const Stream<void>.empty();

  @override
  Future<int> deleteSome(String collection, int limit) async {
    final bucket = docs[collection] ?? {};
    final ids = bucket.keys.take(limit).toList();
    ids.forEach(bucket.remove);
    if (ids.isNotEmpty) deleted.add(ids.length);
    return ids.length;
  }

  @override
  Future<List<RemoteDoc>> readSince(
    String collection,
    DateTime? cursor,
  ) async => [
    for (final d in (docs[collection] ?? const <String, RemoteDoc>{}).values)
      if (cursor == null || !d.at.isBefore(cursor)) d,
  ];

  @override
  Future<void> writeBatch(
    String collection,
    List<RemoteDocWrite> writes,
  ) async {
    batches.add(writes.length);
    clock = clock.add(const Duration(seconds: 1));
    final bucket = docs.putIfAbsent(collection, () => {});
    for (final w in writes) {
      bucket[w.id] = RemoteDoc(id: w.id, data: w.data, at: clock);
    }
  }
}

Map<String, dynamic> rec(String id, {Object? extra}) => {
  'id': id,
  'updatedAt': '2026-10-19T12:00:00.000Z',
  'deleted': false,
  'shape':
      extra ??
      [
        [1, 2],
        [3, 4],
      ],
};

void main() {
  test(
    'records survive the round trip, nested lists and odd ids included',
    () async {
      final port = _FakePort();
      final store = FirestoreRemoteStore(port);
      await store.push('items', [rec('settings.locale'), rec('a/b c')]);
      final changes = await store.fetchChangesSince('items', null);
      expect(changes.records.map((r) => r['id']).toSet(), {
        'settings.locale',
        'a/b c',
      });
      expect(changes.records.first['shape'], [
        [1, 2],
        [3, 4],
      ]);
      // Document ids never contain a slash.
      expect(port.docs['items']!.keys.every((k) => !k.contains('/')), isTrue);
      expect(changes.cursor, port.clock);
    },
  );

  test('the cursor is the newest server time, or the one asked for', () async {
    final port = _FakePort();
    final store = FirestoreRemoteStore(port);
    final before = DateTime.utc(2026, 1, 1);
    expect((await store.fetchChangesSince('items', before)).cursor, before);
    await store.push('items', [rec('one')]);
    final first = await store.fetchChangesSince('items', null);
    await store.push('items', [rec('two')]);
    final next = await store.fetchChangesSince('items', first.cursor);
    expect(next.records.map((r) => r['id']), containsAll(['one', 'two']));
    expect(next.cursor!.isAfter(first.cursor!), isTrue);
  });

  test(
    'large pushes are split into batches within Firestore\'s limit',
    () async {
      final port = _FakePort();
      final store = FirestoreRemoteStore(port);
      await store.push('items', [for (var i = 0; i < 950; i++) rec('r$i')]);
      expect(port.batches, [400, 400, 150]);
      expect(port.docs['items'], hasLength(950));
    },
  );

  test('stored data is the full record as JSON text', () async {
    final port = _FakePort();
    final store = FirestoreRemoteStore(port);
    await store.push('items', [rec('one')]);
    final raw = port.docs['items']!.values.single.data;
    expect(jsonDecode(raw)['id'], 'one');
  });

  test('deleting a collection removes every document, in batches', () async {
    final port = _FakePort();
    final store = FirestoreRemoteStore(port);
    await store.push('items', [for (var i = 0; i < 950; i++) rec('r$i')]);
    await store.push('other', [rec('keep')]);
    await store.deleteCollection('items');
    expect(port.docs['items'], isEmpty);
    expect(port.deleted, [400, 400, 150]);
    expect(port.docs['other'], hasLength(1));
  });
}
