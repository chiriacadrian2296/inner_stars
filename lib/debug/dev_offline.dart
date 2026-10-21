import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/sync_service.dart';
import 'dev_tools.dart';

/// Lets a development build run with no account and no cloud traffic, so
/// sample data can be created and wiped freely without spending Firestore
/// quota.
///
/// On by default whenever [kDevTools] is, and switchable from Settings; a
/// public build never has it (it is always off there). The flag lives under a
/// key outside `settings.*` / `audio-*`, so it stays per device and is never
/// synced.
class DevOffline extends ChangeNotifier implements ValueListenable<bool> {
  DevOffline._(this._prefs, this._enabled);

  static const prefsKey = 'dev.offline';

  final SharedPreferences _prefs;
  bool _enabled;

  static DevOffline load(SharedPreferences prefs) =>
      DevOffline._(prefs, kDevTools && (prefs.getBool(prefsKey) ?? true));

  /// True while the app skips login and sync.
  bool get enabled => _enabled;

  @override
  bool get value => _enabled;

  Future<void> setEnabled(bool enabled) async {
    enabled = enabled && kDevTools;
    if (enabled == _enabled) return;
    _enabled = enabled;
    notifyListeners();
    await _prefs.setBool(prefsKey, enabled);
  }
}

/// Hands [DevOffline] to Settings without threading it through the Galaxy.
class DevOfflineScope extends InheritedNotifier<DevOffline> {
  const DevOfflineScope({
    super.key,
    required DevOffline offline,
    required super.child,
  }) : super(notifier: offline);

  /// Null when no scope is above [context] (public build, widget tests).
  static DevOffline? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevOfflineScope>()?.notifier;
}

/// The signed-in account as the sync sees it: nobody while [offline] is on, so
/// the sync stops listening and writing, and picks up again when it goes off.
class OfflineGatedAccount extends ChangeNotifier implements SyncAccount {
  OfflineGatedAccount({required this.account, required this.offline}) {
    account.addListener(notifyListeners);
    offline.addListener(notifyListeners);
  }

  final SyncAccount account;
  final DevOffline offline;

  @override
  String? get uid => offline.enabled ? null : account.uid;

  @override
  void dispose() {
    account.removeListener(notifyListeners);
    offline.removeListener(notifyListeners);
    super.dispose();
  }
}
