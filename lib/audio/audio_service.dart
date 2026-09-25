import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart'
    show AudioplayersPlatformInterface;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../data/audio_settings_repository.dart';
import '../models/background_track.dart';
import '../models/sky_sound_effect.dart';
import '../models/sky_whoosh_effect.dart';

/// The Sky's own audio: one looping background track, a short sound for a
/// tap/hold on it, and a whoosh for the camera flying in or out — see
/// `AudioSettingsRepository` for what's persisted, and the Sound Lab
/// screen for the only place any of this is ever surfaced to the user.
/// Three [AudioPlayer]s, kept deliberately separate: a tap/hold or
/// zoom sound stopping and restarting the *background* player would cut
/// the loop's own position, and a zoom whoosh stopping the tap/hold
/// player (or vice versa) would cut a sound that's meant to layer with it
/// — a tap that also kicks off a fly-to-target should be heard as both a
/// click and a whoosh, not just whichever fired last.
///
/// [WidgetsBindingObserver] here (registered in [create], removed in
/// [dispose]) is what pauses the loop whenever the app stops being what
/// the user is actually looking at — backgrounded on Android (confirmed
/// live: an `AudioPlayer` otherwise keeps playing straight through that,
/// unlike a normal media app), or a plain browser tab switch on web.
/// [_pausedForBackground] tracks that this specific pause was *ours*, not
/// the user's, so coming back only resumes it if the user hadn't also
/// paused it themselves (from Settings, or from another device) while
/// away.
class AudioService with WidgetsBindingObserver {
  AudioService._(
    this._settings,
    this._backgroundPlayer,
    this._sfxPlayer,
    this._transitionPlayer,
  );

  bool _pausedForBackground = false;

  final AudioSettingsRepository _settings;
  final AudioPlayer _backgroundPlayer;
  final AudioPlayer _sfxPlayer;
  final AudioPlayer _transitionPlayer;

  // Every player defaults to requesting *exclusive* audio focus on Android
  // (`AndroidAudioFocus.gain`) — which is what was silencing the
  // background loop every time a tap/hold/zoom sound played: the SFX
  // player's own `play()` call would ask Android for sole ownership of
  // audio output, and the OS would pause the background player in
  // response, same as it would for a phone call or another app's music.
  // `mixWithOthers` (`AndroidAudioFocus.none`/iOS `mixWithOthers`) tells
  // Android/iOS this player never needs exclusive output, so nothing else
  // — including this service's own other players — ever gets paused out
  // from under it. Confirmed as Android-only in practice (the bug never
  // showed up on web, which has no such focus system at all).
  static final _mixAudioContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  static const _playerIds = ['sky-background', 'sky-sfx', 'sky-transition'];

  /// A hot restart drops the old isolate's Dart objects without disposing
  /// them, but their native players live on — and the Android plugin's
  /// `create` just overwrites its map entry for a reused id, leaving the old
  /// player orphaned and still playing (a second background loop under the
  /// new one, after every restart). Disposing by id first releases whatever
  /// the previous run left behind; on a fresh launch there's nothing there
  /// and the plugin answers with an error, which is expected and ignored.
  /// Debug-only, since a hot restart can't happen in any other mode.
  static Future<void> _disposeLeftoverPlayers() async {
    for (final id in _playerIds) {
      try {
        await AudioplayersPlatformInterface.instance.dispose(id);
      } catch (_) {}
    }
  }

