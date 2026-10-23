part of 'share_composer_screen.dart';

/// Layout archetypes for a share card. Each one has its own feeling, taken
/// from the Victory Stars design board: [centered] is the classic supernova
/// card, [minimal] the postcard, [hero] one giant number, [tiles] a recap
/// grid, [poster] and [editorial] pure typography, [polaroid], [collage] and
/// [gallery] photo-led, [constellation] a drawn map. [free] is the original
/// movable layout driven by the title/badge position controls.
enum _Layout {
  free,
  centered,
  minimal,
  hero,
  tiles,
  poster,
  editorial,
  polaroid,
  collage,
  gallery,
  constellation,
}

/// Which archetype (and variant) each composition chip of each subject uses.
/// Order matches the composition labels of the control panel.
const _layoutMap = <ShareSubject, List<(_Layout, int)>>{
  ShareSubject.victory: [
    (_Layout.centered, 0),
    (_Layout.polaroid, 0),
    (_Layout.free, 0),
  ],
  ShareSubject.goal: [
    (_Layout.centered, 0),
    (_Layout.poster, 0),
    (_Layout.editorial, 1),
  ],
  ShareSubject.habit: [
    (_Layout.centered, 0),
    (_Layout.editorial, 1),
    (_Layout.free, 0),
  ],
  ShareSubject.project: [
    (_Layout.constellation, 0),
    (_Layout.poster, 0),
    (_Layout.free, 0),
  ],
  ShareSubject.vision: [
    (_Layout.poster, 0),
    (_Layout.editorial, 1),
    (_Layout.editorial, 3),
  ],
  ShareSubject.moodboard: [
    (_Layout.collage, 0),
    (_Layout.gallery, 0),
    (_Layout.polaroid, 0),
  ],
  ShareSubject.quote: [
    (_Layout.poster, 0),
    (_Layout.editorial, 1),
    (_Layout.poster, 1),
  ],
};

/// Resolved colours and scale for one card render.
class _Look {
  const _Look({
    required this.foreground,
    required this.secondary,
    required this.accent,
    required this.compact,
    required this.title,
  });
  final Color foreground;
  final Color secondary;
  final Color accent;
  final bool compact;

  /// Colour of the title (the user's own words); defaults to [foreground].
  final Color title;

  /// Type scale: the landscape canvas is much shorter than the portrait ones.
  double get k => compact ? .72 : 1;
}

extension _SpecimenLayouts on _ShareSpecimen {
  (_Layout, int) get _layout {
    final list = _layoutMap[subject]!;
    return list[composition.clamp(0, list.length - 1)];
  }

  String get _typeLabel => data.typeLabel;
  String? get _statText => data.statLabel;
  (String, String) get _hero => (data.heroValue ?? '', data.heroCaption ?? '');
  bool get _hasStat => data.intensity != null || data.statLabel != null;

  Widget _layoutContent(_Look l) {
    final (layout, variant) = _layout;
    return switch (layout) {
      _Layout.free => const SizedBox.shrink(),
      _Layout.centered => _centered(l),
      _Layout.minimal => _minimal(l),
      _Layout.hero => _heroLayout(l),
      _Layout.tiles => _tilesLayout(l),
      _Layout.poster => _poster(l, variant),
      _Layout.editorial => _editorial(l, variant),
      _Layout.polaroid => _polaroid(l),
      _Layout.collage => _collage(l),
      _Layout.gallery => _gallery(l),
      _Layout.constellation => _constellationLayout(l),
    };
  }

  // ----- shared pieces -----

