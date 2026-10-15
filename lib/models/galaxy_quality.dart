/// How much the Galaxy spends on drawing its sky. [quality] is the full
/// sky; the lighter modes trade detail the eye barely notices for a cooler
/// phone: the nebula clouds drawn at a lower resolution, the background
/// stars' twinkle followed a few times a second rather than every frame,
/// and in [performance] the ambient motion repainted less often.
enum GalaxyQuality {
  quality,
  balanced,
  performance;

  /// The fraction of the screen's own resolution the clouds are drawn at.
  double get cloudScale => switch (this) {
    GalaxyQuality.quality => 1,
    GalaxyQuality.balanced => 0.5,
    GalaxyQuality.performance => 0.34,
  };

  /// Which of the background stars are cached like the clouds while the
  /// camera stands still (their slow twinkle then follows the snapshots):
  /// 0 none, 1 the ones behind and in the dust and the galaxies, 2 all.
  int get starDepth => switch (this) {
    GalaxyQuality.quality => 0,
    GalaxyQuality.balanced => 1,
    GalaxyQuality.performance => 2,
  };

  /// The most times a second the ambient motion is repainted.
  int get ambientFps => switch (this) {
    GalaxyQuality.performance => 30,
    _ => 60,
  };

  static GalaxyQuality fromName(String? name) => GalaxyQuality.values
      .firstWhere((value) => value.name == name, orElse: () => quality);
}
