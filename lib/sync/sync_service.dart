// The private fields cannot be initializing formals of named parameters.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_collection.dart';
import 'merge.dart';
import 'remote_store.dart';
import 'settings_collection.dart';
import 'syncable_repository.dart';

/// Who is signed in. [AuthService] implements it; tests use a fake.
abstract interface class SyncAccount implements Listenable {
  String? get uid;
}

/// One collection the service keeps in sync, with the signal that says it
/// changed locally (when the repository has one).
class SyncTarget {
  const SyncTarget(this.name, this.collection, {this.changes});

  /// A repository that already knows how to apply remote records and notify.
  SyncTarget.repository(this.name, SyncableRepository repository)
    : collection = _RepositoryCollection(repository),
      changes = repository;

  /// The settings, reloaded into the running app when remote values arrive.
  SyncTarget.settings(
    SettingsCollection settings,
    VoidCallback onApplied, {
    this.changes,
  }) : name = 'settings',
       collection = _CallbackCollection(settings, onApplied);

  final String name;
  final SyncCollection collection;
  final Listenable? changes;
}

class _RepositoryCollection implements SyncCollection {
  _RepositoryCollection(this._repository);
  final SyncableRepository _repository;

  @override
  List<SyncRecord> readAll() => _repository.syncCollection.readAll();
  @override
  Future<List<SyncRecord>> exportChangesSince(DateTime? since) =>
      _repository.syncCollection.exportChangesSince(since);
  @override
  Future<int> applyRemote(List<SyncRecord> remote) =>
      _repository.applyRemote(remote);
}

class _CallbackCollection implements SyncCollection {
  _CallbackCollection(this._inner, this._onApplied);
  final SyncCollection _inner;
  final VoidCallback _onApplied;

  @override
  List<SyncRecord> readAll() => _inner.readAll();
  @override
  Future<List<SyncRecord>> exportChangesSince(DateTime? since) =>
      _inner.exportChangesSince(since);
  @override
  Future<int> applyRemote(List<SyncRecord> remote) async {
    final changed = await _inner.applyRemote(remote);
    if (changed > 0) _onApplied();
    return changed;
  }
}

enum SyncStatus { idle, syncing, error }