  /// Scales the content down (never up) when the canvas is too short for it.
  Widget _fit(Widget child, {Alignment alignment = Alignment.center}) =>
      LayoutBuilder(
        builder: (context, box) => Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: SizedBox(width: box.maxWidth, child: child),
          ),
        ),
      );

  Widget _titleText(
    _Look l,
    double size, {
    TextAlign align = TextAlign.center,
    int maxLines = 5,
    bool italic = true,
    Color? color,
  }) => _BalancedText(
    _title,
    textAlign: align,
    maxLines: maxLines,
    style: TextStyle(
      color: color ?? l.title,
      fontFamily: kFontStarTitle,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontWeight: FontWeight.w600,
      fontSize: size * l.k,
      height: 1.14,
    ),
  );

  Widget _descText(
    _Look l, {
    TextAlign align = TextAlign.center,
    double size = 13,
    int maxLines = 4,
  }) => Text(
    _description,
    textAlign: align,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: l.secondary, fontSize: size * l.k, height: 1.4),
  );

  /// Type label, area/project and date, honouring the data switches.
  /// [stats] adds the stat chip / bolts like the free layout does.
  /// A moodboard card already carries its name as the title.
  bool get _moodboardCard => data.tiles.isNotEmpty;

  Widget _meta(
    _Look l, {
    CrossAxisAlignment align = CrossAxisAlignment.center,
    bool stats = false,
    bool type = true,
  }) {
    final anyStat = stats && showStats && _hasStat;
    final any =
        (type && showType && !_moodboardCard) ||
        showDate ||
        showArea ||
        showProject ||
        anyStat;
    if (!any) return const SizedBox.shrink();
    return _BadgeWrap(
      data: data,
      showType: type && showType && !_moodboardCard,
      showDate: showDate,
      showArea: showArea,
      showProject: showProject,
      showStats: anyStat,
      accent: l.accent,
      foreground: l.foreground,
      compact: l.compact,
      align: align,
    );
  }

  /// The stat on its own (bolts for a victory, a pill otherwise).
  Widget _stat(_Look l) {
    if (!showStats || !_hasStat) return const SizedBox.shrink();
    if (data.intensity != null) {
      return _IntensityBolts(
        lit: data.intensity!,
        accent: l.accent,
        unlit: l.secondary,
      );
    }
    return _StatPill(label: _statText!, accent: l.accent);
  }

  /// The card's emblem: a burning star (a plain one when it isn't a victory),
  /// an opening quote mark for quotes, or the round photo.
  Widget _mark(_Look l, double size, {bool? burning}) {
    if (photoMode == _PhotoMode.integrated) {
      return _roundPhoto(l, size);
    }
    final lit = burning ?? subject == ShareSubject.victory;
    if (subject == ShareSubject.quote) {
      return Text(
        '“',
        style: TextStyle(
          color: l.accent,
          fontFamily: kFontBranding,
          fontSize: size * 2.2 * l.k,
          height: .8,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: lit
            ? [
                BoxShadow(
                  color: l.accent.withValues(alpha: .5),
                  blurRadius: size * .9,
                  spreadRadius: size * .05,
                ),
              ]
            : null,
      ),
      child: _StarGlyph(
        size: size * l.k,
        color: lit ? l.accent : l.accent.withValues(alpha: .7),
      ),
    );
  }

  Widget _roundPhoto(_Look l, double size) => Container(
    key: const ValueKey('share-round-photo'),
    width: size * 3.2 * l.k,
    height: size * 3.2 * l.k,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: l.accent, width: kBorderWidthActive),
    ),
    padding: const EdgeInsets.all(4),
    child: ClipOval(
      child: _ContentPhoto(
        url: _photoUrl,
        fit: BoxFit.cover,
        moodboard: subject == ShareSubject.moodboard,
      ),
    ),
  );

  Widget _gap(_Look l, double h) => SizedBox(height: h * l.k);

  Widget _rule(_Look l, {double width = 40}) => Container(
    width: width,
    height: 2,
    decoration: BoxDecoration(
      color: l.accent,
      borderRadius: BorderRadius.circular(1),
    ),
  );

  Widget _monoLabel(_Look l, String text, {Color? color, double size = 10}) =>
      Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color ?? l.accent,
          fontFamily: kFontMono,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      );

  // ----- archetypes -----

  /// The classic: emblem, who/when, the words, then the score.
  Widget _centered(_Look l) => _fit(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mark(l, 34),
          _gap(l, 16),
          _meta(l),
          _gap(l, 16),
          _titleText(l, 27),
          if (showDescription) ...[_gap(l, 12), _descText(l)],
          if (showStats && _hasStat) ...[_gap(l, 16), _stat(l)],
        ],
      ),
    ),
  );

  /// The postcard: the sentence first, almost nothing else.
  Widget _minimal(_Look l) => _fit(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mark(l, 22),
          _gap(l, 26),
          _titleText(l, 31),
          if (showDescription) ...[_gap(l, 16), _descText(l)],
          if (data.isReflection) ...[_gap(l, 16), _meta(l)],
          if (showStats && _hasStat) ...[_gap(l, 22), _stat(l)],
        ],
      ),
    ),
  );

  /// One number, as large as it gets.
  Widget _heroLayout(_Look l) {
    final (value, caption) = _hero;
    final goal = subject == ShareSubject.goal;
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _titleText(l, 18, maxLines: 2),
          ),
        ),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: l.accent,
                    fontFamily: kFontMono,
                    fontWeight: FontWeight.w700,
                    fontSize: 104 * l.k,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: l.accent.withValues(alpha: .4),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                ),
                _gap(l, 8),
                Text(
                  caption,
                  style: TextStyle(
                    color: l.foreground,
                    fontSize: 16 * l.k,
                    letterSpacing: .3,
                  ),
                ),
                if (goal) ...[
                  _gap(l, 16),
                  SizedBox(
                    width: 170,
                    height: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          ColoredBox(
                            color: l.foreground.withValues(alpha: .15),
                            child: const SizedBox.expand(),
                          ),
                          FractionallySizedBox(
                            widthFactor: data.total == null || data.total == 0
                                ? 0
                                : ((data.completed ?? 0) / data.total!).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            child: ColoredBox(
                              color: l.accent,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 26),
            child: _meta(l),
          ),
        ),
      ],
    );
  }

  /// A recap grid: tiles that are lit or not, and what they add up to.
  Widget _tilesLayout(_Look l) {
    final habit = subject == ShareSubject.habit;
    final cols = habit ? 7 : 4;
    final total = data.total ?? 0;
    final lit = data.completed ?? 0;
    final size = (habit ? 38.0 : 56.0) * (l.compact ? .8 : 1);
    return _fit(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _meta(l, type: true),
          _gap(l, 18),
          SizedBox(
            width: cols * size + (cols - 1) * 6,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < total; i++)
                  _Tile(
                    size: size,
                    lit: i < lit,
                    last: i == lit - 1,
                    accent: l.accent,
                    unlit: l.foreground,
                  ),
              ],
            ),
          ),
          _gap(l, 18),
          Text(
            '$lit',
            style: TextStyle(
              color: l.foreground,
              fontFamily: kFontMono,
              fontWeight: FontWeight.w700,
              fontSize: 42 * l.k,
              height: 1,
            ),
          ),
          _gap(l, 4),
          Text(
            data.heroCaption ?? '',
            style: TextStyle(color: l.secondary, fontSize: 12 * l.k),
          ),
          _gap(l, 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _titleText(l, 18, maxLines: 2),
          ),
        ],
      ),
    );
  }

  /// Typography only. Variant 1 is the centred "poster" with rules.
  Widget _poster(_Look l, int variant) {
    final quote = subject == ShareSubject.quote;
    if (variant == 1) {
      return _fit(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoMode == _PhotoMode.integrated) ...[
                _roundPhoto(l, 34),
                _gap(l, 20),
              ],
              _rule(l),
              _gap(l, 26),
              _titleText(l, 40, maxLines: 6),
              _gap(l, 26),
              _rule(l),
              if (showDescription) ...[
                _gap(l, 18),
                _monoLabel(l, _description, color: l.secondary, size: 10),
              ],
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showType)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _monoLabel(l, _typeLabel),
                  _gap(l, 8),
                  _rule(l, width: 34),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: _fit(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoMode == _PhotoMode.integrated) ...[
                    _roundPhoto(l, 34),
                    _gap(l, 20),
                  ] else if (quote)
                    Text(
                      '“',
                      style: TextStyle(
                        color: l.accent,
                        fontFamily: kFontBranding,
                        fontSize: 96 * l.k,
                        height: .7,
                      ),
                    ),
                  _titleText(
                    l,
                    quote ? 34 : 38,
                    align: TextAlign.left,
                    maxLines: 6,
                  ),
                  if (showDescription) ...[
                    _gap(l, 16),
                    quote
                        ? _monoLabel(
                            l,
                            '— $_description',
                            color: l.secondary,
                            size: 11,
                          )
                        : _descText(l, align: TextAlign.left),
                  ],
                  if (showDate || showArea || showProject) ...[
                    _gap(l, 16),
                    _meta(l, align: CrossAxisAlignment.start, type: false),
                  ],
                ],
              ),
              alignment: Alignment.bottomLeft,
            ),
          ),
        ),
      ],
    );
  }

  /// Magazine layouts: 1 side rule, 2 oversized chapter number, 3 masthead.
  Widget _editorial(_Look l, int variant) {
    switch (variant) {
      case 1:
        return _fit(
          Container(
            padding: const EdgeInsets.only(left: 18),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: l.accent, width: 2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photoMode == _PhotoMode.integrated) ...[
                  _roundPhoto(l, 34),
                  _gap(l, 20),
                ],
                _meta(l, align: CrossAxisAlignment.start),
                _gap(l, 14),
                _titleText(l, 29, align: TextAlign.left, maxLines: 6),
                if (showDescription) ...[
                  _gap(l, 14),
                  _descText(l, align: TextAlign.left),
                ],
              ],
            ),
          ),
          alignment: Alignment.centerLeft,
        );
      case 2:
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                '01',
                style: TextStyle(
                  color: l.foreground.withValues(alpha: .1),
                  fontFamily: kFontMono,
                  fontWeight: FontWeight.w700,
                  fontSize: 150 * l.k,
                  height: .9,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: _fit(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 1,
                        color: l.foreground.withValues(alpha: .25),
                      ),
                      _gap(l, 14),
                      _monoLabel(l, _typeLabel),
                      _gap(l, 10),
                      _titleText(l, 31, align: TextAlign.left, maxLines: 5),
                      if (showDescription) ...[
                        _gap(l, 12),
                        _descText(l, align: TextAlign.left),
                      ],
                      if (showDate) ...[
                        _gap(l, 14),
                        _meta(l, align: CrossAxisAlignment.start, type: false),
                      ],
                    ],
                  ),
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),
          ],
        );
      default:
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 1,
                      color: l.accent.withValues(alpha: .7),
                    ),
                    const SizedBox(width: 10),
                    _monoLabel(l, _typeLabel),
                    const SizedBox(width: 10),
                    Container(
                      width: 26,
                      height: 1,
                      color: l.accent.withValues(alpha: .7),
                    ),
                  ],
                ),
              ),
            ),
            _fit(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (photoMode == _PhotoMode.integrated) ...[
                      _roundPhoto(l, 34),
                      _gap(l, 20),
                    ],
                    _titleText(l, 33, maxLines: 6),
                    _gap(l, 20),
                    _rule(l, width: 34),
                    if (showDescription) ...[_gap(l, 18), _descText(l)],
                  ],
                ),
              ),
            ),
            if (showDate || showArea || showProject)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: _meta(l, type: false),
                ),
              ),
          ],
        );
    }
  }

  /// A framed print, slightly tilted, with a strip of tape.
  Widget _polaroid(_Look l) => _fit(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FractionallySizedBox(
          widthFactor: _moodboardCard ? .92 : .78,
          child: Transform.rotate(
            angle: -.04,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1E8),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x77000000),
                        blurRadius: 26,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child:
                            photoMode == _PhotoMode.integrated &&
                                data.photos.isNotEmpty
                            ? _photoAt(0)
                            : data.tiles.isNotEmpty
                            ? MoodboardContactSheet(tiles: data.tiles)
                            : Center(child: data.artwork ?? _mark(l, 38)),
                      ),
                      const SizedBox(height: 14),
                      _titleText(
                        l,
                        18,
                        align: TextAlign.left,
                        maxLines: 3,
                        color: const Color(0xFF28231D),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -9,
                  child: Transform.rotate(
                    angle: .07,
                    child: Container(
                      width: 70,
                      height: 20,
                      color: l.accent.withValues(alpha: .6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _gap(l, 30),
        _meta(l, stats: true),
      ],
    ),
  );

  /// Mosaic of photos above the words.
  Widget _collage(_Look l) {
    final mosaic = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: data.tiles.isNotEmpty
          ? MoodboardMosaic(tiles: data.tiles)
          : data.artwork ?? _photoAt(0),
    );
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _meta(l, align: CrossAxisAlignment.start),
        _gap(l, 10),
        _titleText(l, 27, align: TextAlign.left, maxLines: 4),
        if (showDescription) ...[
          _gap(l, 10),
          _descText(l, align: TextAlign.left, maxLines: 3),
        ],
      ],
    );
    if (l.compact) {
      return Row(
        children: [
          Expanded(flex: _moodboardCard ? 7 : 5, child: mosaic),
          const SizedBox(width: 22),
          Expanded(
            flex: 4,
            child: _fit(words, alignment: Alignment.centerLeft),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: _moodboardCard ? 8 : 6,
          child: Padding(
            padding: const EdgeInsets.only(top: 44),
            child: mosaic,
          ),
        ),
        SizedBox(height: _moodboardCard ? 12 : 20),
        Expanded(
          flex: _moodboardCard ? 2 : 4,
          child: _fit(words, alignment: Alignment.topLeft),
        ),
      ],
    );
  }

  /// Three staggered frames, words centred underneath.
  Widget _gallery(_Look l) {
    final frames = data.tiles.isNotEmpty
        ? MoodboardColumns(tiles: data.tiles)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: i == 1 ? 34 * l.k : 0,
                      bottom: i == 1 ? 0 : 34 * l.k,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _photoAt(i),
                    ),
                  ),
                ),
              ],
            ],
          );
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      children: [_titleText(l, 25, maxLines: 3), _gap(l, 10), _meta(l)],
    );
    if (l.compact) {
      return Row(
        children: [
          Expanded(flex: _moodboardCard ? 7 : 6, child: frames),
          const SizedBox(width: 22),
          Expanded(flex: 4, child: _fit(words)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: _moodboardCard ? 8 : 6,
          child: Padding(
            padding: const EdgeInsets.only(top: 44),
            child: frames,
          ),
        ),
        SizedBox(height: _moodboardCard ? 12 : 18),
        Expanded(
          flex: _moodboardCard ? 2 : 3,
          child: _fit(words, alignment: Alignment.topCenter),
        ),
      ],
    );
  }

  /// A drawn constellation fills the card.
  Widget _constellationLayout(_Look l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      Center(child: _meta(l)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
          child: data.artwork ?? const SizedBox.shrink(),
        ),
      ),
      Row(
        children: [
          if (photoMode == _PhotoMode.integrated) ...[
            _roundPhoto(l, 20),
            SizedBox(width: 12 * l.k),
          ],
          Expanded(child: _titleText(l, 28, maxLines: 3)),
        ],
      ),
      if (showDescription) ...[
        _gap(l, 10),
        _descText(l, size: 12, maxLines: 2),
      ],
      const SizedBox(height: 26),
    ],
  );
}

