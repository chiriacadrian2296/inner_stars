import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../models/life_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../utils/area_hero_art.dart';

import '../models/share_content.dart';
import '../l10n/strings_scope.dart';
import '../widgets/photo_image.dart';
import '../widgets/app_choice_chip.dart';
import '../widgets/app_field.dart';
import '../data/photo_storage.dart';
import '../data/moodboard_storage.dart';
import '../l10n/share_composer_strings.dart';

part 'share_composer_layouts.dart';
part 'share_composer_page.dart';

/// Shape of the background gradient; the colours come from a [_Palette].
enum _GradientShape { halo, radial, vertical, diagonal }

/// Ink colour override: the title, and the brand (signature + watermark).
enum _Ink { white, gold, navyDark, navyLight, auto }

enum _WatermarkSize { small, medium, large }

/// What the signature shows.
enum _BrandContent { none, logo, name, both }

enum _LogoStyle { current, inverted }

/// A background colour set: two or more colours, applied on any gradient
/// shape. Light palettes switch the card's text to dark ink.
class _Palette {
  const _Palette(this.label, this.colors, {this.stops});
  final String label;
  final List<Color> colors;
  final List<double>? stops;

  bool get light {
    final luminance =
        colors.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
        colors.length;
    return luminance > .4;
  }
}

const _palettes = <_Palette>[
  _Palette(
    'Notte',
    [Color(0xFF232C44), Color(0xFF161D30), Color(0xFF0D1220)],
    stops: [0, .55, 1],
  ),
  _Palette('Ardesia', [
    Color(0xFF465B79),
    Color(0xFF2D3D56),
    Color(0xFF202B3E),
  ]),
  _Palette(
    'Luce Soffusa',
    [Color(0xFF1C2747), Color(0xFF10162B), Color(0xFF05070D)],
    stops: [0, .55, 1],
  ),
  _Palette('Oro', [Color(0xFF80603A), Color(0xFF353040), Color(0xFF0D1220)]),
];

enum _ShareFormat { story, vertical, portrait, square, landscape }

double _shareAspectRatio(_ShareFormat format) => switch (format) {
  _ShareFormat.story => 2 / 3,
  _ShareFormat.vertical => 9 / 16,
  _ShareFormat.portrait => 4 / 5,
  _ShareFormat.square => 1,
  _ShareFormat.landscape => 16 / 9,
};

enum _PhotoMode { none, background, panel, circle }

enum _Watermark { none, logo, area }

enum _BrandLayout { logoAbove, logoLeft }

enum _LogoSize { small, medium, large }

