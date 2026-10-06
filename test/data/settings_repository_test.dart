import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/settings_repository.dart';
import 'package:inner_stars/models/artwork_blend.dart';
import 'package:inner_stars/models/artwork_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Cosmo visual controls use the configured defaults', () async {
    final repository = await SettingsRepository.create();

    expect(repository.showSupernovae, isTrue);
    expect(repository.supernovaScale, 0.9);
    expect(repository.supernovaIntensity, 0.8);
    expect(repository.artworkOpacity, 0.1);
    expect(repository.artworkScale, 1.0);
    expect(repository.artworkColor, 0xFFFFFFFF);
    expect(repository.artworkLayer, ArtworkLayer.aboveStars);
    expect(repository.artworkBlend, ArtworkBlend.plus);
  });

  test('legacy preview gold migrates once to the canonical app gold', () async {
    SharedPreferences.setMockInitialValues({
      'settings.artworkColor': 0xFFFFCC00,
    });
    final repository = await SettingsRepository.create();

    expect(repository.artworkColor, 0xFFF2B84B);
    final reloaded = await SettingsRepository.create();
    expect(reloaded.artworkColor, 0xFFF2B84B);
  });

  test('resetCosmoVisuals persists every configured default', () async {
    SharedPreferences.setMockInitialValues({
      'settings.showSupernovae': false,
      'settings.supernovaScale': 2.0,
      'settings.supernovaIntensity': 1.5,
      'settings.artworkOpacity': 0.8,
      'settings.artworkScale': 1.7,
      'settings.artworkColor': 0xFF00FF00,
      'settings.artworkLayer': ArtworkLayer.behindSky.name,
      'settings.artworkBlend': ArtworkBlend.overlay.name,
    });
    final repository = await SettingsRepository.create();

    await repository.resetCosmoVisuals();
    final reloaded = await SettingsRepository.create();

    expect(reloaded.showSupernovae, isTrue);
    expect(reloaded.supernovaScale, 0.9);
    expect(reloaded.supernovaIntensity, 0.8);
    expect(reloaded.artworkOpacity, 0.1);
    expect(reloaded.artworkScale, 1.0);
    expect(reloaded.artworkColor, 0xFFFFFFFF);
    expect(reloaded.artworkLayer, ArtworkLayer.aboveStars);
    expect(reloaded.artworkBlend, ArtworkBlend.plus);
  });
}
