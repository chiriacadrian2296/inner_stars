import '../l10n/app_strings.dart';

/// The short sounds offered for the Sky's own tap/hold feedback — the same
/// two moments [Haptics] already fires a buzz for (see `sky_screen.dart`'s
/// `_tapHaptic`/`_startHoldHaptic`), just picked independently per user via
/// `AudioSettingsRepository`. Fixed and closed, same as [BackgroundTrack].
enum SkySoundEffect {
  pluckSoft,
  pluckBright,
  glassLow,
  glassHigh,
  glassChime,
  glassBell,
  glassShine,
  glassTwinkle,
  bong,
  confirmation,
  chimeSoft,
  chimeWarm,
  chimeBright,
  select,
  blip,
  starBlip,
  shimmer,
  tick,
  toggle,
  click,
  cosmicDing,
  cosmicBlink,
  cosmicBeep,
}

extension SkySoundEffectX on SkySoundEffect {
  /// Relative to `assets/` — matches the `assets/audio/sfx/` folder
  /// declared in pubspec.yaml. See `assets/audio/CREDITS.txt` for where
  /// each file comes from (all CC0).
  String get assetPath {
    switch (this) {
      case SkySoundEffect.pluckSoft:
        return 'audio/sfx/pluck_001.wav';
      case SkySoundEffect.pluckBright:
        return 'audio/sfx/pluck_002.wav';
      case SkySoundEffect.glassLow:
        return 'audio/sfx/glass_001.wav';
      case SkySoundEffect.glassHigh:
        return 'audio/sfx/glass_003.wav';
      case SkySoundEffect.glassChime:
        return 'audio/sfx/glass_002.wav';
      case SkySoundEffect.glassBell:
        return 'audio/sfx/glass_004.wav';
      case SkySoundEffect.glassShine:
        return 'audio/sfx/glass_005.wav';
      case SkySoundEffect.glassTwinkle:
        return 'audio/sfx/glass_006.wav';
      case SkySoundEffect.bong:
        return 'audio/sfx/bong_001.wav';
      case SkySoundEffect.confirmation:
        return 'audio/sfx/confirmation_002.wav';
      case SkySoundEffect.chimeSoft:
        return 'audio/sfx/confirmation_001.wav';
      case SkySoundEffect.chimeWarm:
        return 'audio/sfx/confirmation_003.wav';
      case SkySoundEffect.chimeBright:
        return 'audio/sfx/confirmation_004.wav';
      case SkySoundEffect.select:
        return 'audio/sfx/select_004.wav';
      case SkySoundEffect.blip:
        return 'audio/sfx/select_001.wav';
      case SkySoundEffect.starBlip:
        return 'audio/sfx/select_003.wav';
      case SkySoundEffect.shimmer:
        return 'audio/sfx/select_006.wav';
      case SkySoundEffect.tick:
        return 'audio/sfx/tick_002.wav';
      case SkySoundEffect.toggle:
        return 'audio/sfx/toggle_002.wav';
      case SkySoundEffect.click:
        return 'audio/sfx/click_003.wav';
      case SkySoundEffect.cosmicDing:
        return 'audio/sfx/digital_ding.ogg';
      case SkySoundEffect.cosmicBlink:
        return 'audio/sfx/digital_blink.ogg';
      case SkySoundEffect.cosmicBeep:
        return 'audio/sfx/digital_beep.ogg';
    }
  }

  String displayName(AppStrings s) {
    switch (this) {
      case SkySoundEffect.pluckSoft:
        return s.skySoundPluckSoft;
      case SkySoundEffect.pluckBright:
        return s.skySoundPluckBright;
      case SkySoundEffect.glassLow:
        return s.skySoundGlassLow;
      case SkySoundEffect.glassHigh:
        return s.skySoundGlassHigh;
      case SkySoundEffect.glassChime:
        return s.skySoundGlassChime;
      case SkySoundEffect.glassBell:
        return s.skySoundGlassBell;
      case SkySoundEffect.glassShine:
        return s.skySoundGlassShine;
      case SkySoundEffect.glassTwinkle:
        return s.skySoundGlassTwinkle;
      case SkySoundEffect.bong:
        return s.skySoundBong;
      case SkySoundEffect.confirmation:
        return s.skySoundConfirmation;
      case SkySoundEffect.chimeSoft:
        return s.skySoundChimeSoft;
      case SkySoundEffect.chimeWarm:
        return s.skySoundChimeWarm;
      case SkySoundEffect.chimeBright:
        return s.skySoundChimeBright;
      case SkySoundEffect.select:
        return s.skySoundSelect;
      case SkySoundEffect.blip:
        return s.skySoundBlip;
      case SkySoundEffect.starBlip:
        return s.skySoundStarBlip;
      case SkySoundEffect.shimmer:
        return s.skySoundShimmer;
      case SkySoundEffect.tick:
        return s.skySoundTick;
      case SkySoundEffect.toggle:
        return s.skySoundToggle;
      case SkySoundEffect.click:
        return s.skySoundClick;
      case SkySoundEffect.cosmicDing:
        return s.skySoundCosmicDing;
      case SkySoundEffect.cosmicBlink:
        return s.skySoundCosmicBlink;
      case SkySoundEffect.cosmicBeep:
        return s.skySoundCosmicBeep;
    }
  }
}