enum _TitlePosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum _BadgePosition { top, bottom }

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    super.key,
    required this.format,
    required this.specimen,
    required this.captureKey,
    this.padding = 24,
  });
  final _ShareFormat format;
  final Widget specimen;

  /// Boundary the shared image is captured from.
  final GlobalKey captureKey;
  final double padding;

  double get _aspectRatio => _shareAspectRatio(format);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(padding),
    child: LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / _aspectRatio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * _aspectRatio;
        }
        // The card is composed on a fixed logical canvas (as in the Victory
        // Stars design board) and scaled to fit, so type and spacing keep
        // the same proportions at every preview size.
        final canvasWidth = format == _ShareFormat.landscape ? 640.0 : 360.0;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: canvasWidth,
                height: canvasWidth / _aspectRatio,
                child: RepaintBoundary(
                  key: captureKey,
                  child: MediaQuery.withNoTextScaling(child: specimen),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ShareSpecimen extends StatelessWidget {
  const _ShareSpecimen({
    required this.data,
    required this.composition,
    required this.gradient,
    this.reverseColors = false,
    required this.palette,
    required this.titleInk,
    required this.watermarkInk,
    required this.watermarkSize,
    required this.watermarkArea,
    required this.brandContent,
    required this.logoStyle,
    required this.logoDisc,
    required this.nameInk,
    required this.logoInk,
    required this.logoSize,
    required this.format,
    required this.photoMode,
    required this.titlePosition,
    required this.brandPosition,
    required this.badgePosition,
    required this.watermark,
    required this.brandLayout,
    required this.showType,
    required this.showDate,
    required this.showArea,
    required this.showProject,
    required this.showDescription,
    required this.showStats,
  });
  final ShareContent data;
  ShareSubject get subject => data.subject;
  final int composition;
  final _GradientShape gradient;
  final bool reverseColors;
  final int palette;
  final _Ink titleInk;
  final _Ink watermarkInk;
  final _WatermarkSize watermarkSize;
  final int watermarkArea;
  final _BrandContent brandContent;
  final _LogoStyle logoStyle;
  final bool logoDisc;
  final _Ink nameInk;
  final _Ink logoInk;
  final _LogoSize logoSize;
  final _ShareFormat format;
  final _PhotoMode photoMode;
  final _TitlePosition titlePosition;
  final _TitlePosition brandPosition;
  final _BadgePosition badgePosition;
  final _Watermark watermark;
  final _BrandLayout brandLayout;
  final bool showType;
  final bool showDate;
  final bool showArea;
  final bool showProject;
  final bool showDescription;
  final bool showStats;

  String get _title => data.title;
  String get _description => data.description;
  String get _photoUrl => data.photos.isEmpty ? '' : data.photos.first;
  Widget _photoAt(int index) => data.photos.isEmpty
      ? data.artwork ?? const SizedBox.shrink()
      : _ContentPhoto(
          url: data.photos[index % data.photos.length],
          fit: BoxFit.cover,
          moodboard: subject == ShareSubject.moodboard,
        );

  bool get _lightBackground => _palettes[palette].light;
  Alignment get _titleAlignment => _alignmentFor(titlePosition);
  TextAlign get _titleTextAlign => switch (titlePosition) {
    _TitlePosition.topCenter ||
    _TitlePosition.center ||
    _TitlePosition.bottomCenter => TextAlign.center,
    _TitlePosition.topRight ||
    _TitlePosition.centerRight ||
    _TitlePosition.bottomRight => TextAlign.right,
    _ => TextAlign.left,
  };

  BoxDecoration _decoration(AppColors colors) => BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: _lightBackground ? const Color(0xFFBEB6A7) : colors.nightBorder,
      width: kBorderWidth,
    ),
    gradient: _backgroundGradient(
      gradient,
      _palettes[palette],
      reversed: reverseColors,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final layout = _layout.$1;
    // A cover-style moodboard is a photo card even without picking a photo.
    final effPhoto =
        data.photos.isNotEmpty &&
            photoMode == _PhotoMode.none &&
            subject == ShareSubject.moodboard &&
            layout == _Layout.free
        ? _PhotoMode.background
        : photoMode;
    final usePaperPalette =
        _lightBackground && effPhoto != _PhotoMode.background;
    final foreground = usePaperPalette ? const Color(0xFF28231D) : colors.text;
    final secondary = usePaperPalette ? const Color(0xFF635A4E) : colors.muted;
    final accent = usePaperPalette ? const Color(0xFF8A5A26) : colors.gold;
    final compact = format == _ShareFormat.landscape;
    Color? inkColor(_Ink ink) => _inkDotColor(colors, ink);
    final titleColor = inkColor(titleInk) ?? foreground;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: _decoration(colors),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (effPhoto == _PhotoMode.background)
              _ContentPhoto(
                url: _photoUrl,
                fit: BoxFit.cover,
                moodboard: subject == ShareSubject.moodboard,
              ),
            if (effPhoto == _PhotoMode.background) const _PhotoBackdropScrim(),
            if (effPhoto == _PhotoMode.panel && layout == _Layout.free)
              Align(
                alignment: composition.isEven
                    ? Alignment.topCenter
                    : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: composition.isEven ? 1 : .46,
                  heightFactor: composition.isEven ? .4 : 1,
                  child: _ContentPhoto(
                    url: _photoUrl,
                    fit: BoxFit.cover,
                    moodboard: subject == ShareSubject.moodboard,
                  ),
                ),
              ),
            if (watermark != _Watermark.none)
              Center(
                child: _WatermarkArt(
                  watermark: watermark,
                  color: inkColor(watermarkInk) ?? foreground,
                  tinted: watermarkInk != _Ink.auto,
                  // Large stays inside the card (the logo's shapes cover about two
                  // thirds of its width, an area artwork nearly all of it).
                  size:
                      switch (watermarkSize) {
                        _WatermarkSize.small => 300.0,
                        _WatermarkSize.medium => 440.0,
                        _WatermarkSize.large => 520.0,
                      } *
                      (compact ? .68 : 1),
                  area: watermarkArea,
                ),
              ),
            if (layout == _Layout.free &&
                effPhoto != _PhotoMode.panel &&
                effPhoto != _PhotoMode.background)
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: .7,
                  heightFactor: compact ? .58 : .36,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child:
                        data.artwork ??
                        Icon(Icons.auto_awesome, color: accent, size: 64),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(compact ? 18 : 24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (layout != _Layout.free)
                    Padding(
                      padding: EdgeInsets.only(
                        top: brandPosition == _TitlePosition.topRight ? 40 : 0,
                        bottom: brandPosition == _TitlePosition.topRight
                            ? 0
                            : 42,
                      ),
                      child: _layoutContent(
                        _Look(
                          foreground: foreground,
                          secondary: secondary,
                          accent: accent,
                          compact: compact,
                          title: titleColor,
                        ),
                      ),
                    ),
                  if (layout == _Layout.free)
                    Align(
                      alignment: _titleAlignment,
                      child: FractionallySizedBox(
                        widthFactor: compact ? .52 : .82,
                        child: _TitleBlock(
                          title: _title,
                          description: showDescription ? _description : null,
                          textAlign: _titleTextAlign,
                          foreground: titleColor,
                          secondary: secondary,
                          accent: accent,
                          compact: compact,
                          composition: 0,
                        ),
                      ),
                    ),
                  if (layout == _Layout.free && _hasBadges)
                    Align(
                      alignment: badgePosition == _BadgePosition.top
                          ? Alignment.topLeft
                          : Alignment.bottomLeft,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: badgePosition == _BadgePosition.top ? 44 : 0,
                          bottom: badgePosition == _BadgePosition.bottom
                              ? 28
                              : 0,
                        ),
                        child: _BadgeWrap(
                          data: data,
                          showType: showType,
                          showDate: showDate,
                          showArea: showArea,
                          showProject: showProject,
                          showStats: showStats,
                          accent: accent,
                          foreground: foreground,
                          compact: compact,
                        ),
                      ),
                    ),
                  if (brandContent != _BrandContent.none)
                    Align(
                      alignment: _alignmentFor(brandPosition),
                      child: _AppBrand(
                        content: brandContent,
                        logoStyle: logoStyle,
                        disc: logoDisc,
                        ink: inkColor(nameInk),
                        logoInk: inkColor(logoInk),
                        logoSize: switch (logoSize) {
                          _LogoSize.small => 16.0,
                          _LogoSize.medium => 30.0,
                          _LogoSize.large => 44.0,
                        },
                        layout: brandLayout,
                        foreground: foreground,
                        secondary: secondary,
                        accent: accent,
                        compact: compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasBadges =>
      showType ||
      showDate ||
      showArea ||
      showProject ||
      (showStats &&
          (subject == ShareSubject.victory ||
              subject == ShareSubject.habit ||
              subject == ShareSubject.goal ||
              subject == ShareSubject.project));
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.description,
    required this.textAlign,
    required this.foreground,
    required this.secondary,
    required this.accent,
    required this.compact,
    required this.composition,
  });
  final String title;
  final String? description;
  final TextAlign textAlign;
  final Color foreground;
  final Color secondary;
  final Color accent;
  final bool compact;
  final int composition;

  CrossAxisAlignment get _crossAxisAlignment => switch (textAlign) {
    TextAlign.center => CrossAxisAlignment.center,
    TextAlign.right => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: _crossAxisAlignment,
    children: [
      if (composition == 2)
        Container(
          width: 44,
          height: 2,
          margin: const EdgeInsets.only(bottom: 10),
          color: accent,
        ),
      _BalancedText(
        title,
        maxLines: compact ? 3 : 5,
        textAlign: textAlign,
        style: TextStyle(
          color: foreground,
          fontFamily: composition == 3 ? kFontBody : kFontStarTitle,
          fontSize: compact ? 23 : (composition == 4 ? 26 : 31),
          fontStyle: composition == 1 ? FontStyle.normal : FontStyle.italic,
          fontWeight: FontWeight.w700,
          height: 1.05,
          shadows: const [Shadow(color: Color(0x77000000), blurRadius: 14)],
        ),
      ),
      if (description != null) ...[
        const SizedBox(height: 10),
        Text(
          description!,
          maxLines: compact ? 2 : 4,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            color: secondary,
            fontSize: compact ? 10 : 13,
            height: 1.35,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 10)],
          ),
        ),
      ],
    ],
  );
}

