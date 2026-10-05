/// Where the Cosmo inserts the area artwork in its sky stack.
enum ArtworkLayer {
  behindSky,
  behindSupernovae,
  aboveStars;

  static ArtworkLayer fromName(String? name) => ArtworkLayer.values.firstWhere(
    (value) => value.name == name,
    orElse: () => ArtworkLayer.behindSky,
  );
}
