import 'dart:ui' show BlendMode;

/// How the Cosmo composites each area's artwork (see `SkyAreaBackdrop`) onto
/// the sky. [plus] is the original look: the artwork's black simply adds
/// nothing, so only its light shows. The names are the standard blend-mode
/// names, left untranslated on purpose.
enum ArtworkBlend {
  plus('Plus', BlendMode.plus),
  screen('Screen', BlendMode.screen),
  lighten('Lighten', BlendMode.lighten),
  colorDodge('Color Dodge', BlendMode.colorDodge),
  overlay('Overlay', BlendMode.overlay),
  softLight('Soft Light', BlendMode.softLight),
  hardLight('Hard Light', BlendMode.hardLight),
  exclusion('Exclusion', BlendMode.exclusion),
  normal('Normal', BlendMode.srcOver);

  const ArtworkBlend(this.label, this.blendMode);

  final String label;
  final BlendMode blendMode;

  static ArtworkBlend fromName(String? name) => ArtworkBlend.values.firstWhere(
    (value) => value.name == name,
    orElse: () => ArtworkBlend.plus,
  );
}