class _BadgeWrap extends StatelessWidget {
  const _BadgeWrap({
    required this.data,
    required this.showType,
    required this.showDate,
    required this.showArea,
    required this.showProject,
    required this.showStats,
    required this.accent,
    required this.foreground,
    required this.compact,
    this.align = CrossAxisAlignment.start,
  });
  final ShareContent data;
  final bool showType;
  final bool showDate;
  final bool showArea;
  final bool showProject;
  final bool showStats;
  final Color accent;
  final Color foreground;
  final bool compact;
  final CrossAxisAlignment align;

  String get _type => data.typeLabel.toUpperCase();
  String? get _stat => data.statLabel;

  @override
  Widget build(BuildContext context) {
    final secondary = foreground.withValues(alpha: .68);
    final stat = _stat;
    final showArea = this.showArea && data.areaLabel != null;
    final showProject = this.showProject && data.projectLabel != null;
    final showDate = this.showDate && data.dateLabel != null;
    final hasMeta = showArea || showProject || showDate;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 340 : 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          if (showType)
            Text(
              _type,
              style: TextStyle(
                color: accent,
                fontFamily: kFontMono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          if (showType && hasMeta) const SizedBox(height: 8),
          if (hasMeta)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: align == CrossAxisAlignment.center
                  ? WrapAlignment.center
                  : WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (showArea || showProject)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StarGlyph(size: 12, color: accent),
                      const SizedBox(width: 6),
                      if (showArea)
                        Text(
                          data.areaLabel!,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (showProject)
                        Flexible(
                          child: Text(
                            showArea
                                ? ' · ${data.projectLabel}'
                                : data.projectLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: secondary, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                if (showDate)
                  Text(
                    data.dateLabel!,
                    style: TextStyle(
                      color: secondary,
                      fontFamily: kFontMono,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          if (showStats && data.intensity != null) ...[
            if (showType || hasMeta) const SizedBox(height: 10),
            _IntensityBolts(
              lit: data.intensity!,
              accent: accent,
              unlit: secondary,
            ),
          ],
          if (showStats && stat != null) ...[
            if (showType || hasMeta) const SizedBox(height: 10),
            _StatPill(label: stat, accent: accent),
          ],
        ],
      ),
    );
  }
}

/// Gold-tinted pill with a mono label: the "serie di 4" chip of the design
/// board's data-rich card.
class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(kRadiusPill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: TextStyle(color: accent, fontFamily: kFontMono, fontSize: 10.5),
      ),
    ),
  );
}

/// Five bolts: lit ones burn gold, the last lit one a size up with a halo;
/// the rest stay flat and dim ("gold burns, navy is off").
class _IntensityBolts extends StatelessWidget {
  const _IntensityBolts({
    required this.lit,
    required this.accent,
    required this.unlit,
  });
  final int lit;
  final Color accent;
  final Color unlit;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        if (i == lit - 1)
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .45), blurRadius: 9),
              ],
            ),
            child: _BoltGlyph(size: 18, color: accent),
          )
        else
          _BoltGlyph(
            size: 14,
            color: i < lit ? accent : unlit.withValues(alpha: .35),
          ),
      ],
    ],
  );
}

