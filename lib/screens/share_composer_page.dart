part of 'share_composer_screen.dart';

/// Composer for the shareable picture of a victory, goal, habit, project,
/// vision, moodboard or quote.
///
/// The preview sits beside the selected category on wide screens and above
/// it on narrow screens. Every option is a stepper: arrows to flip through the choices,
/// or tap the value to see them all. Choices affect only the shared image.
class ShareComposerScreen extends StatefulWidget {
  const ShareComposerScreen({
    super.key,
    required this.data,
    this.variants,
    this.shareText = '',
    this.fileName = 'inner-stars.png',
  });
  final ShareContent data;
  final List<ShareContent>? variants;
  final String shareText;
  final String fileName;

  @override
  State<ShareComposerScreen> createState() => _ShareComposerScreenState();
}

/// A whole look in one tap: background, inks, brand and watermark together.
class _StylePreset {
  const _StylePreset(
    this.label, {
    required this.gradient,
    required this.palette,
    this.titleInk = _Ink.auto,
    this.brandInk = _Ink.auto,
    this.watermark = _Watermark.none,
    this.watermarkSize = _WatermarkSize.medium,
    this.brandContent = _BrandContent.name,
    this.brandPosition = _TitlePosition.topRight,
    this.brandLayout = _BrandLayout.logoLeft,
    this.logoDisc = true,
  });
  final String label;
  final _GradientShape gradient;
  final int palette;
  final _Ink titleInk;
  final _Ink brandInk;
  final _Watermark watermark;
  final _WatermarkSize watermarkSize;
  final _BrandContent brandContent;
  final _TitlePosition brandPosition;
  final _BrandLayout brandLayout;
  final bool logoDisc;
}

const _stylePresets = [
  _StylePreset('Classico', gradient: _GradientShape.halo, palette: 0),
  _StylePreset(
    'Dorato',
    gradient: _GradientShape.vertical,
    palette: 3,
    titleInk: _Ink.gold,
    brandInk: _Ink.gold,
    watermark: _Watermark.logo,
    brandContent: _BrandContent.both,
    brandPosition: _TitlePosition.bottomCenter,
  ),
  _StylePreset(
    'Carta',
    gradient: _GradientShape.diagonal,
    palette: 12,
    titleInk: _Ink.navy,
    brandInk: _Ink.navy,
    brandPosition: _TitlePosition.bottomCenter,
  ),
  _StylePreset(
    'Oceano',
    gradient: _GradientShape.radial,
    palette: 6,
    titleInk: _Ink.white,
    brandInk: _Ink.white,
    watermark: _Watermark.area,
    watermarkSize: _WatermarkSize.large,
    brandContent: _BrandContent.both,
    brandLayout: _BrandLayout.logoAbove,
    brandPosition: _TitlePosition.bottomCenter,
  ),
  _StylePreset(
    'Aurora',
    gradient: _GradientShape.conic,
    palette: 2,
    titleInk: _Ink.white,
    brandInk: _Ink.white,
    watermark: _Watermark.constellation,
    watermarkSize: _WatermarkSize.large,
    brandContent: _BrandContent.logo,
    brandPosition: _TitlePosition.topCenter,
    logoDisc: false,
  ),
  _StylePreset(
    'Minimale',
    gradient: _GradientShape.flat,
    palette: 11,
    titleInk: _Ink.white,
    brandInk: _Ink.gray,
    brandPosition: _TitlePosition.bottomCenter,
  ),
];

class _ShareComposerScreenState extends State<ShareComposerScreen> {
  int _category = 0;
  int _subjectIndex = 0;
  ShareContent get _data => widget.variants?[_subjectIndex] ?? widget.data;
  ShareSubject get _subject => _data.subject;
  late final _excerpt = TextEditingController(text: widget.data.description);
  List<int> get _availableCompositions => [
    for (var i = 0; i < _layoutMap[_subject]!.length; i++)
      if ((_layoutMap[_subject]![i].$1 != _Layout.hero ||
              _data.heroValue != null) &&
          (_layoutMap[_subject]![i].$1 != _Layout.tiles || _data.total != null))
        i,
  ];
  @override
  void dispose() {
    _excerpt.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _watermarkArea = _data.area?.index ?? 0;
  }