  static Future<AudioService> create(AudioSettingsRepository settings) async {
    if (kDebugMode) await _disposeLeftoverPlayers();
    final backgroundPlayer = AudioPlayer(playerId: _playerIds[0]);
    final sfxPlayer = AudioPlayer(playerId: _playerIds[1]);
    final transitionPlayer = AudioPlayer(playerId: _playerIds[2]);
    await backgroundPlayer.setReleaseMode(ReleaseMode.loop);
    await Future.wait([
      backgroundPlayer.setAudioContext(_mixAudioContext),
      sfxPlayer.setAudioContext(_mixAudioContext),
      transitionPlayer.setAudioContext(_mixAudioContext),
    ]);

    final service = AudioService._(
      settings,
      backgroundPlayer,
      sfxPlayer,
      transitionPlayer,
    );
    // Loading the track never blocks startup: `setSource` waits for the
    // native player's "prepared" event, and after a hot restart that event
    // can fire before the new isolate is listening for it — so the await sat
    // out the plugin's 30-second timeout with the app stuck on its splash,
    // which is what made the first hot restart hang (the second, once the
    // players were warm, went through). See [_prepareBackground].
    unawaited(service._prepareBackground());
    WidgetsBinding.instance.addObserver(service);
    return service;
  }

  /// Loads the background track (loaded, not played, regardless of paused
  /// state, so a later [resumeBackground] has something to resume without an
  /// audible gap for decoding the file), applies its volume and, unless the
  /// user has it paused, starts the loop.
  ///
  /// Not awaited by [create] — see the note there. If the plugin gives up
  /// waiting for "prepared" (the event was lost, not the track), the player
  /// is most likely ready anyway, so it still tries to start.
  Future<void> _prepareBackground() async {
    try {
      await _backgroundPlayer.setVolume(_settings.backgroundVolume);
      await _backgroundPlayer.setSource(
        AssetSource(_settings.backgroundTrack.assetPath),
      );
    } catch (_) {
      // Fall through and try to play regardless.
    }
    if (_settings.backgroundPaused) return;
    try {
      await _backgroundPlayer.resume();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      // [AppLifecycleState.hidden] is what actually fires on the *web*
      // for a plain browser tab switch (added to the enum specifically to
      // mean "not visible", separate from mobile's own backgrounding) —
      // without handling it too, switching tabs left the loop playing
      // straight through, audible from a tab you'd already left. [paused]
      // is mobile's own equivalent (home button, app switcher). Neither
      // includes [AppLifecycleState.inactive] — that also fires for a
      // fleeting, non-backgrounding interruption (a system dialog, a
      // notification shade pulled down), where pausing and immediately
      // resuming the music would just read as a stutter.
      case AppLifecycleState.hidden:
        if (_settings.backgroundPaused) return;
        _pausedForBackground = true;
        _backgroundPlayer.pause();
      case AppLifecycleState.resumed:
        if (!_pausedForBackground) return;
        _pausedForBackground = false;
        _backgroundPlayer.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Switches the loop to [track] and starts playing it immediately —
  /// picking a track is itself the "I want to hear this" action, so it
  /// always plays even if the loop was paused before.
  Future<void> setBackgroundTrack(BackgroundTrack track) async {
    await _settings.setBackgroundTrack(track);
    await _settings.setBackgroundPaused(false);
    await _backgroundPlayer.play(AssetSource(track.assetPath));
  }

  Future<void> pauseBackground() async {
    await _settings.setBackgroundPaused(true);
    await _backgroundPlayer.pause();
  }

  Future<void> resumeBackground() async {
    await _settings.setBackgroundPaused(false);
    await _backgroundPlayer.resume();
  }

  BackgroundTrack get backgroundTrack => _settings.backgroundTrack;
  bool get backgroundPaused => _settings.backgroundPaused;

  /// 0.0-1.0. Applied to the player immediately, not just persisted — the
  /// loop is already playing, so this is meant to be heard changing live
  /// as the Settings slider moves.
  double get backgroundVolume => _settings.backgroundVolume;

  Future<void> setBackgroundVolume(double volume) async {
    await _settings.setBackgroundVolume(volume);
    await _backgroundPlayer.setVolume(volume);
  }

  double get tapVolume => _settings.tapVolume;
  Future<void> setTapVolume(double volume) => _settings.setTapVolume(volume);

  double get holdVolume => _settings.holdVolume;
  Future<void> setHoldVolume(double volume) =>
      _settings.setHoldVolume(volume);

  double get whooshVolume => _settings.whooshVolume;
  Future<void> setWhooshVolume(double volume) =>
      _settings.setWhooshVolume(volume);

  Future<void> setTapSound(SkySoundEffect sound) {
    return _settings.setTapSound(sound);
  }

  Future<void> setHoldSound(SkySoundEffect sound) {
    return _settings.setHoldSound(sound);
  }

  SkySoundEffect get tapSound => _settings.tapSound;
  SkySoundEffect get holdSound => _settings.holdSound;

  Future<void> setWhooshInSound(SkyWhooshEffect sound) {
    return _settings.setWhooshInSound(sound);
  }

  Future<void> setWhooshOutSound(SkyWhooshEffect sound) {
    return _settings.setWhooshOutSound(sound);
  }

  SkyWhooshEffect get whooshInSound => _settings.whooshInSound;
  SkyWhooshEffect get whooshOutSound => _settings.whooshOutSound;

  /// Fired alongside the sky's own tap haptic (see `sky_screen.dart`'s
  /// `_tapHaptic`) — same moment, one more sense.
  Future<void> playTapSound() => _playSfx(tapSound, tapVolume);

  /// Fired alongside the sky's own hold haptic (see `sky_screen.dart`'s
  /// `_startHoldHaptic`).
  Future<void> playHoldSound() => _playSfx(holdSound, holdVolume);

  /// Plays [sound] at the current tap volume — used by Settings' sound
  /// section so picking a *tap* sound there previews it immediately,
  /// without needing to go back to the Sky and tap something.
  Future<void> previewTapSound(SkySoundEffect sound) =>
      _playSfx(sound, tapVolume);

  /// The same, previewed at the current *hold* volume instead.
  Future<void> previewHoldSound(SkySoundEffect sound) =>
      _playSfx(sound, holdVolume);

  Future<void> _playSfx(SkySoundEffect sound, double volume) async {
    // Restarts from the top on every call rather than layering overlapping
    // instances — these are short, one-shot UI sounds, not something a
    // rapid string of taps needs to hear all of individually.
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource(sound.assetPath), volume: volume);
  }

  /// Fired whenever the sky's camera flies to a *closer* view — see
  /// `sky_screen.dart`'s `_flyToWorld`/`_zoomTo`, which compare the
  /// destination zoom against the current one to decide which of these
  /// two to call.
  Future<void> playZoomInSound() =>
      _playTransition(whooshInSound.assetPath);

  /// The same, for a fly that lands on a *farther* view.
  Future<void> playZoomOutSound() =>
      _playTransition(whooshOutSound.assetPath);

  /// Previews [sound] on demand — used by the Sound Lab so picking a
  /// zoom-in/zoom-out whoosh there previews it immediately.
  Future<void> previewWhooshSound(SkyWhooshEffect sound) =>
      _playTransition(sound.assetPath);

  Future<void> _playTransition(String assetPath) async {
    await _transitionPlayer.stop();
    await _transitionPlayer.play(
      AssetSource(assetPath),
      volume: whooshVolume,
    );
  }

  /// Clears every stored choice (see `AudioSettingsRepository.clear`) and
  /// re-applies the resulting default track/volume to the already-playing
  /// background player — everything else (tap/hold/whoosh sound and
  /// volume) is read fresh from the repository on each play, so those
  /// need no live update of their own. Used by the Sound Lab's own reset
  /// button; same "no undo" nature as `clear` itself, just scoped to
  /// sound instead of the whole app.
  Future<void> resetToDefaults() async {
    await _settings.clear();
    await _backgroundPlayer.setVolume(_settings.backgroundVolume);
    await _backgroundPlayer.play(AssetSource(_settings.backgroundTrack.assetPath));
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _backgroundPlayer.dispose();
    await _sfxPlayer.dispose();
    await _transitionPlayer.dispose();
  }
}
