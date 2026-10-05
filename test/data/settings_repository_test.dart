import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('artwork color defaults to the canonical app gold', () async {
    final repository = await SettingsRepository.create();

    expect(repository.artworkColor, 0xFFF2B84B);
  });

  test(
    'supernova visual controls default to the original appearance',
    () async {
      final repository = await SettingsRepository.create();

      expect(repository.supernovaScale, 1.0);
      expect(repository.supernovaIntensity, 1.0);
    },
  );

  test('legacy preview gold migrates once to the canonical app gold', () async {
    SharedPreferences.setMockInitialValues({
      'settings.artworkColor': 0xFFFFCC00,
    });
    final repository = await SettingsRepository.create();

    expect(repository.artworkColor, 0xFFF2B84B);
    final reloaded = await SettingsRepository.create();
    expect(reloaded.artworkColor, 0xFFF2B84B);
  });
}
