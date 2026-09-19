import '../models/life_area.dart';

/// A [LifeArea]'s own hero art (see assets/images) in the two forms the
/// app uses it in: [coverAsset], the full image — title, tagline, and all
/// — for that area's own "cover" page and management-page banner (see
/// `area_detail_screen.dart`); [skyAsset], a "center crop" of the same
/// artwork with that baked-in text cropped out, for the huge wash behind
/// that area's own supernova in the sky (see `sky_area_backdrop.dart`,
/// which would otherwise be showing a title/tagline floating in the sky).
class AreaHeroArt {
  const AreaHeroArt({required this.coverAsset, required this.skyAsset});

  final String coverAsset;
  final String skyAsset;
}

/// Every [LifeArea] with hero art of its own so far — the one shared
/// source of truth both `area_detail_screen.dart` (which area gets a
/// cover, and which two files it shows) and `sky_screen.dart`/
/// `sky_area_backdrop.dart` (which area's hold-to-straighten targets its
/// own backdrop, and which file that backdrop loads) read from, so the two
/// can never drift out of sync with each other. Every other [LifeArea] has
/// no entry and falls back to its plain, art-less treatment everywhere.
const Map<LifeArea, AreaHeroArt> kAreaHeroArt = {
  LifeArea.physical: AreaHeroArt(
    coverAsset: 'assets/images/1. Physical.png',
    skyAsset: 'assets/images/1. Physical - CENTER CROP.jpg',
  ),
  LifeArea.psychological: AreaHeroArt(
    coverAsset: 'assets/images/2. Psychological.png',
    skyAsset: 'assets/images/2. Psychological - CENTER CROP.jpg',
  ),
  LifeArea.professional: AreaHeroArt(
    coverAsset: 'assets/images/3. Professional.png',
    skyAsset: 'assets/images/3. Professional - CENTER CROP.jpg',
  ),
  LifeArea.financial: AreaHeroArt(
    coverAsset: 'assets/images/4. Financial.png',
    skyAsset: 'assets/images/4. Financial - CENTER CROP.jpg',
  ),
};
