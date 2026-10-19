import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/app_lock_repository.dart';
import 'package:inner_stars/data/biometric_auth_service.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/screens/app_lock_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/app_lock_gate.dart';
import 'package:inner_stars/widgets/startup_splash.dart';

void main() {
  testWidgets(
    'locked startup reveals the lock before mounting private content',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = await AppLockRepository.create();
      await repository.setPin('1234');
      final biometrics = BiometricAuthService();
      var unlocked = 0;
      var dismissed = 0;
      var privateBuilds = 0;
      Widget build(bool ready) => StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: StartupSplash(
            ready: ready,
            loadingLabel: 'Caricamento',
            tagline: 'Ogni sforzo è una stella.',
            onDismissed: () => dismissed++,
            child: AppLockGate(
              appLockRepository: repository,
              biometricAuthService: biometrics,
              onLaunchUnlocked: () => unlocked++,
              child: Builder(
                builder: (_) {
                  privateBuilds++;
                  return const Text('Private Galaxy');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(false));
      expect(privateBuilds, 0);
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(privateBuilds, 0);
      expect(find.byType(AppLockScreen), findsOneWidget);
      // Exercise the gate's successful-authentication boundary independently
      // of the OS biometric prompt and the keypad's own tests.
      tester.widget<AppLockScreen>(find.byType(AppLockScreen)).onUnlocked();
      await tester.pumpAndSettle();
      expect(unlocked, 1);
      expect(find.text('Private Galaxy'), findsOneWidget);
      expect(find.byKey(const ValueKey('startup-splash')), findsNothing);
      expect(dismissed, 1);
    },
  );
}
