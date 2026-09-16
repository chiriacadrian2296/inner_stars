import '../l10n/app_strings.dart';

/// The looping ambient tracks offered for the Sky's own background audio —
/// see `AudioService`. Fixed and closed, same as [LifeArea]: adding a
/// track means shipping a new asset file, not something a user picks from
/// outside the app.
enum BackgroundTrack {
  observingTheStar,
  heavenlyLoop,
  outThere,
  ambientRelaxing,
  backgroundSpace,
  nightlight,
}

extension BackgroundTrackX on BackgroundTrack {
  /// Relative to `assets/` — matches the `assets/audio/bg/` folder
  /// declared in pubspec.yaml. See `assets/audio/CREDITS.txt` for where
  /// each file comes from (all CC0).
  String get assetPath {
    switch (this) {
      case BackgroundTrack.observingTheStar:
        return 'audio/bg/observing_the_star.ogg';
      case BackgroundTrack.heavenlyLoop:
        return 'audio/bg/heavenly_loop.ogg';
      case BackgroundTrack.outThere:
        return 'audio/bg/out_there.ogg';
      case BackgroundTrack.ambientRelaxing:
        return 'audio/bg/ambient_relaxing_loop.ogg';
      case BackgroundTrack.backgroundSpace:
        return 'audio/bg/background_space_track.ogg';
      case BackgroundTrack.nightlight:
        // TODO(nightlight-audio): no dedicated track recorded yet — reuses
        // the existing calm loop as a placeholder until one is supplied.
        return 'audio/bg/ambient_relaxing_loop.ogg';
    }
  }

  String displayName(AppStrings s) {
    switch (this) {
      case BackgroundTrack.observingTheStar:
        return s.backgroundTrackObservingTheStar;
      case BackgroundTrack.heavenlyLoop:
        return s.backgroundTrackHeavenlyLoop;
      case BackgroundTrack.outThere:
        return s.backgroundTrackOutThere;
      case BackgroundTrack.ambientRelaxing:
        return s.backgroundTrackAmbientRelaxing;
      case BackgroundTrack.backgroundSpace:
        return s.backgroundTrackBackgroundSpace;
      case BackgroundTrack.nightlight:
        return s.backgroundTrackNightlight;
    }
  }
}