const _starPath =
    'M12 2.5l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.6 6.1 20.5l1.2-6.5-4.8-4.6 '
    '6.6-.9L12 2.5z';
const _boltPath = 'M13 2L4 14h7l-1 8 10-12h-7l1-8z';

SvgPicture _glyph(String path, double size, Color color) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
  '<path d="$path" fill="#FFFFFF"/></svg>',
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);

class _StarGlyph extends StatelessWidget {
  const _StarGlyph({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => _glyph(_starPath, size, color);
}

class _BoltGlyph extends StatelessWidget {
  const _BoltGlyph({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => _glyph(_boltPath, size, color);
}

class _WatermarkArt extends StatelessWidget {
  const _WatermarkArt({
    required this.watermark,
    required this.color,
    required this.tinted,
    required this.size,
    required this.area,
  });

  final _Watermark watermark;
  final Color color;

  /// True when the ink was picked on purpose, so it can be a little stronger
  /// than the default whisper.
  final bool tinted;
  final double size;
  final int area;

  @override
  Widget build(BuildContext context) {
    final areaAsset = kAreaHeroArt[LifeArea.values[area]]!.coverAsset;
    final art = switch (watermark) {
      _Watermark.none => const SizedBox.shrink(),
      _Watermark.logo => SvgPicture.asset(
        'assets/icon/Logo.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
      // The area's royal-symbol artwork, repainted in a single ink and
      // scaled so every area covers about the same visual mass.
      _Watermark.area => Image.asset(
        areaAsset,
        width: size * .72 * _areaArtScale[area],
        height: size * .72 * _areaArtScale[area],
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      ),
    };
    // These are bigger than the card on purpose: let them bleed past it.
    return Opacity(
      opacity: switch (watermark) {
        _Watermark.area => tinted ? .2 : .13,
        _ => tinted ? .14 : .075,
      },
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: size * 1.2,
        maxHeight: size * 1.2,
        child: art,
      ),
    );
  }
}

/// Per-area correction so the eight artworks fill the same visual space.
/// They share one canvas and height, but their ink differs a lot (Social is
/// heavy, Personal and Philanthropic are light); each factor is
/// sqrt(mean ink / own ink), measured on the royal-symbol PNGs, in
/// [LifeArea] order.
const _areaArtScale = [1.02, .97, 1.01, .97, 1.11, .89, .97, 1.1];

class _AppBrand extends StatelessWidget {
  const _AppBrand({
    required this.content,
    required this.logoStyle,
    required this.disc,
    required this.ink,
    required this.logoInk,
    required this.logoSize,
    required this.layout,
    required this.foreground,
    required this.secondary,
    required this.accent,
    required this.compact,
  });

  final _BrandContent content;
  final _LogoStyle logoStyle;
  final bool disc;

  /// The brand colour picked by the user, or null for the card's own palette
  /// (gold logo, softened white wordmark).
  final Color? ink;
  final _BrandLayout layout;

  /// Colour of the logo (null: the card's own gold) and its diameter.
  final Color? logoInk;
  final double logoSize;
  final Color foreground;
  final Color secondary;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final night = context.colors.night;
    final size = logoSize * (compact ? .8 : 1);
    final logoColor = logoInk ?? foreground;
    final nameColor = ink ?? foreground;
    final logo = !disc
        ? _BareLogo(size: size, color: logoColor)
        : switch (logoStyle) {
            _LogoStyle.current => _AppLogoMark(
              size: size,
              discColor: logoColor,
              glyphColor: night,
            ),
            // Colours swapped: a dark disc with the glyph and a thin ring in
            // the logo colour.
            _LogoStyle.inverted => _AppLogoMark(
              size: size,
              discColor: night,
              glyphColor: logoColor,
              ringColor: logoColor,
            ),
          }; // Signature as on the design board: quiet Gloock wordmark, dimmed so the
    // user's own words stay the loudest thing on the card.
    final name = Text(
      'Inner Stars',
      style: TextStyle(
        color: nameColor,
        fontFamily: kFontBranding,
        fontSize: compact ? 12 : 14,
        fontWeight: FontWeight.w400,
        height: 1,
      ),
    );
    return switch (content) {
      _BrandContent.none => const SizedBox.shrink(),
      _BrandContent.logo => logo,
      _BrandContent.name => name,
      _BrandContent.both => switch (layout) {
        _BrandLayout.logoAbove => Column(
          mainAxisSize: MainAxisSize.min,
          children: [logo, const SizedBox(height: 5), name],
        ),
        _BrandLayout.logoLeft => Row(
          mainAxisSize: MainAxisSize.min,
          children: [logo, const SizedBox(width: 7), name],
        ),
      },
    };
  }
}

/// The logo glyph alone, trimmed of the svg's empty margins (its shapes span
/// about 45% x 64% of the file) so it aligns like any other element.
class _BareLogo extends StatelessWidget {
  const _BareLogo({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = size * 1.5;
    return SizedBox(
      width: box * .45,
      height: box * .64,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: box,
        maxHeight: box,
        child: SvgPicture.asset(
          'assets/icon/Logo.svg',
          width: box,
          height: box,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _AppLogoMark extends StatelessWidget {
  const _AppLogoMark({
    required this.size,
    required this.discColor,
    required this.glyphColor,
    this.ringColor,
  });

  final double size;
  final Color discColor;
  final Color glyphColor;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: discColor,
      border: ringColor == null
          ? null
          : Border.all(color: ringColor!, width: 1.5),
    ),
    alignment: Alignment.center,
    child: OverflowBox(
      maxWidth: size * 1.06,
      maxHeight: size * 1.06,
      child: SvgPicture.asset(
        'assets/icon/Logo.svg',
        width: size * 1.06,
        height: size * 1.06,
        colorFilter: ColorFilter.mode(glyphColor, BlendMode.srcIn),
      ),
    ),
  );
}

Future<Uint8List?> _readSharePhoto(String path, bool moodboard) =>
    moodboard ? MoodboardStorage.read(path) : PhotoStorage.readBytes(path);

class _PhotoBackdropScrim extends StatelessWidget {
  const _PhotoBackdropScrim();
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: const [
      // Soft veil over the whole photo, then the design board's
      // night scrim rising from the bottom edge under the text.
      DecoratedBox(decoration: BoxDecoration(color: Color(0x3305070D))),
      // Top scrim too, so a title placed at the top stays readable
      // on a bright photo.
      Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          heightFactor: .4,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB305070D), Color(0x0005070D)],
              ),
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: .62,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0005070D),
                  Color(0x8C05070D),
                  Color(0xF205070D),
                ],
                stops: [0, .35, 1],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _ContentPhoto extends StatefulWidget {
  const _ContentPhoto({
    required this.url,
    required this.fit,
    this.moodboard = false,
  });
  final String url;
  final BoxFit fit;
  final bool moodboard;
  @override
  State<_ContentPhoto> createState() => _ContentPhotoState();
}

class _ContentPhotoState extends State<_ContentPhoto> {
  late Future<Uint8List?> _bytes;
  void _load() {
    _bytes = widget.url.isEmpty || PhotoStorage.isRemote(widget.url)
        ? Future.value(null)
        : _readSharePhoto(widget.url, widget.moodboard);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ContentPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.moodboard != widget.moodboard) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return const SizedBox.shrink();
    if (PhotoStorage.isRemote(widget.url)) {
      return PhotoImage(photoPath: widget.url, fit: widget.fit);
    }
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) => snapshot.data == null
          ? const SizedBox.shrink()
          : Image.memory(snapshot.data!, fit: widget.fit),
    );
  }
}

