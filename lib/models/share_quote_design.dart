/// Number of one-tap style presets in the share composer.
const kShareQuotePresets = 5;

/// A quote's look in the share composer's vocabulary: one of the style
/// presets plus one of the three quote compositions.
class ShareQuoteDesign {
  const ShareQuoteDesign({this.preset = 0, this.composition = 0});

  factory ShareQuoteDesign.fromJson(Map<String, dynamic> json) =>
      ShareQuoteDesign(
        preset: ((json['preset'] as num?)?.toInt() ?? 0).clamp(
          0,
          kShareQuotePresets - 1,
        ),
        composition: ((json['composition'] as num?)?.toInt() ?? 0).clamp(0, 2),
      );

  final int preset;
  final int composition;

  Map<String, dynamic> toJson() => {
    'preset': preset,
    'composition': composition,
  };

  ShareQuoteDesign copyWith({int? preset, int? composition}) =>
      ShareQuoteDesign(
        preset: preset ?? this.preset,
        composition: composition ?? this.composition,
      );

  @override
  bool operator ==(Object other) =>
      other is ShareQuoteDesign &&
      other.preset == preset &&
      other.composition == composition;

  @override
  int get hashCode => Object.hash(preset, composition);
}
