import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/auth/auth_gate.dart';
import 'package:inner_stars/auth/auth_service.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/login_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

class _FakeAuth extends AuthService {
  bool resolved = false;
  bool signedIn = false;
  bool failed = false;
  Object? error;
  int signInCalls = 0;
  int retryCalls = 0;
  bool failSignIn = false;

  @override
  bool get isResolved => resolved;
  @override
  bool get isSignedIn => signedIn;
  @override
  bool get initFailed => failed;
  @override
  Object? get lastError => error;
  @override
  bool get needsGoogleButton => false;
  @override
  Future<bool> ensureReady() async => true;

  @override
  Future<bool> retry() async {
    retryCalls++;
    failed = false;
    resolved = true;
    notifyListeners();
    return true;
  }

  @override
  Future<void> signInWithGoogle() async {
    signInCalls++;
    if (failSignIn) {
      error = StateError('no');
      notifyListeners();
      throw error!;
    }
    signedIn = true;
    resolved = true;
    notifyListeners();
  }

  void set({bool? resolved, bool? signedIn, bool? failed}) {
    this.resolved = resolved ?? this.resolved;
    this.signedIn = signedIn ?? this.signedIn;
    this.failed = failed ?? this.failed;
    notifyListeners();
  }
}

Widget _app(Widget home) => StringsScope(
  strings: StringsEn(),
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

void main() {
  group('LoginScreen', () {
    Widget screen(_FakeAuth auth, {void Function(String)? onLocale}) => _app(
      LoginScreen(
        auth: auth,
        locale: 'en',
        onLocaleChanged: onLocale ?? (_) {},
      ),
    );

    testWidgets('shows the landing-style hero and a sign-in button', (
      tester,
    ) async {
      final auth = _FakeAuth()..resolved = true;
      await tester.pumpWidget(screen(auth));
      await tester.pumpAndSettle();
      expect(find.text('Even the dark'), findsOneWidget);
      expect(find.text('has its stars.'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-sign-in')), findsOneWidget);
      expect(
        find.text('Your account keeps your data safe and in sync.'),
        findsOne,
      );
    });

    testWidgets('the language chips change the language', (tester) async {
      final auth = _FakeAuth()..resolved = true;
      String? picked;
      await tester.pumpWidget(screen(auth, onLocale: (c) => picked = c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login-locale-ro')));
      expect(picked, 'ro');
    });

    testWidgets('pressing the button signs in', (tester) async {
      final auth = _FakeAuth()..resolved = true;
      await tester.pumpWidget(screen(auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login-sign-in')));
      await tester.pumpAndSettle();
      expect(auth.signInCalls, 1);
    });

    testWidgets('a failed sign-in says so and the button stays', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..resolved = true
        ..failSignIn = true;
      await tester.pumpWidget(screen(auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login-sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Could not sign in. Please try again.'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-sign-in')), findsOneWidget);
    });

    testWidgets('when sign-in cannot start it offers to try again', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..resolved = true
        ..failed = true;
      await tester.pumpWidget(screen(auth));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login-sign-in')), findsNothing);
      expect(find.textContaining('could not start'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('login-retry')));
      await tester.pumpAndSettle();
      expect(auth.retryCalls, 1);
      expect(find.byKey(const ValueKey('login-sign-in')), findsOneWidget);
    });
  });

  group('AuthGate', () {
    Widget gate(
      _FakeAuth auth, {
      bool wasSignedIn = false,
      List<String>? log,
    }) => _app(
      AuthGate(
        auth: auth,
        wasSignedIn: wasSignedIn,
        login: const Text('LOGIN'),
        childBuilder: (startLocked) => Text('APP locked=$startLocked'),
        onLoginShown: () => log?.add('login'),
        onOpened: (locked) => log?.add('open locked=$locked'),
      ),
    );

    testWidgets('shows neither page until Firebase has answered', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(gate(auth));
      expect(find.text('LOGIN'), findsNothing);
      expect(find.textContaining('APP'), findsNothing);
    });

    testWidgets('no account: the login page, and the splash is told', (
      tester,
    ) async {
      final log = <String>[];
      final auth = _FakeAuth()..resolved = true;
      await tester.pumpWidget(gate(auth, log: log));
      await tester.pump();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(log, ['login']);
    });

    testWidgets('an account already there opens the app, PIN lock applies', (
      tester,
    ) async {
      final log = <String>[];
      final auth = _FakeAuth()
        ..resolved = true
        ..signedIn = true;
      await tester.pumpWidget(gate(auth, log: log));
      await tester.pump();
      expect(find.text('APP locked=true'), findsOneWidget);
      expect(log, ['open locked=true']);
    });

    testWidgets('signing in on the login page opens the app without the PIN', (
      tester,
    ) async {
      final log = <String>[];
      final auth = _FakeAuth()..resolved = true;
      await tester.pumpWidget(gate(auth, log: log));
      await tester.pump();
      auth.set(signedIn: true);
      await tester.pump();
      await tester.pump();
      expect(find.text('APP locked=false'), findsOneWidget);
      expect(log, ['login', 'open locked=false']);
    });

    testWidgets('signing out shows the login page and closes pages on top', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..resolved = true
        ..signedIn = true;
      await tester.pumpWidget(
        _app(
          AuthGate(
            auth: auth,
            wasSignedIn: true,
            login: const Text('LOGIN'),
            childBuilder: (_) => Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('SETTINGS')),
                  ),
                ),
                child: const Text('APP'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('APP'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);

      auth.set(signedIn: false);
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsNothing);
      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('Firebase cannot start: a returning account still opens', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..resolved = true
        ..failed = true;
      await tester.pumpWidget(gate(auth, wasSignedIn: true));
      await tester.pump();
      expect(find.textContaining('APP'), findsOneWidget);
    });

    testWidgets('Firebase cannot start and nobody was signed in: login', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..resolved = true
        ..failed = true;
      await tester.pumpWidget(gate(auth, wasSignedIn: false));
      await tester.pump();
      expect(find.text('LOGIN'), findsOneWidget);
    });
  });
}