Alignment _alignmentFor(_TitlePosition position) => switch (position) {
  _TitlePosition.topLeft => Alignment.topLeft,
  _TitlePosition.topCenter => Alignment.topCenter,
  _TitlePosition.topRight => Alignment.topRight,
  _TitlePosition.centerLeft => Alignment.centerLeft,
  _TitlePosition.center => Alignment.center,
  _TitlePosition.centerRight => Alignment.centerRight,
  _TitlePosition.bottomLeft => Alignment.bottomLeft,
  _TitlePosition.bottomCenter => Alignment.bottomCenter,
  _TitlePosition.bottomRight => Alignment.bottomRight,
};

/// Any gradient [shape] applied to any [palette]'s colours.
Gradient _backgroundGradient(
  _GradientShape shape,
  _Palette palette, {
  bool reversed = false,
}) {
  final colors = reversed ? palette.colors.reversed.toList() : palette.colors;
  final evenStops = [
    for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
  ];
  switch (shape) {
    case _GradientShape.halo:
      // The supernova glow of the Victory Stars cards: a pool of light just
      // above the top edge fading into the dark.
      return RadialGradient(
        center: const Alignment(0, -1.2),
        radius: 1.25,
        colors: colors,
        stops: palette.stops ?? evenStops,
      );
    case _GradientShape.radial:
      return RadialGradient(
        center: const Alignment(0, -.15),
        radius: .95,
        colors: colors,
        stops: evenStops,
      );
    case _GradientShape.vertical:
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: evenStops,
      );
    case _GradientShape.diagonal:
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: evenStops,
      );
  }
}
