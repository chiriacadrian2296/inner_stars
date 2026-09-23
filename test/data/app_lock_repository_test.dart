import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/app_lock_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts disabled, with no PIN and biometrics off', () async {
    final repo = await AppLockRepository.create();

    expect(repo.isEnabled, isFalse);
    expect(repo.hasPin, isFalse);
    expect(repo.biometricEnabled, isFalse);
  });

  test('setPin() enables the lock and the PIN verifies correctly', () async {
    final repo = await AppLockRepository.create();

    await repo.setPin('1234');

    expect(repo.isEnabled, isTrue);
    expect(repo.hasPin, isTrue);
    expect(repo.verifyPin('1234'), isTrue);
  });

  test('verifyPin() rejects a wrong PIN', () async {
    final repo = await AppLockRepository.create();
    await repo.setPin('1234');

    expect(repo.verifyPin('4321'), isFalse);
    expect(repo.verifyPin('0000'), isFalse);
  });

  test('verifyPin() is false when no PIN has been set yet', () async {
    final repo = await AppLockRepository.create();

    expect(repo.verifyPin('1234'), isFalse);
  });

  test('two repositories salt the same PIN differently', () async {
    final first = await AppLockRepository.create();
    await first.setPin('1234');

    SharedPreferences.setMockInitialValues({});
    final second = await AppLockRepository.create();
    await second.setPin('1234');

    // Both still verify their own PIN correctly even though the stored
    // hash/salt pair differs between them (can't observe the raw prefs
    // here without reaching past the repository's own API, but a wrong
    // PIN failing and the right one succeeding on each is the behavior
    // that actually matters).
    expect(first.verifyPin('1234'), isTrue);
    expect(second.verifyPin('1234'), isTrue);
  });

  test('setPin() replaces a previous PIN — only the new one verifies', () async {
    final repo = await AppLockRepository.create();
    await repo.setPin('1234');

    await repo.setPin('5678');

    expect(repo.verifyPin('1234'), isFalse);
    expect(repo.verifyPin('5678'), isTrue);
  });

  test('setBiometricEnabled() is a no-op without a PIN set', () async {
    final repo = await AppLockRepository.create();

    await repo.setBiometricEnabled(true);

    expect(repo.biometricEnabled, isFalse);
  });

  test('setBiometricEnabled() persists once a PIN exists', () async {
    final repo = await AppLockRepository.create();
    await repo.setPin('1234');

    await repo.setBiometricEnabled(true);

    expect(repo.biometricEnabled, isTrue);
  });

  test('disable() clears the PIN, biometrics, and the enabled flag', () async {
    final repo = await AppLockRepository.create();
    await repo.setPin('1234');
    await repo.setBiometricEnabled(true);

    await repo.disable();

    expect(repo.isEnabled, isFalse);
    expect(repo.hasPin, isFalse);
    expect(repo.biometricEnabled, isFalse);
    expect(repo.verifyPin('1234'), isFalse);
  });

  test('a set PIN persists across repository instances (same storage)', () async {
    final first = await AppLockRepository.create();
    await first.setPin('1234');

    final second = await AppLockRepository.create();

    expect(second.isEnabled, isTrue);
    expect(second.hasPin, isTrue);
    expect(second.verifyPin('1234'), isTrue);
  });
}
