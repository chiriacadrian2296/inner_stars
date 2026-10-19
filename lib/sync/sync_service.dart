// The private fields cannot be initializing formals of named parameters.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

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
  SyncTarget.settings(SettingsCollection settings, VoidCallback onApplied)
    : name = 'settings',
      collection = _CallbackCollection(settings, onApplied),
      changes = null;

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
/// right after sign-in, a few seconds after a local change, when the app comes
/// back to the foreground or goes to the background, and every couple of
/// minutes while it is open. A failure (offline, timeout) never blocks the
/// app: it retries later, backing off, and the local data is untouched.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService({
    required SyncAccount account,
    required SharedPreferences prefs,
    required List<SyncTarget> targets,
    required RemoteStore Function(String uid) remote,
    this.debounce = const Duration(seconds: 5),
    this.interval = const Duration(minutes: 2),
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
  final Duration debounce;
  final Duration interval;
  final DateTime Function() _now;

  SyncStatus _status = SyncStatus.idle;
  Object? _lastError;
  bool _running = false;
  bool _again = false;
  bool _started = false;
  bool _paused = false;
  int _failures = 0;
  String? _lastUid;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Timer? _periodic;

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
    _periodic = Timer.periodic(interval, (_) => schedule());
    _onAccountChanged();
  }

  void _onAccountChanged() {
    final uid = _account.uid;
    if (uid == _lastUid) return;
    _lastUid = uid;
    _failures = 0;
    _retryTimer?.cancel();
    if (uid == null) {
      _debounceTimer?.cancel();
      _setStatus(SyncStatus.idle);
    } else {
      schedule(const Duration(milliseconds: 300));
    }
  }

  void _onLocalChange() {
    if (_running) return;
    schedule();
  }

  /// Asks for a sync soon; several requests inside [after] become one.
  void schedule([Duration? after]) {
    if (_account.uid == null) return;
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

  /// Runs one full sync of every collection. Concurrent calls collapse into
  /// one extra run after the current one.
  Future<void> syncNow() async {
    final uid = _account.uid;
    if (uid == null || _paused) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _retryTimer?.cancel();
    _setStatus(SyncStatus.syncing);
    try {
      final remote = _remoteFactory(uid);
      final startedAt = _now().toUtc();
      for (final target in _targets) {
        final pullKey = 'sync.$uid.${target.name}.pull';
        final pushKey = 'sync.$uid.${target.name}.push';
        final outcome = await syncCollection(
          name: target.name,
          local: target.collection,
          remote: remote,
          pullCursor: _readTime(pullKey),
          pushSince: _readTime(pushKey),
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
      await _prefs.setString(
        'sync.$uid.last-success',
        _now().toUtc().toIso8601String(),
      );
      _failures = 0;
      _lastError = null;
      _setStatus(SyncStatus.idle);
    } catch (error) {
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
        schedule(const Duration(seconds: 1));
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
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('sync.') && key != SettingsCollection.metaKey) {
        await _prefs.remove(key);
      }
    }
  }

  /// Deletes every collection of the signed-in account from the cloud. Local
  /// data stays. Call inside [pausedWhile].
  Future<void> deleteCloudData() async {
    final uid = _account.uid;
    if (uid == null) throw StateError('Not signed in');
    final remote = _remoteFactory(uid);
    for (final target in _targets) {
      await remote.deleteCollection(target.name);
    }
    await resetPositions();
  }

  DateTime? _readTime(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _account.removeListener(_onAccountChanged);
      for (final target in _targets) {
        target.changes?.removeListener(_onLocalChange);
      }
    }
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
