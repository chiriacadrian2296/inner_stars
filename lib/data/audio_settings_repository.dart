import 'package:shared_preferences/shared_preferences.dart';

import '../models/background_track.dart';
import '../models/sky_sound_effect.dart';
import '../models/sky_whoosh_effect.dart';

/// Reads and writes the user's audio choices — which background track
/// plays (and whether it's paused), which sound plays for a tap and for a
/// hold in the Sky, which whoosh plays for flying closer/farther, and a
/// volume per category. See `AudioService`, which reads this at startup
/// and whenever the user changes something in the Sound Lab.
class AudioSettingsRepository {
  AudioSettingsRepository(this._prefs);

  static const _trackKey = 'audio-background-track';
  static const _pausedKey = 'audio-background-paused';
  static const _tapSoundKey = 'audio-tap-sound';
  static const _holdSoundKey = 'audio-hold-sound';
  static const _whooshInSoundKey = 'audio-whoosh-in-sound';
  static const _whooshOutSoundKey = 'audio-whoosh-out-sound';
  static const _backgroundVolumeKey = 'audio-background-volume';
  static const _tapVolumeKey = 'audio-tap-volume';
  static const _holdVolumeKey = 'audio-hold-volume';
  static const _whooshVolumeKey = 'audio-whoosh-volume';

  static const _defaultTrack = BackgroundTrack.observingTheStar;
  static const _defaultTapSound = SkySoundEffect.glassBell;
  static const _defaultHoldSound = SkySoundEffect.chimeWarm;
  // Match the two whoosh files chosen and bisected against on the sky's
  // own zoom (see `AudioService`'s earlier fixed constants) — kept as the
  // defaults now that both are user-selectable, so nobody's first
  // impression of the feature changes just because it became configurable.
  static const _defaultWhooshInSound = SkyWhooshEffect.whooshA;
  static const _defaultWhooshOutSound = SkyWhooshEffect.whooshB;
  static const _defaultBackgroundVolume = 0.7;
  static const _defaultTapVolume = 0.3;
  static const _defaultHoldVolume = 0.3;
  static const _defaultWhooshVolume = 0.5;

  final SharedPreferences _prefs;

  static Future<AudioSettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AudioSettingsRepository(prefs);
  }

  BackgroundTrack get backgroundTrack {
    final name = _prefs.getString(_trackKey);
    for (final track in BackgroundTrack.values) {
      if (track.name == name) return track;
    }
    return _defaultTrack;
  }

  Future<void> setBackgroundTrack(BackgroundTrack track) {
    return _prefs.setString(_trackKey, track.name);
  }

  /// False (playing) by default — the ambient loop is meant to just be
  /// there unless the user turns it off themselves.
  bool get backgroundPaused => _prefs.getBool(_pausedKey) ?? false;

  Future<void> setBackgroundPaused(bool paused) {
    return _prefs.setBool(_pausedKey, paused);
  }

  SkySoundEffect get tapSound {
    final name = _prefs.getString(_tapSoundKey);
    for (final sound in SkySoundEffect.values) {
      if (sound.name == name) return sound;
    }
    return _defaultTapSound;
  }

  Future<void> setTapSound(SkySoundEffect sound) {
    return _prefs.setString(_tapSoundKey, sound.name);
  }

  SkySoundEffect get holdSound {
    final name = _prefs.getString(_holdSoundKey);
    for (final sound in SkySoundEffect.values) {
      if (sound.name == name) return sound;
    }
    return _defaultHoldSound;
  }

  Future<void> setHoldSound(SkySoundEffect sound) {
    return _prefs.setString(_holdSoundKey, sound.name);
  }

  SkyWhooshEffect get whooshInSound {
    final name = _prefs.getString(_whooshInSoundKey);
    for (final sound in SkyWhooshEffect.values) {
      if (sound.name == name) return sound;
    }
    return _defaultWhooshInSound;
  }

  Future<void> setWhooshInSound(SkyWhooshEffect sound) {
    return _prefs.setString(_whooshInSoundKey, sound.name);
  }

  SkyWhooshEffect get whooshOutSound {
    final name = _prefs.getString(_whooshOutSoundKey);
    for (final sound in SkyWhooshEffect.values) {
      if (sound.name == name) return sound;
    }
    return _defaultWhooshOutSound;
  }

  Future<void> setWhooshOutSound(SkyWhooshEffect sound) {
    return _prefs.setString(_whooshOutSoundKey, sound.name);
  }

  /// 0.0-1.0, each independent — the Settings sound section's own
  /// leveling panel.
  double get backgroundVolume =>
      _prefs.getDouble(_backgroundVolumeKey) ?? _defaultBackgroundVolume;

  Future<void> setBackgroundVolume(double volume) {
    return _prefs.setDouble(_backgroundVolumeKey, volume);
  }

  double get tapVolume => _prefs.getDouble(_tapVolumeKey) ?? _defaultTapVolume;

  Future<void> setTapVolume(double volume) {
    return _prefs.setDouble(_tapVolumeKey, volume);
  }

  double get holdVolume =>
      _prefs.getDouble(_holdVolumeKey) ?? _defaultHoldVolume;

  Future<void> setHoldVolume(double volume) {
    return _prefs.setDouble(_holdVolumeKey, volume);
  }

  double get whooshVolume =>
      _prefs.getDouble(_whooshVolumeKey) ?? _defaultWhooshVolume;

  Future<void> setWhooshVolume(double volume) {
    return _prefs.setDouble(_whooshVolumeKey, volume);
  }

  /// Used by the "reset all data" action — there's no undo.
  Future<void> clear() async {
    await _prefs.remove(_trackKey);
    await _prefs.remove(_pausedKey);
    await _prefs.remove(_tapSoundKey);
    await _prefs.remove(_holdSoundKey);
    await _prefs.remove(_whooshInSoundKey);
    await _prefs.remove(_whooshOutSoundKey);
    await _prefs.remove(_backgroundVolumeKey);
    await _prefs.remove(_tapVolumeKey);
    await _prefs.remove(_holdVolumeKey);
    await _prefs.remove(_whooshVolumeKey);
  }
}
