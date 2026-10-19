import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/sync/settings_collection.dart';

Map<String, dynamic> remote(String id, Object value, String updatedAt) => {
  'id': id,
  'value': value,
  'updatedAt': updatedAt,
  'deleted': false,
};

void main() {
  late SharedPreferences prefs;
  late SettingsRepository settings;
  late SettingsCollection sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = SettingsRepository(prefs);
    sync = SettingsCollection(prefs);
  });

  test('exports changed settings but never per-device ones', () async {
    await settings.setLocale('it');
    await settings.setShowGrid(true);
    await settings.setGalaxyQuality(settings.galaxyQuality);
    await prefs.setDouble('audio-tap-volume', 0.3);
    await prefs.setString('audio-background-track', 'x');
    final ids = (await sync.exportChangesSince(null))
        .map((r) => r['id'])
        .toSet();
    expect(ids, {
      'settings.locale',
      'settings.showGrid',
      'audio-background-track',
    });
  });

  test(
    'an unchanged value keeps its clock, a change moves it forward',
    () async {
      await settings.setLocale('it');
      final first = (await sync.exportChangesSince(null)).single;
      final again = (await sync.exportChangesSince(null)).single;
      expect(again['updatedAt'], first['updatedAt']);
      await settings.setLocale('ro');
      final changed = (await sync.exportChangesSince(null)).single;
      expect(changed['value'], 'ro');
      final firstTime = DateTime.parse(first['updatedAt'] as String);
      final changedTime = DateTime.parse(changed['updatedAt'] as String);
      expect(changedTime.isAfter(firstTime), isTrue);
      expect(await sync.exportChangesSince(changedTime), isEmpty);
    },
  );

  test(
    'newer remote values apply with their types, older ones do not',
    () async {
      await settings.setLocale('it');
      await settings.setShowGrid(false);
      await settings.setGalaxyCinematicGravity(0.5);
      final local = await sync.exportChangesSince(null);
      DateTime t(String id) => DateTime.parse(
        local.firstWhere((r) => r['id'] == id)['updatedAt'] as String,
      );
      String later(String id) =>
          t(id).add(const Duration(minutes: 1)).toIso8601String();
      String earlier(String id) =>
          t(id).subtract(const Duration(minutes: 1)).toIso8601String();

      final changed = await sync.applyRemote([
        remote('settings.locale', 'ro', earlier('settings.locale')),
        remote('settings.showGrid', true, later('settings.showGrid')),
        remote(
          'settings.galaxyCinematicGravity',
          1,
          later('settings.galaxyCinematicGravity'),
        ),
        remote(
          'settings.galaxyQuality',
          'low',
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        ),
      ]);
      expect(changed, 2);
      expect(settings.locale, 'it');
      expect(settings.showGrid, isTrue);
      expect(prefs.getDouble('settings.galaxyCinematicGravity'), 1.0);
      expect(prefs.containsKey('settings.galaxyQuality'), isFalse);
      // What was just applied is not exported back as a new local change.
      final exported = await sync.exportChangesSince(null);
      expect(
        exported.firstWhere((r) => r['id'] == 'settings.showGrid')['updatedAt'],
        later('settings.showGrid'),
      );
    },
  );

  test(
    'clearSynced removes synced settings and their bookkeeping only',
    () async {
      await settings.setLocale('it');
      await prefs.setDouble('audio-tap-volume', 0.4);
      await settings.setGalaxyQuality(settings.galaxyQuality);
      await sync.exportChangesSince(null);
      expect(prefs.containsKey(SettingsCollection.metaKey), isTrue);

      await sync.clearSynced();
      expect(prefs.containsKey('settings.locale'), isFalse);
      expect(prefs.containsKey(SettingsCollection.metaKey), isFalse);
      // Per-device settings stay.
      expect(prefs.getDouble('audio-tap-volume'), 0.4);
      expect(prefs.containsKey('settings.galaxyQuality'), isTrue);
    },
  );

  test('a fresh device takes a setting the cloud already has', () async {
    final changed = await sync.applyRemote([
      remote('settings.locale', 'ro', DateTime.utc(2026).toIso8601String()),
    ]);
    expect(changed, 1);
    expect(settings.locale, 'ro');
  });
}
