import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/sync/local_collection.dart';
import 'package:inner_stars/sync/merge.dart';
import 'package:inner_stars/sync/remote_store.dart';
import 'package:inner_stars/sync/sync_service.dart';

class _Account extends ChangeNotifier implements SyncAccount {
  _Account([this._uid]);
  String? _uid;
  @override
  String? get uid => _uid;
  set uid(String? value) {
    _uid = value;
    notifyListeners();
  }
}

/// Cloud writes and listener delivery can be controlled independently, as
/// happens when a notification arrives while a request is still in flight.
class _ProbeRemote extends InMemoryRemoteStore {
  final signals = StreamController<String>.broadcast(sync: true);
  final reads = <String>[];
  final watches = <String>[];
  int uploads = 0;
  bool emitInitial = true;
  Future<void> Function(String)? beforeRead;

  @override
  Stream<void> watch(String collection) => Stream<void>.multi((sink) {
    watches.add(collection);
    final subscription = signals.stream
        .where((name) => name == collection)
        .listen((_) => sink.addSync(null), onError: sink.addErrorSync);
    if (emitInitial) sink.addSync(null);
    sink.onCancel = subscription.cancel;
  });

  @override
  Future<RemoteChanges> fetchChangesSince(String name, DateTime? cursor) async {
    reads.add(name);
    await beforeRead?.call(name);
    return super.fetchChangesSince(name, cursor);
  }

  @override
  Future<void> push(String name, List<SyncRecord> records) async {
    uploads += records.length;
    await super.push(name, records);
  }
}

SyncRecord rec(
  String id,
  DateTime at, {
  String v = 'a',
  bool deleted = false,
}) => {
  'id': id,
  'v': v,
  'deleted': deleted,
  'updatedAt': at.toUtc().toIso8601String(),
};