/// Keeps the local data and the cloud copy in step, with nobody asking for it:
/// Local changes are pushed after a short debounce. Only a collection's cloud
/// listener requests a pull, including its initial server snapshot. There is
/// no polling. Failed work is retained and retried with backoff.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService({
    required SyncAccount account,
    required SharedPreferences prefs,
    required List<SyncTarget> targets,
    required RemoteStore Function(String uid) remote,
    this.clearLocalData,
    this.afterSync,
    this.deleteMedia,
    this.ownerKey = 'data.owner',
    this.debounce = const Duration(seconds: 5),
    this.watchDelay = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _account = account,

       _prefs = prefs,

       _targets = targets,
       _remoteFactory = remote,
       _now = now ?? DateTime.now;

  final SyncAccount _account;
  final SharedPreferences _prefs;
  final List<SyncTarget> _targets;
  final RemoteStore Function(String uid) _remoteFactory;

  /// Empties this device's content (and synced settings). Called when a
  /// different account signs in, so data of two accounts never mixes. Without
  /// it, a sync that finds another account's data refuses to run.
  final Future<void> Function()? clearLocalData;

  /// Called after every successful sync, for work that follows the records
  /// (sending media files). Its errors never fail the sync.
  final Future<void> Function()? afterSync;

  /// Removes the account's media files from the cloud, as part of
  /// [deleteCloudData].
  final Future<void> Function()? deleteMedia;
  final Duration debounce;

  /// How long after another device's write this one waits before pulling.
  final Duration watchDelay;
  final DateTime Function() _now;

  SyncStatus _status = SyncStatus.idle;
  Object? _lastError;
  bool _running = false;
  bool _again = false;
  bool _started = false;
  bool _paused = false;
  bool _disposed = false;
  int _failures = 0;
  String? _lastUid;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  final _pendingChanges = <String, RemoteChanges>{};
  final _acknowledgedVersions = <String, Map<String, String>>{};
  final _readyToPush = <String>{};
  final _knownRemote = <String, Map<String, SyncRecord>>{};
  final _watchers = <String, StreamSubscription<RemoteChanges>>{};
  final _watchRetries = <String, Timer>{};
  final _watchFailures = <String, int>{};

  SyncStatus get status => _status;
  Object? get lastError => _lastError;

  /// When the last full sync of the signed-in account finished, or null.
  DateTime? get lastSyncAt {
    final uid = _account.uid;
    if (uid == null) return null;
    final raw = _prefs.getString('sync.$uid.last-success');
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// Starts listening. Safe to call once the repositories exist.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _account.addListener(_onAccountChanged);
    for (final target in _targets) {
      target.changes?.addListener(_onLocalChange);
    }
    _onAccountChanged();
  }

  void _onAccountChanged() {
    final uid = _account.uid;
    if (uid == _lastUid) return;
    _lastUid = uid;
    _failures = 0;
    _retryTimer?.cancel();
    _pendingChanges.clear();
    _acknowledgedVersions.clear();
    _readyToPush.clear();
    _knownRemote.clear();
    _stopWatching();
    if (uid == null) {
      _debounceTimer?.cancel();
      _setStatus(SyncStatus.idle);
    } else {
      _startWatching(uid);
      schedule(const Duration(milliseconds: 300));
    }
  }

  /// Listens for writes by other devices so their changes arrive within
  /// seconds. A burst of events becomes one sync through the debounce.
  void _startWatching(String uid) {
    final remote = _remoteFactory(uid);
    for (final target in _targets) {
      _watchCollection(uid, remote, target.name);
    }
  }

  void _watchCollection(String uid, RemoteStore remote, String name) {
    _watchers[name] = remote
        .watchChanges(name, _readTime('sync.$uid.$name.pull'))
        .listen(
          (changes) {
            if (_disposed || _account.uid != uid) return;
            _watchFailures.remove(name);
            _watchRetries.remove(name)?.cancel();
            _pendingChanges[name] =
                _pendingChanges[name]?.followedBy(changes) ?? changes;
            if (_running) {
              _again = true;
            } else if (!_paused) {
              schedule(watchDelay);
            }
          },
          onError: (Object error) {
            if (_disposed || _account.uid != uid) return;
            _lastError = error;
            _setStatus(SyncStatus.error);
            final failures = (_watchFailures[name] ?? 0) + 1;
            _watchFailures[name] = failures;
            _watchRetries.remove(name)?.cancel();
            _watchRetries[name] = Timer(
              Duration(
                seconds: (30 * (1 << (failures - 1).clamp(0, 5))).clamp(
                  30,
                  600,
                ),
              ),
              () {
                if (_disposed || _account.uid != uid) return;
                unawaited(_watchers.remove(name)?.cancel());
                _watchCollection(uid, remote, name);
              },
            );
          },
        );
  }

  void _stopWatching() {
    for (final subscription in _watchers.values) {
      unawaited(subscription.cancel());
    }
    _watchers.clear();
    for (final retry in _watchRetries.values) {
      retry.cancel();
    }
    _watchRetries.clear();
    _watchFailures.clear();
  }

  void _onLocalChange() {
    if (_running) {
      _again = true;
      return;
    }
    schedule();
  }

  /// Asks for a sync soon; several requests inside [after] become one.
  void schedule([Duration? after]) {
    if (_disposed || _account.uid == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(after ?? debounce, () => unawaited(syncNow()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      schedule(const Duration(seconds: 1));
    } else if (state == AppLifecycleState.paused) {
      // Push what is pending before the system may stop the app.
      unawaited(syncNow());
    }
  }

  /// Sends pending local edits and pulls only collections signalled by their
  /// listeners. Concurrent calls collapse into one extra run.
  Future<void> syncNow() async {
    final uid = _account.uid;
    if (_disposed || uid == null || _paused) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _retryTimer?.cancel();
    _setStatus(SyncStatus.syncing);
    try {
      await _claimDataFor(uid);
      final remote = _remoteFactory(uid);
      final startedAt = _now().toUtc();
      for (final target in _targets) {
        if (_disposed || _account.uid != uid) return;
        final pullKey = 'sync.$uid.${target.name}.pull';
        final pushKey = 'sync.$uid.${target.name}.push';
        final changes = _pendingChanges.remove(target.name);
        // Wait for the initial server snapshot before uploading: another
        // device may have edited the same records while this one was closed.
        if (changes == null && !_readyToPush.contains(target.name)) continue;
        late final SyncOutcome outcome;
        try {
          outcome = await syncCollection(
            name: target.name,
            local: target.collection,
            remote: remote,
            pullCursor: _readTime(pullKey),
            pushSince: _readTime(pushKey),
            pull: false,
            changes: changes,
            knownRemote: _knownRemote.putIfAbsent(target.name, () => {}),
            acknowledgedVersions: _versionsFor(uid, target),
          );
        } catch (_) {
          if (changes != null && _account.uid == uid) {
            final next = _pendingChanges[target.name];
            _pendingChanges[target.name] = next == null
                ? changes
                : changes.followedBy(next);
          }
          rethrow;
        }
        if (_disposed || _account.uid != uid) return;
        _readyToPush.add(target.name);
        await _prefs.setString(
          'sync.$uid.${target.name}.acked',
          jsonEncode(_acknowledgedVersions[target.name]),
        );
        if (outcome.pullCursor != null) {
          await _prefs.setString(
            pullKey,
            outcome.pullCursor!.toUtc().toIso8601String(),
          );
        }
        // Local writes made while this sync ran are stamped after startedAt;
        // the margin covers clock rounding.
        await _prefs.setString(
          pushKey,
          startedAt.subtract(const Duration(seconds: 2)).toIso8601String(),
        );
      }
      if (_readyToPush.length == _targets.length && _watchRetries.isEmpty) {
        await _prefs.setString(
          'sync.$uid.last-success',
          _now().toUtc().toIso8601String(),
        );
      }
      _failures = 0;
      try {
        await afterSync?.call();
      } catch (_) {
        // Media is retried by its own queue; the records are already synced.
      }
      if (_watchRetries.isEmpty) {
        _lastError = null;
        _setStatus(SyncStatus.idle);
      } else {
        _setStatus(SyncStatus.error);
      }
    } catch (error) {
      if (_disposed || _account.uid != uid) return;
      _lastError = error;
      _failures++;
      _setStatus(SyncStatus.error);
      // 30 s, 1 min, 2 min ... at most 10 min.
      final wait = Duration(
        seconds: (30 * (1 << (_failures - 1).clamp(0, 5))).clamp(30, 600),
      );
      _retryTimer = Timer(wait, () => unawaited(syncNow()));
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        if (_status != SyncStatus.error) schedule(const Duration(seconds: 1));
      }
    }
  }

  /// Runs [action] with syncing held off: waits for a sync in progress, keeps
  /// new ones from starting, and asks for one afterwards. For actions that
  /// must not race with a sync (wiping local data, deleting the account).
  Future<T> pausedWhile<T>(Future<T> Function() action) async {
    _paused = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    try {
      while (_running) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return await action();
    } finally {
      _paused = false;
      if (_account.uid != null) schedule(const Duration(seconds: 1));
    }
  }

  /// Forgets where every sync left off, so the next one starts from scratch
  /// and sends and receives everything. Keeps the settings' own bookkeeping.
  Future<void> resetPositions() async {
    _knownRemote.clear();
    _readyToPush.clear();
    _acknowledgedVersions.clear();
    _pendingChanges.clear();
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('sync.') && key != SettingsCollection.metaKey) {
        await _prefs.remove(key);
      }
    }
    // A reset (for example a local wipe) needs a fresh listener snapshot even
    // when the cloud data has not changed since the previous subscription.
    if (_started && _account.uid != null) {
      _stopWatching();
      _startWatching(_account.uid!);
    }
  }

  /// Deletes every collection of the signed-in account from the cloud. Local
  /// data stays. Call inside [pausedWhile].
  Future<void> deleteCloudData() async {
    final uid = _account.uid;
    if (uid == null) throw StateError('Not signed in');
    final remote = _remoteFactory(uid);
    await deleteMedia?.call();
    for (final target in _targets) {
      await remote.deleteCollection(target.name);
    }
    await resetPositions();
    await releaseOwnership();
  }

  /// Where the owning account is remembered. Only tests, which run two
  /// "devices" over one preferences store, use another name.
  final String ownerKey;

  /// A device's data belongs to one account. The first account to sync adopts
  /// whatever was made before any sign-in; if a different account signs in
  /// later, the previous one's data is replaced by the new account's own,
  /// never merged into it. (The previous account keeps its copy in its cloud.)
  Future<void> _claimDataFor(String uid) async {
    final owner = _prefs.getString(ownerKey);
    if (owner == uid) return;
    if (owner != null) {
      final clear = clearLocalData;
      if (clear == null) {
        throw StateError('This device holds the data of another account');
      }
      final incoming = Map.of(_pendingChanges);
      await clear();
      await resetPositions();
      // Keep snapshots for the new account that arrived before clearing
      // the previous account's local data.
      for (final entry in incoming.entries) {
        final next = _pendingChanges[entry.key];
        _pendingChanges[entry.key] = next == null
            ? entry.value
            : entry.value.followedBy(next);
      }
    }
    await _prefs.setString(ownerKey, uid);
  }

  /// Lets the next account adopt what is on the device (after the account that
  /// owned it was deleted).
  Future<void> releaseOwnership() => _prefs.remove(ownerKey);

  Map<String, String> _versionsFor(String uid, SyncTarget target) =>
      _acknowledgedVersions.putIfAbsent(target.name, () {
        final raw = _prefs.getString('sync.$uid.${target.name}.acked');
        if (raw != null) {
          return Map<String, String>.from(jsonDecode(raw) as Map);
        }
        // Upgrade: records before the old push position were acknowledged;
        // edits made after it still need to be sent.
        final pushed = _readTime('sync.$uid.${target.name}.push');
        return {
          for (final record in target.collection.readAll())
            if (pushed != null &&
                !DateTime.parse(record['updatedAt'] as String).isAfter(pushed))
              record['id'] as String: syncRecordVersion(record),
        };
      });

  DateTime? _readTime(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  void _setStatus(SyncStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _account.removeListener(_onAccountChanged);
      for (final target in _targets) {
        target.changes?.removeListener(_onLocalChange);
      }
    }
    _stopWatching();
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
