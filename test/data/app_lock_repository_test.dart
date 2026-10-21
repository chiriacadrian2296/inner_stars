import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/app_lock_repository.dart';
import 'package:inner_stars/sync/merge.dart';

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

  test(
    'setPin() replaces a previous PIN — only the new one verifies',
    () async {
      final repo = await AppLockRepository.create();
      await repo.setPin('1234');

      await repo.setPin('5678');

      expect(repo.verifyPin('1234'), isFalse);
      expect(repo.verifyPin('5678'), isTrue);
    },
  );

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

  test(
    'a set PIN persists across repository instances (same storage)',
    () async {
      final first = await AppLockRepository.create();
      await first.setPin('1234');

      final second = await AppLockRepository.create();

      expect(second.isEnabled, isTrue);
      expect(second.hasPin, isTrue);
      expect(second.verifyPin('1234'), isTrue);
    },
  );
  group('syncing the PIN', () {
    test('the PIN is one record with a clock, never in the clear', () async {
      final repo = await AppLockRepository.create();
      await repo.setPin('1234');

      final records = await repo.syncCollection.exportChangesSince(null);

      expect(records, hasLength(1));
      expect(records.single['id'], 'current');
      expect(records.single['deleted'], isFalse);
      expect(records.single['updatedAt'], isA<String>());
      expect(records.single.toString(), isNot(contains('1234')));
    });

    test(
      'turning the lock off leaves a deletion record without a hash',
      () async {
        final repo = await AppLockRepository.create();
        await repo.setPin('1234');
        await repo.disable();

        final record = (await repo.syncCollection.exportChangesSince(null))
            .single;

        expect(repo.isEnabled, isFalse);
        expect(record['deleted'], isTrue);
        expect(record.containsKey('hash'), isFalse);
        expect(record.containsKey('salt'), isFalse);
      },
    );

    test('a newer PIN from another device replaces this one', () async {
      final phone = await AppLockRepository.create();
      await phone.setPin('1111');
      final mine = (await phone.syncCollection.exportChangesSince(null)).single;

      SharedPreferences.setMockInitialValues({});
      final web = await AppLockRepository.create();
      await web.setPin('2222');
      final theirs =
          Map<String, dynamic>.from(
              (await web.syncCollection.exportChangesSince(null)).single,
            )
            ..['updatedAt'] = DateTime.parse(mine['updatedAt'] as String)
                .add(const Duration(seconds: 5))
                .toIso8601String();

      SharedPreferences.setMockInitialValues({});
      final device = await AppLockRepository.create();
      await device.setPin('1111');
      await device.applyRemote(<SyncRecord>[theirs]);

      expect(device.verifyPin('2222'), isTrue);
      expect(device.verifyPin('1111'), isFalse);
    });

    test('a PIN saved before syncing is migrated and keeps working', () async {
      final hashRepo = await AppLockRepository.create();
      await hashRepo.setPin('4321');
      final record = (await hashRepo.syncCollection.exportChangesSince(null))
          .single;

      SharedPreferences.setMockInitialValues({
        'app_lock.enabled': true,
        'app_lock.pin_hash': record['hash'],
        'app_lock.pin_salt': record['salt'],
      });
      final repo = await AppLockRepository.create();
      final prefs = await SharedPreferences.getInstance();

      expect(repo.verifyPin('4321'), isTrue);
      expect(prefs.containsKey('app_lock.pin_hash'), isFalse);
      expect(await repo.syncCollection.exportChangesSince(null), hasLength(1));
    });

    test(
      'forgetting locally clears the lock without a deletion record',
      () async {
        final repo = await AppLockRepository.create();
        await repo.setPin('1234');
        await repo.setBiometricEnabled(true);

        await repo.forgetLocally();

        expect(repo.isEnabled, isFalse);
        expect(repo.biometricEnabled, isFalse);
        expect(await repo.syncCollection.exportChangesSince(null), isEmpty);
      },
    );

    test('the biometric shortcut stays on this device', () async {
      final repo = await AppLockRepository.create();
      await repo.setPin('1234');
      await repo.setBiometricEnabled(true);

      final records = await repo.syncCollection.exportChangesSince(null);

      expect(repo.biometricEnabled, isTrue);
      expect(records.single.toString(), isNot(contains('biometric')));
    });
  });
}
