part of 'share_composer_screen.dart';

/// Draws a quote exactly as the share composer would (story format), scaled
/// to fill the available width.
class ShareQuoteArtwork extends StatelessWidget {
  const ShareQuoteArtwork({
    super.key,
    required this.data,
    this.design = const ShareQuoteDesign(),
    this.aspectRatio = 2 / 3,
    this.fill = false,
  });
  final ShareContent data;
  final ShareQuoteDesign design;
  final double aspectRatio;

  /// Cover the parent instead of keeping [aspectRatio] (grid tiles).
  final bool fill;

  /// Composes the card on the composer canvas for [ratio] (width / height).
  Widget _card(double ratio) {
    final format = _ShareFormat.values.reduce(
      (a, b) =>
          (_shareAspectRatio(a) - ratio).abs() <=
              (_shareAspectRatio(b) - ratio).abs()
          ? a
          : b,
    );
    final canvas = format == _ShareFormat.landscape ? 640.0 : 360.0;
    final preset = _stylePresets[design.preset];
    final layout = _layoutMap[ShareSubject.quote]![design.composition].$1;
    final ink = switch (layout) {
      _Layout.centered || _Layout.free => _Ink.gold,
      _ => _Ink.auto,
    };
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: canvas,
        height: canvas / ratio,
        child: MediaQuery.withNoTextScaling(
          child: _ShareSpecimen(
            data: data,
            composition: design.composition,
            gradient: preset.gradient,
            palette: preset.palette,
            format: format,
            photoMode: _PhotoMode.none,
            titlePosition: _TitlePosition.bottomLeft,
            brandPosition: switch (layout) {
              _Layout.free || _Layout.poster => _TitlePosition.topRight,
              _ => _TitlePosition.bottomCenter,
            },
            badgePosition: _BadgePosition.top,
            titleInk: _Ink.auto,
            watermark: data.area == null && preset.watermark == _Watermark.area
                ? _Watermark.none
                : preset.watermark,
            watermarkInk: ink,
            watermarkArea: data.area?.index ?? 0,
            brandContent: _BrandContent.both,
            logoStyle: _LogoStyle.current,
            logoDisc: false,
            nameInk: ink,
            logoInk: ink,
            logoSize: _LogoSize.small,
            brandLayout: _BrandLayout.logoLeft,
            showType: true,
            showDate: true,
            showArea: true,
            showProject: true,
            showDescription: data.description.isNotEmpty,
            showStats: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => fill
      ? LayoutBuilder(
          builder: (context, constraints) => SizedBox.expand(
            child: _card(constraints.maxWidth / constraints.maxHeight),
          ),
        )
      : AspectRatio(aspectRatio: aspectRatio, child: _card(aspectRatio));
}

/// Style and composition pickers for a quote, the same choices the share
/// composer offers.
class ShareQuoteDesignPicker extends StatelessWidget {
  const ShareQuoteDesignPicker({
    super.key,
    required this.data,
    required this.design,
    required this.onChanged,
  });
  final ShareContent data;
  final ShareQuoteDesign design;
  final ValueChanged<ShareQuoteDesign> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _VisualChoices(
        fieldKey: 'quote-preset',
        label: 'Stili Pronti',
        labels: [for (final p in _stylePresets) p.label],
        index: design.preset,
        columns: 5,
        previewHeight: 90,
        preview: (i) => ShareQuoteArtwork(
          data: data,
          design: design.copyWith(preset: i),
        ),
        onChanged: (i) => onChanged(design.copyWith(preset: i)),
      ),
      const SizedBox(height: 16),
      _VisualChoices(
        fieldKey: 'quote-composition',
        label: 'Composizione',
        labels: _compositionLabels(ShareSubject.quote),
        index: design.composition,
        columns: 3,
        previewHeight: 90,
        preview: (i) => ShareQuoteArtwork(
          data: data,
          design: design.copyWith(composition: i),
        ),
        onChanged: (i) => onChanged(design.copyWith(composition: i)),
      ),
    ],
  );
}
