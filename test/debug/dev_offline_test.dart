import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/auth/auth_gate.dart';
import 'package:inner_stars/auth/auth_service.dart';
import 'package:inner_stars/debug/dev_offline.dart';
import 'package:inner_stars/sync/settings_collection.dart';
import 'package:inner_stars/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account extends ChangeNotifier implements SyncAccount {
  @override
  String? uid = 'user-1';
  void signOut() {
    uid = null;
    notifyListeners();
  }
}

class _Auth extends AuthService {
  @override
  bool get isResolved => true;
  @override
  bool get isSignedIn => false;
}

void main() {
  Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('a development build starts offline and remembers the choice', () async {
    final p = await prefs();
    final offline = DevOffline.load(p);
    expect(offline.enabled, isTrue);

    var notified = 0;
    offline.addListener(() => notified++);
    await offline.setEnabled(false);
    expect(offline.enabled, isFalse);
    expect(notified, 1);
    expect(DevOffline.load(p).enabled, isFalse);

    await offline.setEnabled(false);
    expect(notified, 1);
  });

  test('the offline flag is never synced between devices', () {
    expect(SettingsCollection.isSynced(DevOffline.prefsKey), isFalse);
  });

  test('the sync sees nobody while offline and the account after', () async {
    final offline = DevOffline.load(await prefs());
    final account = _Account();
    final gated = OfflineGatedAccount(account: account, offline: offline);
    var notified = 0;
    gated.addListener(() => notified++);

    expect(gated.uid, isNull);
    await offline.setEnabled(false);
    expect(gated.uid, 'user-1');
    expect(notified, 1);

    account.signOut();
    expect(gated.uid, isNull);
    expect(notified, 2);
  });

  testWidgets('the gate opens the app without an account while offline', (
    tester,
  ) async {
    final offline = DevOffline.load(await prefs());
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: _Auth(),
          wasSignedIn: false,
          offline: offline,
          login: const Text('login'),
          childBuilder: (_) => const Text('app'),
        ),
      ),
    );
    expect(find.text('app'), findsOneWidget);

    await offline.setEnabled(false);
    await tester.pump();
    expect(find.text('login'), findsOneWidget);
  });
}
