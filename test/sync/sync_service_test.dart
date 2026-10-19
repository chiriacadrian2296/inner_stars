import 'package:flutter/foundation.dart';
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
  }) => SyncService(
    account: account,
    prefs: prefs,
    targets: [SyncTarget('items', items, changes: changes)],
    remote: (_) => remote,
    debounce: debounce,
    interval: const Duration(hours: 1),
    now: () => clock,
  );

  test('does nothing while signed out', () async {
    final service = build(_Account());
    await items.applyRemote([rec('one', clock)]);
    await service.syncNow();
    expect(remote.records('items'), isEmpty);
    expect(service.lastSyncAt, isNull);
    service.dispose();
  });

  test('pushes local data, pulls remote data, and remembers when', () async {
    final service = build(_Account('uid-1'));
    await items.applyRemote([rec('phone', clock)]);
    await remote.push('items', [rec('cloud', clock)]);
    await service.syncNow();
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
    await service.syncNow();
    remote.data['items']!.clear();

    clock = clock.add(const Duration(minutes: 10));
    await items.applyRemote([rec('new', clock)]);
    await service.syncNow();
    expect(remote.records('items').keys, {'new'});
    service.dispose();
  });

  test(
    'a failure keeps the local data, reports it, and the next try works',
    () async {
      final service = build(_Account('uid-1'));
      await items.applyRemote([rec('one', clock)]);
      remote.failNext = StateError('offline');
      await service.syncNow();
      expect(service.status, SyncStatus.error);
      expect(service.lastSyncAt, isNull);
      expect(items.readAll(), hasLength(1));

      await service.syncNow();
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
    await a.syncNow();

    // Device B: its own storage and its own account object, same cloud.
    final other = LocalCollection(prefs, 'items-b');
    final b = SyncService(
      account: _Account('uid-b'),
      prefs: prefs,
      targets: [SyncTarget('items', other)],
      remote: (_) => remote,
      now: () => clock,
    );
    await b.syncNow();
    expect(other.readAll().map((r) => r['id']), ['from-a']);

    clock = clock.add(const Duration(minutes: 3));
    await other.applyRemote([rec('from-a', clock, deleted: true)]);
    await b.syncNow();
    await a.syncNow();
    expect(items.readAll().single['deleted'], true);
    a.dispose();
    b.dispose();
  });

  test('pausedWhile holds syncing off and asks for one afterwards', () async {
    final service = build(_Account('uid-1'));
    await items.applyRemote([rec('one', clock)]);
    var ranInside = false;
    await service.pausedWhile(() async {
      await service.syncNow(); // refused while paused
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
      await service.syncNow();
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
    await service.syncNow();
    await prefs.remove('items'); // the device was emptied
    await service.resetPositions();
    await service.syncNow();
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
    await service.syncNow();
    expect(applied, 1);
    service.dispose();
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