/// One cell of the recap grid: lit ones hold a small gold star, the most
/// recent one burns a little brighter, the rest stay flat.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.size,
    required this.lit,
    required this.last,
    required this.accent,
    required this.unlit,
  });
  final double size;
  final bool lit;
  final bool last;
  final Color accent;
  final Color unlit;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: lit
          ? accent.withValues(alpha: last ? .3 : .14)
          : unlit.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(8),
      boxShadow: last
          ? [BoxShadow(color: accent.withValues(alpha: .3), blurRadius: 10)]
          : null,
    ),
    child: lit
        ? _StarGlyph(size: size * (last ? .52 : .42), color: accent)
        : Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlit.withValues(alpha: .2),
            ),
          ),
  );
}

/// Text wrapped so its lines come out about the same length, without
/// changing how many lines it takes. Avoids a lone word on the last line.
class _BalancedText extends StatelessWidget {
  const _BalancedText(
    this.text, {
    required this.style,
    required this.textAlign,
    required this.maxLines,
  });
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      Widget plain(double? width) => Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
      final full = box.maxWidth;
      if (!full.isFinite) return plain(null);
      final direction = Directionality.of(context);
      // Measure with the same inherited style the Text will really use.
      final resolved = DefaultTextStyle.of(context).style.merge(style);
      int lines(double width) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: resolved),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: direction,
          textAlign: textAlign,
          maxLines: maxLines,
        )..layout(maxWidth: width);
        return painter.computeLineMetrics().length;
      }

      final target = lines(full);
      if (target < 2) return plain(null);
      var lo = full * .4;
      var hi = full;
      for (var i = 0; i < 12; i++) {
        final mid = (lo + hi) / 2;
        if (lines(mid) > target) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      final alignment = switch (textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        _ => Alignment.centerLeft,
      };
      return Align(
        alignment: alignment,
        heightFactor: 1,
        child: SizedBox(width: hi + 1, child: plain(hi)),
      );
    },
  );
}
