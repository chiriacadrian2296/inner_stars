import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/audio_settings_repository.dart';
import 'package:inner_stars/models/background_track.dart';
import 'package:inner_stars/models/sky_sound_effect.dart';
import 'package:inner_stars/models/sky_whoosh_effect.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to Observing the Star, playing, glass bell/warm ding', () async {
    final repo = await AudioSettingsRepository.create();

    expect(repo.backgroundTrack, BackgroundTrack.observingTheStar);
    expect(repo.backgroundPaused, isFalse);
    expect(repo.tapSound, SkySoundEffect.glassBell);
    expect(repo.holdSound, SkySoundEffect.chimeWarm);
    expect(repo.whooshInSound, SkyWhooshEffect.whooshA);
    expect(repo.whooshOutSound, SkyWhooshEffect.whooshB);
  });

  test('every volume defaults to its own preset level', () async {
    final repo = await AudioSettingsRepository.create();

    expect(repo.backgroundVolume, 0.7);
    expect(repo.tapVolume, 0.3);
    expect(repo.holdVolume, 0.3);
    expect(repo.whooshVolume, 0.5);
  });

  test('each volume setter persists independently', () async {
    final repo = await AudioSettingsRepository.create();

    await repo.setBackgroundVolume(0.4);
    await repo.setTapVolume(0.6);
    await repo.setHoldVolume(0.8);
    await repo.setWhooshVolume(0.2);

    expect(repo.backgroundVolume, 0.4);
    expect(repo.tapVolume, 0.6);
    expect(repo.holdVolume, 0.8);
    expect(repo.whooshVolume, 0.2);
  });

  test('setBackgroundTrack() persists and getter reads it back', () async {
    final repo = await AudioSettingsRepository.create();

    await repo.setBackgroundTrack(BackgroundTrack.outThere);

    expect(repo.backgroundTrack, BackgroundTrack.outThere);
  });

  test('setBackgroundPaused() persists and getter reads it back', () async {
    final repo = await AudioSettingsRepository.create();

    await repo.setBackgroundPaused(true);

    expect(repo.backgroundPaused, isTrue);
  });

  test('setTapSound()/setHoldSound() persist independently', () async {
    final repo = await AudioSettingsRepository.create();

    await repo.setTapSound(SkySoundEffect.bong);
    await repo.setHoldSound(SkySoundEffect.select);

    expect(repo.tapSound, SkySoundEffect.bong);
    expect(repo.holdSound, SkySoundEffect.select);
  });

  test('setWhooshInSound()/setWhooshOutSound() persist independently', () async {
    final repo = await AudioSettingsRepository.create();

    await repo.setWhooshInSound(SkyWhooshEffect.whooshE);
    await repo.setWhooshOutSound(SkyWhooshEffect.whooshF);

    expect(repo.whooshInSound, SkyWhooshEffect.whooshE);
    expect(repo.whooshOutSound, SkyWhooshEffect.whooshF);
  });

  test('clear() resets every setting back to its default', () async {
    final repo = await AudioSettingsRepository.create();
    await repo.setBackgroundTrack(BackgroundTrack.heavenlyLoop);
    await repo.setBackgroundPaused(true);
    await repo.setTapSound(SkySoundEffect.confirmation);
    await repo.setHoldSound(SkySoundEffect.pluckBright);
    await repo.setWhooshInSound(SkyWhooshEffect.whooshC);
    await repo.setWhooshOutSound(SkyWhooshEffect.whooshD);
    await repo.setBackgroundVolume(0.3);
    await repo.setTapVolume(0.3);
    await repo.setHoldVolume(0.3);
    await repo.setWhooshVolume(0.3);

    await repo.clear();

    expect(repo.backgroundTrack, BackgroundTrack.observingTheStar);
    expect(repo.backgroundPaused, isFalse);
    expect(repo.tapSound, SkySoundEffect.glassBell);
    expect(repo.holdSound, SkySoundEffect.chimeWarm);
    expect(repo.whooshInSound, SkyWhooshEffect.whooshA);
    expect(repo.whooshOutSound, SkyWhooshEffect.whooshB);
    expect(repo.backgroundVolume, 0.7);
    expect(repo.tapVolume, 0.3);
    expect(repo.holdVolume, 0.3);
    expect(repo.whooshVolume, 0.5);
  });

  test(
    'a setting persists across repository instances (same storage)',
    () async {
      final first = await AudioSettingsRepository.create();
      await first.setBackgroundTrack(BackgroundTrack.outThere);

      final second = await AudioSettingsRepository.create();

      expect(second.backgroundTrack, BackgroundTrack.outThere);
    },
  );
}
