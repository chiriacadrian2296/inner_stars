import '../l10n/app_strings.dart';

/// The whoosh sounds offered for the Sky's own camera movement — one
/// picked independently for "flying closer" and one for "flying farther"
/// (see `AudioSettingsRepository.whooshInSound`/`whooshOutSound`), both
/// drawn from this same pool rather than two separate enums, since they're
/// the same kind of sound just assigned to different moments. Fixed and
/// closed, same as [SkySoundEffect].
enum SkyWhooshEffect { whooshA, whooshB, whooshC, whooshD, whooshE, whooshF }

extension SkyWhooshEffectX on SkyWhooshEffect {
  /// Relative to `assets/` — matches the `assets/audio/sfx/` folder
  /// declared in pubspec.yaml. See `assets/audio/CREDITS.txt` for where
  /// each file comes from (all CC0).
  String get assetPath {
    switch (this) {
      case SkyWhooshEffect.whooshA:
        return 'audio/sfx/whoosh_in.wav';
      case SkyWhooshEffect.whooshB:
        return 'audio/sfx/whoosh_out.wav';
      case SkyWhooshEffect.whooshC:
        return 'audio/sfx/whoosh_a.wav';
      case SkyWhooshEffect.whooshD:
        return 'audio/sfx/whoosh_b.wav';
      case SkyWhooshEffect.whooshE:
        return 'audio/sfx/whoosh_c.wav';
      case SkyWhooshEffect.whooshF:
        return 'audio/sfx/whoosh_d.wav';
    }
  }

  String displayName(AppStrings s) {
    switch (this) {
      case SkyWhooshEffect.whooshA:
        return s.skyWhooshA;
      case SkyWhooshEffect.whooshB:
        return s.skyWhooshB;
      case SkyWhooshEffect.whooshC:
        return s.skyWhooshC;
      case SkyWhooshEffect.whooshD:
        return s.skyWhooshD;
      case SkyWhooshEffect.whooshE:
        return s.skyWhooshE;
      case SkyWhooshEffect.whooshF:
        return s.skyWhooshF;
    }
  }
}