  int _composition = 0;
  _ShareFormat _format = _ShareFormat.story;

  // Style. [_style] is the applied preset, or null once anything was changed
  // by hand.
  int? _style = 0;
  _Ink _brandInk = _Ink.auto;
  _Ink _titleInk = _Ink.auto;

  // Background.
  _GradientShape _gradient = _GradientShape.halo;
  int _palette = 0;
  _PhotoMode _photoMode = _PhotoMode.none;

  // Text and data.
  _TitlePosition _titlePosition = _TitlePosition.bottomLeft;
  _BadgePosition _badgePosition = _BadgePosition.top;
  bool _showType = true;
  bool _showDate = true;
  bool _showArea = true;
  bool _showProject = true;
  bool _showDescription = true;
  bool _showStats = true;

  // Signature. A null ink follows the brand colour.
  _BrandContent _brandContent = _BrandContent.name;
  _LogoStyle _logoStyle = _LogoStyle.current;
  bool _logoDisc = true;
  _BrandLayout _brandLayout = _BrandLayout.logoLeft;
  _TitlePosition _brandPosition = _TitlePosition.topRight;
  _Ink? _nameInk;
  _Ink? _logoInk;
  _LogoSize _logoSize = _LogoSize.medium;

  // Watermark.
  _Watermark _watermark = _Watermark.none;
  _WatermarkSize _watermarkSize = _WatermarkSize.medium;
  int _watermarkArea = 0;
  _Ink? _watermarkInk;

  final _captureKey = GlobalKey();
  bool _sharing = false;

  /// A manual change: whatever preset was applied no longer describes it.
  void _edit(VoidCallback change) => setState(() {
    change();
    _style = null;
  });

  void _applyPreset(int index) {
    final s = _stylePresets[index];
    setState(() {
      _style = index;
      _gradient = s.gradient;
      _palette = s.palette;
      _titleInk = s.titleInk;
      _brandInk = s.brandInk;
      _nameInk = null;
      _logoInk = null;
      _watermarkInk = null;
      _watermark = s.watermark;
      _watermarkSize = s.watermarkSize;
      _brandContent = s.brandContent;
      _brandPosition = s.brandPosition;
      _brandLayout = s.brandLayout;
      _logoDisc = s.logoDisc;
      _logoStyle = _LogoStyle.current;
    });
  }

