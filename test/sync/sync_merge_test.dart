import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/sync/local_collection.dart';
import 'package:inner_stars/sync/merge.dart';
import 'package:inner_stars/sync/remote_store.dart';

SyncRecord rec(String id, int minute, {String v = 'a', bool deleted = false}) =>
    {
      'id': id,
      'v': v,
      'deleted': deleted,
      'updatedAt': DateTime.utc(2026, 10, 19, 12, minute).toIso8601String(),
    };

void main() {
  group('pickWinner', () {
    test('newer clock wins', () {
      expect(pickWinner(rec('x', 2), rec('x', 1)), SyncWinner.local);
      expect(pickWinner(rec('x', 1), rec('x', 2)), SyncWinner.remote);
    });

    test('identical records are the same', () {
      expect(pickWinner(rec('x', 1), rec('x', 1)), SyncWinner.same);
    });

    test('on a tie a tombstone beats a live record, on both devices', () {
      final live = rec('x', 1, v: 'z');
      final dead = rec('x', 1, deleted: true);
      expect(pickWinner(live, dead), SyncWinner.remote);
      expect(pickWinner(dead, live), SyncWinner.local);
    });

    test('a tie of two live records picks the same side everywhere', () {
      final a = rec('x', 1, v: 'a');
      final b = rec('x', 1, v: 'b');
      final first = pickWinner(a, b) == SyncWinner.local ? a : b;
      final second = pickWinner(b, a) == SyncWinner.local ? b : a;
      expect(first, second);
    });
  });

  group('mergeCollections', () {
    test('splits new and newer records both ways', () {
      final result = mergeCollections(
        [rec('l-only', 1), rec('both', 5), rec('both2', 1)],
        [rec('r-only', 1), rec('both', 3), rec('both2', 4)],
      );
      expect(result.applyLocally.map((r) => r['id']).toSet(), {
        'r-only',
        'both2',
      });
      expect(result.pushRemotely.map((r) => r['id']).toSet(), {
        'l-only',
        'both',
      });
    });

    test('is idempotent once both sides applied', () {
      final local = [rec('a', 1), rec('b', 5)];
      final remote = [rec('b', 3), rec('c', 2)];
      final first = mergeCollections(local, remote);
      final mergedLocal = {
        for (final r in [...local, ...first.applyLocally]) r['id']: r,
      };
      final mergedRemote = {
        for (final r in [...remote, ...first.pushRemotely]) r['id']: r,
      };
      mergedLocal.addAll({
        for (final r in first.applyLocally) r['id'] as String: r,
      });
      final again = mergeCollections(mergedLocal.values, mergedRemote.values);
      expect(again.applyLocally, isEmpty);
      expect(again.pushRemotely, isEmpty);
    });

    test('a newer tombstone propagates deletion', () {
      final result = mergeCollections(
        [rec('a', 1)],
        [rec('a', 2, deleted: true)],
      );
      expect(result.applyLocally.single['deleted'], true);
      expect(result.pushRemotely, isEmpty);
    });
  });

  group('syncCollection', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // Two devices sharing the remote; each has its own storage key.
    LocalCollection device(String key) => LocalCollection(prefs, key);

    test('two devices converge through the remote', () async {
      final remote = InMemoryRemoteStore();
      final a = device('a');
      final b = device('b');
      await a.applyRemote([rec('one', 1), rec('two', 2)]);
      await syncCollection(name: 'items', local: a, remote: remote);
      expect(remote.records('items').keys, {'one', 'two'});

      await syncCollection(name: 'items', local: b, remote: remote);
      expect(b.readAll().map((r) => r['id']).toSet(), {'one', 'two'});

      // Device B deletes 'one' later; device A receives the tombstone.
      await b.applyRemote([rec('one', 9, deleted: true)]);
      await syncCollection(
        name: 'items',
        local: b,
        remote: remote,
        pushSince: DateTime.utc(2026, 10, 19, 12, 5),
      );
      await syncCollection(name: 'items', local: a, remote: remote);
      final one = a.readAll().firstWhere((r) => r['id'] == 'one');
      expect(one['deleted'], true);
    });

    test('a first sync merges both sides by record', () async {
      final remote = InMemoryRemoteStore();
      await remote.push('items', [rec('cloud', 1), rec('both', 3, v: 'cloud')]);
      final local = device('a');
      await local.applyRemote([rec('phone', 2), rec('both', 5, v: 'phone')]);
      await syncCollection(name: 'items', local: local, remote: remote);
      expect(local.readAll().map((r) => r['id']).toSet(), {
        'cloud',
        'phone',
        'both',
      });
      expect(remote.records('items').keys, {'cloud', 'phone', 'both'});
      expect(remote.records('items')['both']!['v'], 'phone');
    });

    test('remote clock is kept, not restamped', () async {
      final local = device('a');
      await local.applyRemote([rec('one', 7)]);
      expect(local.readAll().single['updatedAt'], rec('one', 7)['updatedAt']);
    });

    test('offline failure leaves local data untouched and can retry', () async {
      final remote = InMemoryRemoteStore();
      final local = device('a');
      await local.applyRemote([rec('one', 1)]);
      remote.failNext = StateError('offline');
      await expectLater(
        syncCollection(name: 'items', local: local, remote: remote),
        throwsStateError,
      );
      expect(local.readAll(), hasLength(1));
      await syncCollection(name: 'items', local: local, remote: remote);
      expect(remote.records('items').keys, {'one'});
    });

    test(
      'the pull cursor follows the server, so a lagging clock is not missed',
      () async {
        final remote = InMemoryRemoteStore();
        final a = device('a');
        final b = device('b');

        // A pushes, then syncs again to get a server position to resume from.
        await a.applyRemote([rec('a1', 30)]);
        await syncCollection(name: 'items', local: a, remote: remote);
        final first = await syncCollection(
          name: 'items',
          local: a,
          remote: remote,
          pushSince: DateTime.utc(2026, 10, 19, 12, 30),
        );
        expect(first.pullCursor, isNotNull);

        // B's clock is far behind: its record is dated before everything A has.
        await b.applyRemote([rec('b1', 1)]);
        await syncCollection(name: 'items', local: b, remote: remote);

        // A still receives it, because it resumes from the server's position.
        final second = await syncCollection(
          name: 'items',
          local: a,
          remote: remote,
          pullCursor: first.pullCursor,
          pushSince: DateTime.utc(2026, 10, 19, 12, 30),
        );
        expect(second.pulled, greaterThan(0));
        expect(a.readAll().map((r) => r['id']), contains('b1'));
      },
    );

    test('only changes after pushSince are sent', () async {
      final remote = InMemoryRemoteStore();
      final local = device('a');
      await local.applyRemote([rec('old', 1), rec('new', 20)]);
      final out = await syncCollection(
        name: 'items',
        local: local,
        remote: remote,
        pushSince: DateTime.utc(2026, 10, 19, 12, 10),
      );
      expect(out.pushed, 1);
      expect(remote.records('items').keys, {'new'});
    });
  });
}