// Deliver the listener's initial snapshot (or a pending cloud event) before flushing.
Future<void> sync(SyncService service) async {
  service.start();
  await Future<void>.delayed(Duration.zero);
  await service.syncNow();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late InMemoryRemoteStore remote;
  late LocalCollection items;
  late DateTime clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = InMemoryRemoteStore();
    items = LocalCollection(prefs, 'items');
    clock = DateTime.utc(2026, 10, 19, 12);
  });

  SyncService build(
    _Account account, {
    ChangeNotifier? changes,
    Duration debounce = const Duration(milliseconds: 40),
    Future<void> Function()? clear,
    String ownerKey = 'data.owner',
  }) => SyncService(
    account: account,
    prefs: prefs,
    targets: [SyncTarget('items', items, changes: changes)],
    remote: (_) => remote,
    debounce: debounce,
    watchDelay: const Duration(milliseconds: 40),
    clearLocalData: clear,
    ownerKey: ownerKey,

    now: () => clock,
  );

  test('does nothing while signed out', () async {
    final service = build(_Account());
    await items.applyRemote([rec('one', clock)]);
    await sync(service);
    expect(remote.records('items'), isEmpty);
    expect(service.lastSyncAt, isNull);
    service.dispose();
  });

  test('pushes local data, pulls remote data, and remembers when', () async {
    final service = build(_Account('uid-1'));
    await items.applyRemote([rec('phone', clock)]);
    await remote.push('items', [rec('cloud', clock)]);
    await sync(service);
    expect(items.readAll().map((r) => r['id']).toSet(), {'phone', 'cloud'});
    expect(remote.records('items').keys, {'phone', 'cloud'});
    expect(service.status, SyncStatus.idle);
    expect(service.lastSyncAt, clock.toLocal());
    service.dispose();
  });

  test('a later sync sends only what changed since', () async {
    final service = build(_Account('uid-1'));
    await items.applyRemote([
      rec('old', clock.subtract(const Duration(hours: 1))),
    ]);
    await sync(service);
    remote.data['items']!.clear();

    clock = clock.add(const Duration(minutes: 10));
    await items.applyRemote([rec('new', clock)]);
    await sync(service);
    expect(remote.records('items').keys, {'new'});
    service.dispose();
  });

  test(
    'a failure keeps the local data, reports it, and the next try works',
    () async {
      final service = build(_Account('uid-1'));
      await items.applyRemote([rec('one', clock)]);
      remote.failNext = StateError('offline');
      await sync(service);
      expect(service.status, SyncStatus.error);
      expect(service.lastSyncAt, isNull);
      expect(items.readAll(), hasLength(1));

      await sync(service);
      expect(service.status, SyncStatus.idle);
      expect(remote.records('items').keys, {'one'});
      expect(service.lastSyncAt, isNotNull);
      service.dispose();
    },
  );

  test('signing in starts a sync by itself', () async {
    final account = _Account();
    final service = build(account);
    await items.applyRemote([rec('one', clock)]);
    service.start();
    expect(remote.records('items'), isEmpty);
    account.uid = 'uid-1';
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(remote.records('items').keys, {'one'});
    service.dispose();
  });

  test('a local change schedules a sync after the debounce', () async {
    final changes = ChangeNotifier();
    final service = build(_Account('uid-1'), changes: changes);
    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await items.applyRemote([
      rec('edited', clock.add(const Duration(minutes: 5))),
    ]);
    changes.notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(remote.records('items').keys, contains('edited'));
    service.dispose();
    changes.dispose();
  });

  test('two devices of one account converge', () async {
    final a = build(_Account('uid-a'));
    await items.applyRemote([rec('from-a', clock)]);
    await sync(a);

    // Device B: its own storage and its own account object, same cloud.
    final other = LocalCollection(prefs, 'items-b');
    final b = SyncService(
      account: _Account('uid-b'),
      prefs: prefs,
      targets: [SyncTarget('items', other)],
      remote: (_) => remote,
      ownerKey: 'data.owner.b',
      now: () => clock,
    );
    await sync(b);
    expect(other.readAll().map((r) => r['id']), ['from-a']);

    clock = clock.add(const Duration(minutes: 3));
    await other.applyRemote([rec('from-a', clock, deleted: true)]);
    await sync(b);
    await sync(a);
    expect(items.readAll().single['deleted'], true);
    a.dispose();
    b.dispose();
  });

  group('one account per set of data', () {
    test(
      'a different account replaces the data instead of receiving it',
      () async {
        // Account A's data, synced.
        final a = build(_Account('uid-a'));
        await items.applyRemote([rec('a-private', clock)]);
        await sync(a);
        a.dispose();
        final cloudA = Map.of(remote.records('items'));

        // Account B has its own cloud copy; its device is the same phone.
        final cloudB = InMemoryRemoteStore();
        await cloudB.push('items', [rec('b-data', clock)]);
        var cleared = 0;
        final b = SyncService(
          account: _Account('uid-b'),
          prefs: prefs,
          targets: [SyncTarget('items', items)],
          remote: (_) => cloudB,
          clearLocalData: () async {
            cleared++;
            await prefs.remove('items');
          },
          now: () => clock,
        );
        await sync(b);

        expect(cleared, 1);
        // B sees only B's data, and none of A's reached B's cloud.
        expect(items.readAll().map((r) => r['id']), ['b-data']);
        expect(cloudB.records('items').keys, {'b-data'});
        // A's cloud is exactly as it was.
        expect(remote.records('items'), cloudA);
        b.dispose();
      },
    );

    test('without a way to clear, it refuses to mix', () async {
      final a = build(_Account('uid-a'));
      await items.applyRemote([rec('a-private', clock)]);
      await sync(a);
      a.dispose();

      final cloudB = InMemoryRemoteStore();
      final b = SyncService(
        account: _Account('uid-b'),
        prefs: prefs,
        targets: [SyncTarget('items', items)],
        remote: (_) => cloudB,
        now: () => clock,
      );
      await sync(b);
      expect(b.status, SyncStatus.error);
      expect(cloudB.records('items'), isEmpty);
      expect(items.readAll().map((r) => r['id']), ['a-private']);
      b.dispose();
    });

    test('the same account coming back keeps its data', () async {
      var cleared = 0;
      final a = build(_Account('uid-a'), clear: () async => cleared++);
      await items.applyRemote([rec('mine', clock)]);
      await sync(a);
      await sync(a);
      expect(cleared, 0);
      expect(items.readAll(), hasLength(1));
      a.dispose();
    });

    test(
      'data made before any sign-in is adopted by the first account',
      () async {
        var cleared = 0;
        final a = build(_Account('uid-a'), clear: () async => cleared++);
        await items.applyRemote([rec('made-offline', clock)]);
        await sync(a);
        expect(cleared, 0);
        expect(remote.records('items').keys, {'made-offline'});
        a.dispose();
      },
    );

    test(
      'after the account is deleted the next one can adopt the data',
      () async {
        var cleared = 0;
        final a = build(_Account('uid-a'), clear: () async => cleared++);
        await items.applyRemote([rec('mine', clock)]);
        await sync(a);
        await a.deleteCloudData();
        a.dispose();

        final again = build(_Account('uid-new'), clear: () async => cleared++);
        await sync(again);
        expect(cleared, 0);
        expect(remote.records('items').keys, {'mine'});
        again.dispose();
      },
    );
  });

  test(
    'a write by another device is pulled within seconds, with no timer wait',
    () async {
      final service = build(_Account('uid-1'));
      service.start();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(items.readAll(), isEmpty);

      // Another device writes; this one is told and pulls by itself.
      await remote.push('items', [rec('from-elsewhere', clock)]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(items.readAll().map((r) => r['id']), ['from-elsewhere']);
      service.dispose();
    },
  );

  test('pausedWhile holds syncing off and asks for one afterwards', () async {
    final service = build(_Account('uid-1'));
    await items.applyRemote([rec('one', clock)]);
    var ranInside = false;
    await service.pausedWhile(() async {
      await sync(service); // refused while paused
      ranInside = true;
      expect(remote.records('items'), isEmpty);
    });
    expect(ranInside, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(remote.records('items').keys, {'one'});
    service.dispose();
  });

  test(
    'deleteCloudData empties every collection and forgets the positions',
    () async {
      final service = build(_Account('uid-1'));
      await items.applyRemote([rec('one', clock)]);
      await sync(service);
      expect(remote.records('items'), isNotEmpty);
      await prefs.setString('sync.settings-meta', '{}');

      await service.deleteCloudData();
      expect(remote.records('items'), isEmpty);
      expect(
        prefs.getKeys().where(
          (k) => k.startsWith('sync.') && k != 'sync.settings-meta',
        ),
        isEmpty,
      );
      expect(prefs.containsKey('sync.settings-meta'), isTrue);
      // Local data is untouched.
      expect(items.readAll(), hasLength(1));
      service.dispose();
    },
  );

  test('after the positions are reset a sync brings everything back', () async {
    final service = build(_Account('uid-1'));
    await remote.push('items', [rec('cloud', clock)]);
    await sync(service);
    await prefs.remove('items'); // the device was emptied
    await service.resetPositions();
    await sync(service);
    expect(items.readAll().map((r) => r['id']), ['cloud']);
    service.dispose();
  });

  test('settings target runs its callback when remote values arrive', () async {
    var applied = 0;
    final target = SyncTarget('items', _Counting(items, () => applied++));
    final service = SyncService(
      account: _Account('uid-1'),
      prefs: prefs,
      targets: [target],
      remote: (_) => remote,
      now: () => clock,
    );
    await remote.push('items', [rec('cloud', clock)]);
    await sync(service);
    expect(applied, 1);
    service.dispose();
  });

  testWidgets('idle time and lifecycle changes never poll the cloud', (
    tester,
  ) async {
    final probe = _ProbeRemote();
    remote = probe;
    final service = build(_Account('uid-1'));
    service.start();
    await tester.pump();
    await tester.runAsync(service.syncNow);
    await tester.pump(const Duration(seconds: 2));
    probe.reads.clear();

    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(minutes: 10));
    expect(probe.reads, isEmpty);
    service.dispose();
    await probe.signals.close();
  });

  test('local edits upload without any cloud query', () async {
    final probe = _ProbeRemote();
    remote = probe;
    final changes = ChangeNotifier();
    final service = build(_Account('uid-1'), changes: changes);
    await sync(service);
    probe.reads.clear();

    clock = clock.add(const Duration(minutes: 5));
    await items.applyRemote([rec('local', clock)]);
    changes.notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(probe.records('items').keys, {'local'});
    expect(probe.reads, isEmpty);
    await service.syncNow();
    expect(probe.uploads, 1); // The overlap window must not upload it again.
    service.dispose();
    changes.dispose();
    await probe.signals.close();
  });

  test('applying a cloud edit does not upload it back', () async {
    final probe = _ProbeRemote();
    remote = probe;
    final changes = ChangeNotifier();
    final service = SyncService(
      account: _Account('uid-1'),
      prefs: prefs,
      targets: [
        SyncTarget(
          'items',
          _Counting(items, changes.notifyListeners),
          changes: changes,
        ),
      ],
      remote: (_) => probe,
      now: () => clock,
    );
    await sync(service);
    await probe.push('items', [rec('cloud', clock)]);
    probe.signals.add('items');
    await service.syncNow();
    await service.syncNow();
    expect(probe.uploads, 1); // Only the original cloud write.
    expect(items.readAll().single['id'], 'cloud');
    service.dispose();
    changes.dispose();
    await probe.signals.close();
  });

  test('only the collection whose listener fires is queried', () async {
    final probe = _ProbeRemote();
    final other = LocalCollection(prefs, 'other');
    final service = SyncService(
      account: _Account('uid-1'),
      prefs: prefs,
      targets: [SyncTarget('items', items), SyncTarget('other', other)],
      remote: (_) => probe,
      watchDelay: const Duration(milliseconds: 10),
      now: () => clock,
    );
    await sync(service);
    probe.reads.clear();
    await probe.push('other', [rec('cloud', clock)]);
    probe.signals.add('other');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(probe.reads, ['other']);
    expect(other.readAll().single['id'], 'cloud');
    expect(items.readAll(), isEmpty);
    service.dispose();
    await probe.signals.close();
  });

  test('an update arriving during a pull is not lost', () async {
    final probe = _ProbeRemote();
    remote = probe;
    final service = build(_Account('uid-1'));
    await sync(service);
    probe.reads.clear();
    final entered = Completer<void>();
    final release = Completer<void>();
    probe.beforeRead = (_) async {
      entered.complete();
      await release.future;
    };
    probe.signals.add('items');
    await entered.future;
    await probe.push('items', [rec('arrived-during-pull', clock)]);
    probe.signals.add('items');
    probe.beforeRead = null;
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(probe.reads, ['items', 'items']);
    expect(items.readAll().single['id'], 'arrived-during-pull');
    service.dispose();
    await probe.signals.close();
  });

  test('failed listener pulls remain pending for retry', () async {
    final probe = _ProbeRemote();
    remote = probe;
    final service = build(_Account('uid-1'));
    await sync(service);
    probe.reads.clear();
    await probe.push('items', [rec('cloud', clock)]);
    probe.failNext = StateError('offline');
    probe.signals.add('items');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(service.status, SyncStatus.error);
    await service.syncNow();
    expect(probe.reads, ['items', 'items']);
    expect(items.readAll().single['id'], 'cloud');
    service.dispose();
    await probe.signals.close();
  });

  test(
    'waits for the first server signal before uploading local data',
    () async {
      final probe = _ProbeRemote()..emitInitial = false;
      remote = probe;
      await items.applyRemote([rec('same', clock)]);
      await probe.push('items', [
        rec('same', clock.add(const Duration(minutes: 1)), v: 'newer'),
      ]);
      final service = build(_Account('uid-1'));
      await sync(service);
      expect(probe.reads, isEmpty);
      expect(service.lastSyncAt, isNull);
      expect(probe.records('items')['same']!['v'], 'newer');
      probe.signals.add('items');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(items.readAll().single['v'], 'newer');
      service.dispose();
      await probe.signals.close();
    },
  );

  testWidgets('a failed listener is reconnected without polling', (
    tester,
  ) async {
    final probe = _ProbeRemote();
    remote = probe;
    final service = build(_Account('uid-1'));
    // Keep the subscription in the fake-clock zone, so pump advances its
    // reconnect timer; only preferences I/O needs runAsync.
    service.start();
    await tester.pump();
    await tester.runAsync(service.syncNow);
    await tester.pump(const Duration(seconds: 2));
    probe.reads.clear();
    probe.emitInitial = false;
    probe.signals.addError(StateError('listener disconnected'));
    await tester.pump();
    expect(service.status, SyncStatus.error);
    await tester.pump(const Duration(seconds: 30));
    expect(probe.watches, ['items', 'items']);
    expect(probe.reads, isEmpty);
    await tester.runAsync(() async {
      await probe.push('items', [rec('after-reconnect', clock)]);
      probe.signals.add('items');
      await service.syncNow();
    });
    expect(items.readAll().single['id'], 'after-reconnect');
    expect(service.status, SyncStatus.idle);
    service.dispose();
    await probe.signals.close();
  });
}

class _Counting implements SyncCollection {
  _Counting(this._inner, this._onApplied);
  final SyncCollection _inner;
  final VoidCallback _onApplied;
  @override
  List<SyncRecord> readAll() => _inner.readAll();
  @override
  Future<List<SyncRecord>> exportChangesSince(DateTime? since) =>
      _inner.exportChangesSince(since);
  @override
  Future<int> applyRemote(List<SyncRecord> remote) async {
    final n = await _inner.applyRemote(remote);
    if (n > 0) _onApplied();
    return n;
  }
}