  bool get _freeLayout =>
      _layoutMap[_subject]![_availableCompositions[_composition]].$1 ==
      _Layout.free;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    ui.Image? capturedImage;
    try {
      for (final path in _data.photos) {
        final ImageProvider provider;
        if (PhotoStorage.isRemote(path)) {
          provider = NetworkImage(path);
        } else {
          final bytes = await _readSharePhoto(
            path,
            _subject == ShareSubject.moodboard,
          );
          if (bytes == null) throw StateError('Missing share photo');
          provider = MemoryImage(bytes);
        }
        if (!mounted) return;
        Object? imageError;
        await precacheImage(
          provider,
          context,
          onError: (error, stack) => imageError = error,
        );
        if (imageError != null) throw StateError('Could not load share photo');
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Preview is not ready');
      final image = await boundary.toImage(pixelRatio: 3);
      capturedImage = image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode the picture');
      if (!mounted) return;
      final origin = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          sharePositionOrigin: origin == null
              ? null
              : origin.localToGlobal(Offset.zero) & origin.size,
          text: widget.shareText,
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: widget.fileName,
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.shareContentError)),
        );
      }
    } finally {
      capturedImage?.dispose();
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _editExcerpt() async {
    final draft = TextEditingController(text: _excerpt.text);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(shareComposerLabel(context, 'Modifica estratto')),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: TextField(
              key: const ValueKey('share-excerpt-field'),
              controller: draft,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: context.strings.reflectionBodyLabel,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: context.colors.muted),
            child: AppButtonLabel(
              context.strings.cancel,
              color: context.colors.muted,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, draft.text),
            child: AppButtonLabel(context.strings.saveChanges),
          ),
        ],
      ),
    );
    // The dialog route animates out before releasing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    draft.dispose();
    if (value != null && mounted) setState(() => _excerpt.text = value);
  }

  Widget _specimen() => _ShareSpecimen(
    data: ShareContent(
      subject: _data.subject,
      title: _data.title,
      typeLabel: _data.typeLabel,
      description: _data.isReflection ? _excerpt.text : _data.description,
      area: _data.area,
      areaLabel: _data.areaLabel,
      projectLabel: _data.projectLabel,
      dateLabel: _data.dateLabel,
      statLabel: _data.statLabel,
      intensity: _data.intensity,
      artwork: _data.artwork,
      photos: _data.photos,
      heroValue: _data.heroValue,
      heroCaption: _data.heroCaption,
      total: _data.total,
      completed: _data.completed,
      isReflection: _data.isReflection,
    ),
    composition: _availableCompositions[_composition],
    gradient: _gradient,
    palette: _palette,
    format: _format,
    photoMode: _photoMode,
    titlePosition: _titlePosition,
    brandPosition: _brandPosition,
    badgePosition: _badgePosition,
    titleInk: _titleInk,
    watermark: _watermark,
    watermarkInk: _watermarkInk ?? _brandInk,
    watermarkSize: _watermarkSize,
    watermarkArea: _watermarkArea,
    brandContent: _brandContent,
    logoStyle: _logoStyle,
    logoDisc: _logoDisc,
    nameInk: _nameInk ?? _brandInk,
    logoInk: _logoInk ?? _brandInk,
    logoSize: _logoSize,
    brandLayout: _brandLayout,
    showType: _showType,
    showDate: _showDate,
    showArea: _showArea,
    showProject: _showProject,
    showDescription: _showDescription,
    showStats: _showStats,
  );

  // ----- blocks -----

  Widget _cardBlock() => _BlockCard(
    children: [
      if (widget.variants != null)
        _OptionStepper(
          fieldKey: 'scheda-contenuto',
          label: 'Contenuto',
          labels: [for (final item in widget.variants!) item.typeLabel],
          index: _subjectIndex,
          onChanged: (i) => _edit(() {
            _subjectIndex = i;
            _composition = 0;
            _excerpt.text = _data.description;
            _titlePosition = _subject == ShareSubject.quote
                ? _TitlePosition.center
                : _TitlePosition.bottomLeft;
          }),
        ),
      _OptionStepper(
        fieldKey: 'scheda-composizione',
        label: 'Composizione',
        labels: [
          for (final i in _availableCompositions)
            _compositionLabels(_subject)[i],
        ],
        index: _composition,
        onChanged: (i) => _edit(() => _composition = i),
      ),
      _VisualChoices(
        fieldKey: 'scheda-formato',
        label: 'Formato',
        labels: [for (final f in _ShareFormat.values) _formatLabel(f)],
        index: _format.index,
        columns: 5,
        showLabels: true,
        preview: (i) => Center(
          child: Container(
            width:
                24 *
                switch (_ShareFormat.values[i]) {
                  _ShareFormat.story => 2 / 3,
                  _ShareFormat.vertical => 9 / 16,
                  _ShareFormat.portrait => 4 / 5,
                  _ShareFormat.square => 1.0,
                  _ShareFormat.landscape => 16 / 9,
                },
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.text),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        onChanged: (i) => _edit(() => _format = _ShareFormat.values[i]),
      ),
    ],
  );

  Widget _styleBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'stile-preset',
        label: 'Stile',
        labels: [for (final p in _stylePresets) p.label],
        index: _style ?? 0,
        placeholder: _style == null ? 'Personalizzato' : null,
        columns: 3,
        showLabels: true,
        preview: (i) => Container(
          width: 36,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: _palettes[_stylePresets[i].palette].colors,
            ),
          ),
        ),
        onChanged: _applyPreset,
      ),
      _VisualChoices(
        fieldKey: 'stile-marchio',
        label: 'Marchio',
        labels: [for (final i in _Ink.values) _inkLabel(i)],
        preview: (i) => _InkDot(_Ink.values[i]),
        index: _brandInk.index,
        onChanged: (i) => _edit(() => _brandInk = _Ink.values[i]),
      ),
      _VisualChoices(
        fieldKey: 'stile-titolo',
        label: 'Titolo',
        labels: [for (final i in _Ink.values) _inkLabel(i)],
        preview: (i) => _InkDot(_Ink.values[i]),
        index: _titleInk.index,
        onChanged: (i) => _edit(() => _titleInk = _Ink.values[i]),
      ),
    ],
  );

  Widget _backgroundBlock() => _BlockCard(
    children: [
      _OptionStepper(
        fieldKey: 'sfondo-forma',
        label: 'Forma',
        labels: [for (final g in _GradientShape.values) _gradientLabel(g)],
        index: _gradient.index,
        onChanged: (i) => _edit(() => _gradient = _GradientShape.values[i]),
      ),
      _VisualChoices(
        fieldKey: 'sfondo-colori',
        label: 'Colori',
        labels: [for (final p in _palettes) p.label],
        preview: (i) => _PaletteDot(_palettes[i]),
        columns: 7,
        index: _palette,
        onChanged: (i) => _edit(() => _palette = i),
      ),
      if (_data.photos.isNotEmpty)
        _OptionStepper(
          fieldKey: 'sfondo-foto',
          label: 'Foto',
          labels: [for (final m in _PhotoMode.values) _photoLabel(m)],
          index: _photoMode.index,
          onChanged: (i) => _edit(() => _photoMode = _PhotoMode.values[i]),
        ),
    ],
  );

  Widget _textBlock() => _BlockCard(
    children: [
      if (_freeLayout)
        _PositionChoices(
          fieldKey: 'testo-posizione',
          label: 'Titolo',
          index: _titlePosition.index,
          onChanged: (i) =>
              _edit(() => _titlePosition = _TitlePosition.values[i]),
        ),
      if (_freeLayout)
        _OptionStepper(
          fieldKey: 'testo-badge',
          label: 'Badge',
          labels: const ['In Alto', 'In Basso'],
          index: _badgePosition.index,
          onChanged: (i) =>
              _edit(() => _badgePosition = _BadgePosition.values[i]),
        ),
      _Toggles(
        label: 'Elementi visibili',
        toggles: [
          ('Tipo', _showType, (v) => _edit(() => _showType = v)),
          if (_data.dateLabel != null)
            ('Data', _showDate, (v) => _edit(() => _showDate = v)),
          if (_data.areaLabel != null)
            ('Area', _showArea, (v) => _edit(() => _showArea = v)),
          if (_data.projectLabel != null)
            ('Progetto', _showProject, (v) => _edit(() => _showProject = v)),
          (
            _data.isReflection ? 'Testo' : 'Descrizione',
            _showDescription,
            (v) => _edit(() => _showDescription = v),
          ),
          if (_data.statLabel != null || _data.intensity != null)
            ('Statistiche', _showStats, (v) => _edit(() => _showStats = v)),
        ],
      ),
    ],
  );

  Widget _signatureBlock() {
    final hasLogo =
        _brandContent == _BrandContent.logo ||
        _brandContent == _BrandContent.both;
    final hasName =
        _brandContent == _BrandContent.name ||
        _brandContent == _BrandContent.both;
    // Signature layouts in one list: what is shown, and for logo and name
    // together, how they are arranged.
    const shown = [
      'Nessuna',
      'Solo Logo',
      'Solo Nome',
      'Logo e Nome',
      'Logo sopra Nome',
    ];
    final shownIndex = switch (_brandContent) {
      _BrandContent.none => 0,
      _BrandContent.logo => 1,
      _BrandContent.name => 2,
      _BrandContent.both => _brandLayout == _BrandLayout.logoLeft ? 3 : 4,
    };
    final inks = ['Come Marchio', for (final i in _Ink.values) _inkLabel(i)];
    return _BlockCard(
      children: [
        _OptionStepper(
          fieldKey: 'firma-mostra',
          label: 'Mostra',
          labels: shown,
          index: shownIndex,
          onChanged: (i) => _edit(() {
            _brandContent = const [
              _BrandContent.none,
              _BrandContent.logo,
              _BrandContent.name,
              _BrandContent.both,
              _BrandContent.both,
            ][i];
            if (i == 3) _brandLayout = _BrandLayout.logoLeft;
            if (i == 4) _brandLayout = _BrandLayout.logoAbove;
          }),
        ),
        if (_brandContent != _BrandContent.none)
          _PositionChoices(
            fieldKey: 'firma-posizione',
            label: 'Posizione',
            index: _brandPosition.index,
            onChanged: (i) =>
                _edit(() => _brandPosition = _TitlePosition.values[i]),
          ),
        if (hasLogo)
          _OptionStepper(
            fieldKey: 'firma-logo',
            label: 'Logo',
            labels: const ['Disco Pieno', 'Disco Invertito', 'Senza Disco'],
            index: !_logoDisc ? 2 : _logoStyle.index,
            onChanged: (i) => _edit(() {
              _logoDisc = i != 2;
              if (i != 2) _logoStyle = _LogoStyle.values[i];
            }),
          ),
        if (hasLogo)
          _OptionStepper(
            fieldKey: 'firma-misura',
            label: 'Misura Logo',
            labels: const ['Piccolo', 'Medio', 'Grande'],
            index: _logoSize.index,
            onChanged: (i) => _edit(() => _logoSize = _LogoSize.values[i]),
          ),
        if (hasLogo)
          _VisualChoices(
            fieldKey: 'firma-colore-logo',
            label: 'Colore Logo',
            labels: inks,
            preview: (i) => i == 0
                ? const Icon(Icons.link, size: 18)
                : _InkDot(_Ink.values[i - 1]),
            index: _logoInk == null ? 0 : _logoInk!.index + 1,
            onChanged: (i) =>
                _edit(() => _logoInk = i == 0 ? null : _Ink.values[i - 1]),
          ),
        if (hasName)
          _VisualChoices(
            fieldKey: 'firma-colore-nome',
            label: 'Colore Nome',
            labels: inks,
            preview: (i) => i == 0
                ? const Icon(Icons.link, size: 18)
                : _InkDot(_Ink.values[i - 1]),
            index: _nameInk == null ? 0 : _nameInk!.index + 1,
            onChanged: (i) =>
                _edit(() => _nameInk = i == 0 ? null : _Ink.values[i - 1]),
          ),
      ],
    );
  }

  Widget _watermarkBlock() {
    final on = _watermark != _Watermark.none;
    // The area artworks are part of the type list, one entry per area.
    final kinds = [
      for (final w in _Watermark.values)
        if (w != _Watermark.area) _watermarkLabel(w),
      for (final area in LifeArea.values)
        '${shareComposerLabel(context, 'Arte')} · ${area.displayName(context.strings)}',
    ];
    return _BlockCard(
      children: [
        _OptionStepper(
          fieldKey: 'watermark-tipo',
          label: 'Filigrana',
          labels: kinds,
          index: _watermark == _Watermark.area
              ? _Watermark.area.index + _watermarkArea
              : _watermark.index,
          onChanged: (i) => _edit(() {
            if (i >= _Watermark.area.index) {
              _watermark = _Watermark.area;
              _watermarkArea = i - _Watermark.area.index;
            } else {
              _watermark = _Watermark.values[i];
            }
          }),
        ),
        if (on)
          _OptionStepper(
            fieldKey: 'watermark-misura',
            label: 'Misura',
            labels: [
              for (final s in _WatermarkSize.values) _watermarkSizeLabel(s),
            ],
            index: _watermarkSize.index,
            onChanged: (i) =>
                _edit(() => _watermarkSize = _WatermarkSize.values[i]),
          ),
        if (on)
          _VisualChoices(
            fieldKey: 'watermark-colore',
            label: 'Colore',
            labels: ['Come Marchio', for (final i in _Ink.values) _inkLabel(i)],
            preview: (i) => i == 0
                ? const Icon(Icons.link, size: 18)
                : _InkDot(_Ink.values[i - 1]),
            index: _watermarkInk == null ? 0 : _watermarkInk!.index + 1,
            onChanged: (i) =>
                _edit(() => _watermarkInk = i == 0 ? null : _Ink.values[i - 1]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.night,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 1000 ||
                (constraints.maxWidth >= 650 && constraints.maxHeight < 600);
            // The same space separates preview, panels and the share button.
            const gap = 16.0;
            final gutter = wide ? 20.0 : 12.0;
            final preview = _PreviewPane(
              key: const ValueKey('share-preview'),
              format: _format,
              captureKey: _captureKey,
              padding: 0,
              specimen: _specimen(),
            );
            const categories = [
              ('Aspetto', Icons.palette_outlined),
              ('Contenuto', Icons.title_rounded),
              ('Sfondo', Icons.gradient_rounded),
              ('Firma', Icons.verified_outlined),
            ];
            final blocks = switch (_category) {
              0 => [_cardBlock(), _styleBlock()],
              1 => [_textBlock()],
              2 => [_backgroundBlock(), _watermarkBlock()],
              _ => [_signatureBlock()],
            };
            final controls = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < categories.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: _category == i,
                          child: TextButton(
                            key: ValueKey('share-category-$i'),
                            onPressed: () => setState(() => _category = i),
                            style: TextButton.styleFrom(
                              foregroundColor: _category == i
                                  ? colors.gold
                                  : colors.muted,
                              backgroundColor: _category == i
                                  ? colors.nightPanel
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(categories[i].$2, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  shareComposerLabel(context, categories[i].$1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      key: ValueKey('share-category-panel-$_category'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < blocks.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            blocks[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
            final body = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: preview),
                      const SizedBox(width: gap),
                      SizedBox(
                        width: (constraints.maxWidth * .42).clamp(320.0, 480.0),
                        child: controls,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: preview),
                      const SizedBox(height: gap),
                      SizedBox(
                        height: (constraints.maxHeight * .38).clamp(
                          240.0,
                          310.0,
                        ),
                        child: controls,
                      ),
                    ],
                  );
            return Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: body),
                  const SizedBox(height: gap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                        ),
                        child: AppButtonLabel(
                          context.strings.cancel,
                          color: colors.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _sharing ? null : _share,
                        child: AppButtonLabel(context.strings.shareNowAction),
                      ),
                      if (_data.isReflection)
                        IconButton(
                          key: const ValueKey('share-reflection-excerpt'),
                          tooltip: shareComposerLabel(
                            context,
                            'Modifica estratto',
                          ),
                          onPressed: _editExcerpt,
                          icon: const Icon(Icons.edit_note),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
// ----- labels -----

List<String> _compositionLabels(ShareSubject subject) => switch (subject) {
  ShareSubject.victory => const [
    'Celebrazione',
    'Traguardo',
    'Diario',
    'Essenziale',
    'Risultati',
  ],
  ShareSubject.goal => const [
    'Direzione',
    'Promessa',
    'Piano',
    'Essenziale',
    'Progresso',
  ],
  ShareSubject.habit => const [
    'Ritmo',
    'Serie',
    'Rituale',
    'Essenziale',
    'Statistiche',
  ],
  ShareSubject.project => const [
    'Costellazione',
    'Progresso',
    'Manifesto',
    'Mappa',
    'Statistiche',
  ],
  ShareSubject.vision => const [
    'Manifesto',
    'Estratto',
    'Capitolo',
    'Editoriale',
    'Essenziale',
  ],
  ShareSubject.moodboard => const [
    'Collage',
    'Copertina',
    'Galleria',
    'Polaroid',
    'Editoriale',
  ],
  ShareSubject.quote => const [
    'Tipografica',
    'Celestiale',
    'Minimale',
    'Editoriale',
    'Poster',
  ],
};

String _gradientLabel(_GradientShape value) => switch (value) {
  _GradientShape.halo => 'Alone',
  _GradientShape.radial => 'Radiale',
  _GradientShape.vertical => 'Verticale',
  _GradientShape.diagonal => 'Diagonale',
  _GradientShape.conic => 'Conico',
  _GradientShape.mirrored => 'Riflesso',
  _GradientShape.flat => 'Piatto',
};

String _inkLabel(_Ink value) => switch (value) {
  _Ink.auto => 'Auto',
  _Ink.gold => 'Oro',
  _Ink.white => 'Bianco',
  _Ink.navy => 'Navy',
  _Ink.gray => 'Grigio',
};

String _watermarkSizeLabel(_WatermarkSize value) => switch (value) {
  _WatermarkSize.small => 'Piccolo',
  _WatermarkSize.medium => 'Medio',
  _WatermarkSize.large => 'Grande',
};

String _formatLabel(_ShareFormat value) => switch (value) {
  _ShareFormat.story => 'Story · 2:3',
  _ShareFormat.vertical => 'Story · 9:16',
  _ShareFormat.portrait => 'Post · 4:5',
  _ShareFormat.square => 'Quadrato · 1:1',
  _ShareFormat.landscape => 'Orizzontale · 16:9',
};

String _photoLabel(_PhotoMode value) => switch (value) {
  _PhotoMode.none => 'Senza Foto',
  _PhotoMode.background => 'Foto di Sfondo',
  _PhotoMode.panel => 'Pannello Foto',
  _PhotoMode.circle => 'Foto Tonda',
};

String _watermarkLabel(_Watermark value) => switch (value) {
  _Watermark.none => 'Nessuno',
  _Watermark.logo => 'Logo App',
  _Watermark.sparkle => 'Scintilla',
  _Watermark.constellation => 'Costellazione',
  _Watermark.area => 'Arte Area',
};

String _positionLabel(_TitlePosition value) => switch (value) {
  _TitlePosition.topLeft => 'Alto Sinistra',
  _TitlePosition.topCenter => 'Alto Centro',
  _TitlePosition.topRight => 'Alto Destra',
  _TitlePosition.centerLeft => 'Metà Sinistra',
  _TitlePosition.center => 'Centro',
  _TitlePosition.centerRight => 'Metà Destra',
  _TitlePosition.bottomLeft => 'Basso Sinistra',
  _TitlePosition.bottomCenter => 'Basso Centro',
  _TitlePosition.bottomRight => 'Basso Destra',
};

// ----- control widgets -----

/// A group of related controls, separated without repeating category titles.
class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.nightBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        ],
      ),
    );
  }
}

/// A compact label and value. Composition also supports quick stepping.
class _OptionStepper extends StatelessWidget {
  const _OptionStepper({
    required this.fieldKey,
    required this.label,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  /// Stable id, used to key the arrows (tests, semantics).
  final String fieldKey;
  final String label;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  void _step(int delta) =>
      onChanged((index + delta + labels.length) % labels.length);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelText = Text(
      shareComposerLabel(context, label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.supporting.copyWith(fontSize: 12),
    );
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(flex: 4, child: labelText),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: Row(
              children: [
                if (fieldKey == 'scheda-composizione')
                  _ArrowButton(
                    key: ValueKey('$fieldKey-prev'),
                    icon: Icons.chevron_left_rounded,
                    tooltip: shareComposerLabel(context, 'Precedente'),
                    onTap: () => _step(-1),
                  ),
                Expanded(
                  child: PopupMenuButton<int>(
                    key: ValueKey('$fieldKey-menu'),
                    tooltip: shareComposerLabel(context, label),
                    initialValue: index,
                    onSelected: onChanged,
                    color: colors.nightPanel,
                    surfaceTintColor: Colors.transparent,
                    elevation: 8,
                    position: PopupMenuPosition.under,
                    constraints: const BoxConstraints(minWidth: 170),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusField),
                      side: BorderSide(color: colors.nightBorder),
                    ),
                    itemBuilder: (context) => [
                      for (var i = 0; i < labels.length; i++)
                        PopupMenuItem<int>(
                          value: i,
                          height: 48,
                          child: _ValueRow(
                            text: shareComposerLabel(context, labels[i]),
                            selected: i == index,
                            trailingCheck: true,
                          ),
                        ),
                    ],
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      decoration: selectableDecoration(colors, selected: false),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ValueRow(
                              text: shareComposerLabel(context, labels[index]),
                              selected: false,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: colors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (fieldKey == 'scheda-composizione')
                  _ArrowButton(
                    key: ValueKey('$fieldKey-next'),
                    icon: Icons.chevron_right_rounded,
                    tooltip: shareComposerLabel(context, 'Successivo'),
                    onTap: () => _step(1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Direct visual choices with accessible names and a persistent selected label.
class _VisualChoices extends StatelessWidget {
  const _VisualChoices({
    required this.fieldKey,
    required this.label,
    required this.labels,
    required this.index,
    required this.preview,
    required this.onChanged,
    this.columns = 6,
    this.showLabels = false,
    this.showHeader = true,
    this.placeholder,
  });
  final String fieldKey;
  final String label;
  final List<String> labels;
  final int index;
  final Widget Function(int) preview;
  final ValueChanged<int> onChanged;
  final int columns;
  final bool showLabels;
  final bool showHeader;
  final String? placeholder;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showHeader)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${shareComposerLabel(context, label)} · ${shareComposerLabel(context, placeholder ?? labels[index])}',
            style: context.typography.supporting.copyWith(fontSize: 12),
          ),
        ),
      LayoutBuilder(
        builder: (context, constraints) {
          final count = columns.clamp(
            1,
            (constraints.maxWidth / 48).floor().clamp(1, columns),
          );
          final width = (constraints.maxWidth - (count - 1) * 6) / count;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < labels.length; i++)
                Semantics(
                  button: true,
                  selected: i == index && placeholder == null,
                  label: shareComposerLabel(context, labels[i]),
                  child: Tooltip(
                    message: shareComposerLabel(context, labels[i]),
                    child: InkWell(
                      key: ValueKey('$fieldKey-$i'),
                      onTap: () => onChanged(i),
                      borderRadius: BorderRadius.circular(kRadiusField),
                      child: Container(
                        width: width,
                        height: showLabels ? 72 : 44,
                        decoration: selectableDecoration(
                          context.colors,
                          selected: i == index && placeholder == null,
                        ),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 26,
                                child: Center(child: preview(i)),
                              ),
                              if (showLabels) ...[
                                const SizedBox(height: 4),
                                Text(
                                  shareComposerLabel(context, labels[i]),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.controlLabel
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _PositionChoices extends StatelessWidget {
  const _PositionChoices({
    required this.fieldKey,
    required this.label,
    required this.index,
    required this.onChanged,
  });
  final String fieldKey;
  final String label;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '${shareComposerLabel(context, label)}\n${shareComposerLabel(context, _positionLabel(_TitlePosition.values[index]))}',
          style: context.typography.supporting.copyWith(fontSize: 12),
        ),
      ),
      SizedBox(
        width: 144,
        child: _VisualChoices(
          fieldKey: fieldKey,
          label: label,
          labels: [for (final p in _TitlePosition.values) _positionLabel(p)],
          index: index,
          columns: 3,
          showHeader: false,
          onChanged: onChanged,
          preview: (i) => Padding(
            padding: const EdgeInsets.all(5),
            child: Align(
              alignment: Alignment(
                (i % 3 - 1).toDouble(),
                (i ~/ 3 - 1).toDouble(),
              ),
              child: Container(
                width: 10,
                height: 4,
                color: context.colors.text,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.text,
    required this.selected,
    this.trailingCheck = false,
  });
  final String text;
  final bool selected;
  final bool trailingCheck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.controlLabel.copyWith(
              fontSize: 12.5,
              color: selected ? colors.gold : colors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (trailingCheck && selected)
          Icon(Icons.check_rounded, size: 16, color: colors.gold),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 22, color: context.colors.muted),
      ),
    ),
  );
}

/// Explicit switches for the elements included in the shared image.
class _Toggles extends StatelessWidget {
  const _Toggles({required this.label, required this.toggles});
  final String label;
  final List<(String, bool, ValueChanged<bool>)> toggles;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 16,
        child: Text(
          shareComposerLabel(context, label),
          style: context.typography.supporting.copyWith(fontSize: 12),
        ),
      ),
      const SizedBox(height: 4),
      for (final toggle in toggles)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            shareComposerLabel(context, toggle.$1),
            style: context.typography.controlLabel,
          ),
          value: toggle.$2,
          onChanged: toggle.$3,
        ),
    ],
  );
}

Color? _inkDotColor(AppColors colors, _Ink ink) => switch (ink) {
  _Ink.auto => null,
  _Ink.gold => colors.gold,
  _Ink.white => const Color(0xFFF4F1E8),
  _Ink.navy => const Color(0xFF7C8FC4),
  _Ink.gray => colors.muted,
};

/// A colour dot for an ink option (a hollow ring for Auto).
class _InkDot extends StatelessWidget {
  const _InkDot(this.ink);
  final _Ink ink;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _inkDotColor(colors, ink);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: color == null
            ? Border.all(color: colors.muted, width: 1.5)
            : null,
      ),
    );
  }
}

/// A small preview of a background palette.
class _PaletteDot extends StatelessWidget {
  const _PaletteDot(this.palette);
  final _Palette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: context.colors.nightBorder),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette.colors,
      ),
    ),
  );
}
