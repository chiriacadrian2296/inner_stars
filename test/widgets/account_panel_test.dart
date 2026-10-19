import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/auth/auth_scope.dart';
import 'package:inner_stars/auth/auth_service.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/sync/remote_store.dart';
import 'package:inner_stars/sync/sync_scope.dart';
import 'package:inner_stars/sync/sync_service.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/account_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends AuthService {
  _FakeAuth({this.ready = true, this.signedInEmail, this.failSignIn = false});

  final bool ready;
  final bool failSignIn;
  String? signedInEmail;
  Object? error;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isSignedIn => signedInEmail != null;
  @override
  String? get email => signedInEmail;
  @override
  String? get uid => signedInEmail == null ? null : 'uid-1';
  @override
  String? get displayName => signedInEmail == null ? null : 'Ada Lovelace';
  @override
  String? get photoUrl => null;
  @override
  Object? get lastError => error;
  @override
  Future<bool> ensureReady() async => ready;

  @override
  Future<void> signInWithGoogle() async {
    signInCalls++;
    if (failSignIn) {
      error = StateError('nope');
      notifyListeners();
      throw error!;
    }
    signedInEmail = 'ada@example.com';
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedInEmail = null;
    notifyListeners();
  }
}

Widget _host(Widget child, {AuthService? auth}) {
  Widget body = Scaffold(body: SingleChildScrollView(child: child));
  if (auth != null) body = AuthScope(service: auth, child: body);
  return StringsScope(
    strings: StringsEn(),
    child: MaterialApp(theme: buildAppTheme(), home: body),
  );
}

void main() {
  testWidgets('renders nothing without an auth scope', (tester) async {
    await tester.pumpWidget(_host(const AccountPanel()));
    expect(find.byKey(const ValueKey('account-panel')), findsNothing);
  });

  testWidgets('signed out: explains local data and offers sign-in', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const AccountPanel(), auth: auth));
    await tester.pumpAndSettle();
    expect(find.textContaining('stays on this device'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sign-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sign-out')), findsNothing);
  });

  testWidgets('signing in shows the account and a way out', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const AccountPanel(), auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sign-in')));
    await tester.pumpAndSettle();
    expect(auth.signInCalls, 1);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sign-out')), findsOneWidget);
    expect(find.textContaining('keeps your data on this device'), findsOne);
  });

  testWidgets('signing out returns to the sign-in state', (tester) async {
    final auth = _FakeAuth(signedInEmail: 'ada@example.com');
    await tester.pumpWidget(_host(const AccountPanel(), auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(find.byKey(const ValueKey('account-sign-in')), findsOneWidget);
  });

  testWidgets('a failed sign-in shows a message and stays signed out', (
    tester,
  ) async {
    final auth = _FakeAuth(failSignIn: true);
    await tester.pumpWidget(_host(const AccountPanel(), auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sign-in')), findsOneWidget);
  });

  testWidgets('when sign-in is unavailable the app says so, without a button', (
    tester,
  ) async {
    final auth = _FakeAuth(ready: false);
    await tester.pumpWidget(_host(const AccountPanel(), auth: auth));
    await tester.pumpAndSettle();
    expect(find.textContaining('not available right now'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sign-in')), findsNothing);
  });

  testWidgets('signed in: reports the last update, with no sync button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = _FakeAuth(signedInEmail: 'ada@example.com');
    final sync = SyncService(
      account: auth,
      prefs: prefs,
      targets: const [],
      remote: (_) => InMemoryRemoteStore(),
      now: () => DateTime.utc(2026, 10, 19, 12, 30),
    );
    addTearDown(sync.dispose);
    await tester.pumpWidget(
      _host(
        SyncScope(service: sync, child: const AccountPanel()),
        auth: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not updated yet'), findsOneWidget);

    await tester.runAsync(sync.syncNow);
    await tester.pumpAndSettle();
    expect(find.textContaining('Last updated:'), findsOneWidget);
    // Syncing is automatic: there is nothing to press.
    expect(
      find.textContaining(RegExp('sync now', caseSensitive: false)),
      findsNothing,
    );
  });
}
