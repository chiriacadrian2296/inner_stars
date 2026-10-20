part of 'share_composer_screen.dart';

/// Composer for the shareable picture of a victory, goal, habit, project,
/// vision, moodboard or quote.
///
/// The preview sits beside one scrolling editor on wide screens and above
/// it on narrow screens. Choices affect only the shared image.
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
    this.brandInk = _Ink.auto,
    this.watermark = _Watermark.none,
  });
  final String label;
  final _GradientShape gradient;
  final int palette;
  final _Ink brandInk;
  final _Watermark watermark;
}

const _stylePresets = [
  _StylePreset('Classico', gradient: _GradientShape.halo, palette: 0),
  _StylePreset(
    'Dorato',
    gradient: _GradientShape.vertical,
    palette: 3,
    brandInk: _Ink.gold,
    watermark: _Watermark.logo,
  ),
];

class _ShareComposerScreenState extends State<ShareComposerScreen> {
  final _controlsScroll = ScrollController();
  int _subjectIndex = 0;
  ShareContent get _data => widget.variants?[_subjectIndex] ?? widget.data;
  ShareSubject get _subject => _data.subject;
  late final _excerpt = TextEditingController(text: widget.data.description);
  @override
  void dispose() {
    _controlsScroll.dispose();
    _excerpt.dispose();
    super.dispose();
  }

  int _composition = 0;
  _ShareFormat _format = _ShareFormat.story;

  // Style. [_style] is the applied preset, or null once anything was changed
  // by hand.
  int? _style = 0;
  _Ink _brandInk = _Ink.auto;

  // Background.
  _GradientShape _gradient = _GradientShape.halo;
  int _palette = 0;
  bool _reverseColors = false;
  _PhotoMode _photoMode = _PhotoMode.none;

  // Signature colors are linked to the title and watermark.
  _BrandContent _brandContent = _BrandContent.both;
  _BrandLayout _brandLayout = _BrandLayout.logoLeft;

  // Watermark.
  _Watermark _watermark = _Watermark.none;
  _WatermarkSize _watermarkSize = _WatermarkSize.medium;
  int get _watermarkArea => _data.area?.index ?? 0;
  _Watermark get _effectiveWatermark =>
      _watermark == _Watermark.area && _data.area == null
      ? _Watermark.none
      : _watermark;

  final _captureKey = GlobalKey();
  bool _sharing = false;

  final _undo = <VoidCallback>[];
  final _redo = <VoidCallback>[];

  // Capture the complete draft together, including preset and subject changes.
  VoidCallback _snapshot() {
    final draft = (
      subject: _subjectIndex,
      composition: _composition,
      format: _format,
      style: _style,
      brandInk: _brandInk,
      gradient: _gradient,
      palette: _palette,
      reverseColors: _reverseColors,
      photoMode: _photoMode,
      brandContent: _brandContent,
      brandLayout: _brandLayout,
      watermark: _watermark,
      watermarkSize: _watermarkSize,
      excerpt: _excerpt.text,
    );
    return () {
      _subjectIndex = draft.subject;
      _composition = draft.composition;
      _format = draft.format;
      _style = draft.style;
      _brandInk = draft.brandInk;
      _gradient = draft.gradient;
      _palette = draft.palette;
      _reverseColors = draft.reverseColors;
      _photoMode = draft.photoMode;
      _brandContent = draft.brandContent;
      _brandLayout = draft.brandLayout;
      _watermark = draft.watermark;
      _watermarkSize = draft.watermarkSize;
      _excerpt.text = draft.excerpt;
    };
  }

  void _change(VoidCallback change) => setState(() {
    _undo.add(_snapshot());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
    change();
  });

  void _travel(List<VoidCallback> from, List<VoidCallback> to) => setState(() {
    to.add(_snapshot());
    from.removeLast()();
  });

  /// A manual change: whatever preset was applied no longer describes it.
  void _edit(VoidCallback change) => _change(() {
    change();
    _style = null;
  });

  void _applyPreset(int index) {
    final s = _stylePresets[index];
    if (_style == index) return;
    _change(() {
      _style = index;
      _gradient = s.gradient;
      _palette = s.palette;
      _reverseColors = false;
      _brandInk = s.brandInk;
      _watermark = s.watermark;
    });
  }

  _TitlePosition _signaturePosition(int composition) =>
      switch (_layoutMap[_subject]![composition].$1) {
        _Layout.free || _Layout.poster => _TitlePosition.topRight,
        _ => _TitlePosition.bottomCenter,
      };

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
    if (value != null && mounted && value != _excerpt.text) {
      _change(() => _excerpt.text = value);
    }
  }

  Widget _specimen({int? composition}) => _ShareSpecimen(
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
    composition: composition ?? _composition,
    gradient: _gradient,
    reverseColors: _reverseColors,
    palette: _palette,
    format: _format,
    photoMode: _photoMode,
    titlePosition: _TitlePosition.bottomLeft,
    brandPosition: _signaturePosition(composition ?? _composition),
    badgePosition: _BadgePosition.top,
    titleInk: _brandInk,
    watermark: _effectiveWatermark,
    watermarkInk: _brandInk,
    watermarkSize: _watermarkSize,
    watermarkArea: _watermarkArea,
    brandContent: _brandContent,
    logoStyle: _LogoStyle.current,
    logoDisc: false,
    nameInk: _brandInk,
    logoInk: _brandInk,
    logoSize: _LogoSize.small,
    brandLayout: _brandLayout,
    showType: true,
    showDate: true,
    showArea: true,
    showProject: true,
    showDescription: true,
    showStats: true,
  );

  // ----- blocks -----

  Widget _note(String text) => Text(
    shareComposerLabel(context, text),
    style: context.typography.supporting.copyWith(
      color: context.colors.muted,
      fontSize: 12,
      height: 1.4,
    ),
  );

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
          }),
        ),
      _VisualChoices(
        fieldKey: 'scheda-composizione',
        label: 'Composizione',
        labels: _compositionLabels(_subject),
        index: _composition,
        columns: 3,
        showLabels: true,
        previewHeight: 90,
        preview: (i) => FittedBox(
          child: SizedBox(
            width: _format == _ShareFormat.landscape ? 640 : 360,
            height:
                (_format == _ShareFormat.landscape ? 640 : 360) /
                _shareAspectRatio(_format),
            child: MediaQuery.withNoTextScaling(
              child: _specimen(composition: i),
            ),
          ),
        ),
        onChanged: (i) => _edit(() => _composition = i),
      ),
      _VisualChoices(
        fieldKey: 'scheda-formato',
        label: 'Formato',
        labels: [for (final f in _ShareFormat.values) _formatLabel(f)],
        index: _format.index,
        columns: 5,
        minItemWidth: 64,
        singleRow: true,
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
        label: 'Stili pronti',
        labels: [for (final p in _stylePresets) p.label],
        index: _style ?? 0,
        placeholder: _style == null ? 'Personalizzato' : null,
        columns: 2,
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
      _note('Gli stili pronti cambiano sfondo, colore condiviso e filigrana.'),
    ],
  );

  Widget _backgroundBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'sfondo-forma',
        label: 'Forma',
        labels: [for (final g in _GradientShape.values) _gradientLabel(g)],
        index: _gradient.index,
        columns: 4,
        previewHeight: 64,
        preview: (i) => SizedBox(
          width: 56,
          height: 64,
          child: Center(
            child: AspectRatio(
              aspectRatio: _shareAspectRatio(_format),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.colors.nightBorder),
                  gradient: _backgroundGradient(
                    _GradientShape.values[i],
                    _palettes[_palette],
                    reversed: _reverseColors,
                  ),
                ),
              ),
            ),
          ),
        ),
        onChanged: (i) => _edit(() => _gradient = _GradientShape.values[i]),
      ),
      _VisualChoices(
        fieldKey: 'sfondo-colori',
        label: 'Colori',
        labels: [for (final p in _palettes) p.label],
        preview: (i) => _PaletteDot(_palettes[i], reversed: _reverseColors),
        columns: 7,
        index: _palette,
        onChanged: (i) => _edit(() => _palette = i),
      ),
      Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppChoiceChip(
            key: const ValueKey('share-reverse-colors'),
            label: shareComposerLabel(context, 'Inverti colori'),
            icon: Icons.swap_vert_rounded,
            selected: _reverseColors,
            dense: true,
            onPressed: () => _edit(() => _reverseColors = !_reverseColors),
          ),
        ),
      ),
      if (_data.photos.isNotEmpty)
        _OptionStepper(
          fieldKey: 'sfondo-foto',
          label: 'Foto',
          labels: [for (final m in _PhotoMode.values) _photoLabel(m)],
          index: _photoMode.index,
          onChanged: (i) => _edit(() => _photoMode = _PhotoMode.values[i]),
        )
      else
        _note('Questo contenuto non contiene foto.'),
    ],
  );

  Widget _textBlock() => _BlockCard(
    children: [
      if (_data.isReflection)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('share-reflection-excerpt'),
            onPressed: _editExcerpt,
            child: Text(shareComposerLabel(context, 'Modifica estratto')),
          ),
        ),
    ],
  );

  Widget _signatureBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'firma-disposizione',
        label: 'Disposizione',
        labels: const ['Solo Logo', 'Logo e Nome', 'Logo sopra Nome'],
        index: _brandContent == _BrandContent.logo
            ? 0
            : _brandLayout == _BrandLayout.logoLeft
            ? 1
            : 2,
        columns: 3,
        previewHeight: 44,
        preview: (i) {
          final color =
              _inkDotColor(context.colors, _brandInk) ?? context.colors.text;
          final logo = SvgPicture.asset(
            'assets/icon/Logo.svg',
            width: 20,
            height: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          );
          final name = Text(
            'Inner Stars',
            style: TextStyle(
              fontFamily: kFontBranding,
              fontSize: 10,
              color: color,
            ),
          );
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: switch (i) {
              0 => logo,
              1 => Row(
                mainAxisSize: MainAxisSize.min,
                children: [logo, const SizedBox(width: 4), name],
              ),
              _ => Column(
                mainAxisSize: MainAxisSize.min,
                children: [logo, const SizedBox(height: 4), name],
              ),
            },
          );
        },
        onChanged: (i) => _edit(() {
          _brandContent = i == 0 ? _BrandContent.logo : _BrandContent.both;
          _brandLayout = i == 2
              ? _BrandLayout.logoAbove
              : _BrandLayout.logoLeft;
        }),
      ),
    ],
  );

  Widget _linkedColorBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'colore-elementi',
        label: 'Colore',
        labels: [for (final ink in _Ink.values) _inkLabel(ink)],
        index: _brandInk.index,
        columns: 5,
        preview: (i) => _InkDot(_Ink.values[i]),
        onChanged: (i) => _edit(() => _brandInk = _Ink.values[i]),
      ),
    ],
  );
  Widget _watermarkBlock() {
    final on = _effectiveWatermark != _Watermark.none;
    final kinds = [
      _Watermark.none,
      _Watermark.logo,
      if (_data.area != null) _Watermark.area,
    ];
    return _BlockCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _VisualChoices(
                fieldKey: 'watermark-tipo',
                label: 'Filigrana',
                labels: [for (final kind in kinds) _watermarkLabel(kind)],
                index: kinds.indexOf(_effectiveWatermark),
                columns: 3,
                singleRow: true,
                previewHeight: 32,
                preview: (i) => switch (kinds[i]) {
                  _Watermark.none => Icon(
                    Icons.block_rounded,
                    color: context.colors.muted,
                  ),
                  _Watermark.logo => SvgPicture.asset(
                    'assets/icon/Logo.svg',
                    width: 28,
                    height: 28,
                    colorFilter: ColorFilter.mode(
                      context.colors.gold,
                      BlendMode.srcIn,
                    ),
                  ),
                  _Watermark.area => Image.asset(
                    kAreaHeroArt[_data.area]!.coverAsset,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    color: context.colors.gold,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                },
                onChanged: (i) => _edit(() => _watermark = kinds[i]),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      shareComposerLabel(context, 'Misura'),
                      style: context.typography.supporting.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: selectableDecoration(
                      context.colors,
                      selected: false,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_WatermarkSize>(
                        key: const ValueKey('watermark-misura-menu'),
                        value: _watermarkSize,
                        isExpanded: true,
                        dropdownColor: context.colors.nightPanel,
                        style: context.typography.controlLabel.copyWith(
                          fontSize: 12,
                        ),
                        items: [
                          for (final size in _WatermarkSize.values)
                            DropdownMenuItem(
                              value: size,
                              child: Text(
                                shareComposerLabel(
                                  context,
                                  _watermarkSizeLabel(size),
                                ),
                              ),
                            ),
                        ],
                        onChanged: on
                            ? (value) {
                                if (value != null && value != _watermarkSize) {
                                  _edit(() => _watermarkSize = value);
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_data.area == null)
          _note('Artwork non disponibile: questo contenuto non ha un’area.'),
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
              ('Scheda', Icons.dashboard_customize_outlined),
              ('Contenuto', Icons.title_rounded),
              ('Sfondo', Icons.gradient_rounded),
              ('Firma', Icons.verified_outlined),
              ('Colore elementi', Icons.palette_outlined),
            ];
            const descriptions = [
              'Scegli la composizione e il formato, oppure applica uno stile pronto.',
              'Titolo, informazioni e posizioni sono definiti dalla composizione.',
              'Personalizza sfumatura, foto e filigrana.',
              'Scegli come mostrare il logo e il nome di Inner Stars.',
              'Un solo colore per titolo, logo, nome e filigrana.',
            ];
            final sections = [
              [_cardBlock(), _styleBlock()],
              [_textBlock()],
              [_backgroundBlock(), _watermarkBlock()],
              [_signatureBlock()],
              [_linkedColorBlock()],
            ];
            final history = SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const ValueKey('share-undo'),
                    tooltip: shareComposerLabel(context, 'Annulla modifica'),
                    color: colors.gold,
                    disabledColor: colors.muted,
                    onPressed: _undo.isEmpty
                        ? null
                        : () => _travel(_undo, _redo),
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('share-redo'),
                    tooltip: shareComposerLabel(context, 'Ripristina modifica'),
                    color: colors.gold,
                    disabledColor: colors.muted,
                    onPressed: _redo.isEmpty
                        ? null
                        : () => _travel(_redo, _undo),
                    icon: const Icon(Icons.redo_rounded),
                  ),
                ],
              ),
            );
            final controls = ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                controller: _controlsScroll,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  key: const ValueKey('share-controls'),
                  controller: _controlsScroll,
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < categories.length; i++) ...[
                        if (i > 0) const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Row(
                                  key: ValueKey('share-section-$i'),
                                  children: [
                                    Icon(
                                      categories[i].$2,
                                      size: 20,
                                      color: colors.gold,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      shareComposerLabel(
                                        context,
                                        categories[i].$1,
                                      ),
                                      style: context
                                          .typography
                                          .compactSectionLabel
                                          .copyWith(fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _note(descriptions[i]),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        for (var j = 0; j < sections[i].length; j++) ...[
                          if (j > 0) const SizedBox(height: 10),
                          sections[i][j],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
            final body = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: preview),
                            history,
                          ],
                        ),
                      ),
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
                      history,
                      SizedBox(
                        height:
                            (constraints.maxHeight * .38).clamp(240.0, 310.0) -
                            48 +
                            gap,
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
                      ElevatedButton(
                        onPressed: _sharing ? null : _share,
                        child: AppButtonLabel(context.strings.shareNowAction),
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
  ShareSubject.victory => const ['Celebrazione', 'Diario', 'Scenica'],
  ShareSubject.goal => const ['Direzione', 'Promessa', 'Editoriale'],
  ShareSubject.habit => const ['Rituale', 'Editoriale', 'Scenica'],
  ShareSubject.project => const ['Costellazione', 'Manifesto', 'Scenica'],
  ShareSubject.vision => const ['Manifesto', 'Estratto', 'Editoriale'],
  ShareSubject.moodboard => const ['Collage', 'Galleria', 'Polaroid'],
  ShareSubject.quote => const ['Tipografica', 'Estratto', 'Poster'],
};

String _gradientLabel(_GradientShape value) => switch (value) {
  _GradientShape.halo => 'Alone',
  _GradientShape.radial => 'Radiale',
  _GradientShape.vertical => 'Verticale',
  _GradientShape.diagonal => 'Diagonale',
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
  _ShareFormat.story => '2:3',
  _ShareFormat.vertical => '9:16',
  _ShareFormat.portrait => '4:5',
  _ShareFormat.square => '1:1',
  _ShareFormat.landscape => '16:9',
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
  _Watermark.area => 'Artwork',
};

// ----- control widgets -----

/// A group of related controls, separated without repeating category titles.
class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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

/// A compact label and value with the full list of choices.
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
                Expanded(
                  child: PopupMenuButton<int>(
                    key: ValueKey('$fieldKey-menu'),
                    tooltip: shareComposerLabel(context, label),
                    initialValue: index,
                    onSelected: (i) {
                      if (i != index) onChanged(i);
                    },
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
    this.placeholder,
    this.previewHeight = 26,
    this.minItemWidth,
    this.singleRow = false,
  });
  final String fieldKey;
  final String label;
  final List<String> labels;
  final int index;
  final Widget Function(int) preview;
  final ValueChanged<int> onChanged;
  final int columns;
  final bool showLabels;
  final String? placeholder;
  final double previewHeight;
  final double? minItemWidth;
  final bool singleRow;

  Widget _label(BuildContext context, int index) {
    final text = Text(
      shareComposerLabel(context, labels[index]),
      textAlign: TextAlign.center,
      maxLines: singleRow ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: context.typography.controlLabel.copyWith(fontSize: 12.5),
    );
    return singleRow ? FittedBox(fit: BoxFit.scaleDown, child: text) : text;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          shareComposerLabel(context, label),
          style: context.typography.supporting.copyWith(fontSize: 12),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final maxColumns = columns.clamp(1, labels.length);
          final count = singleRow
              ? maxColumns
              : maxColumns.clamp(
                  1,
                  ((constraints.maxWidth + 6) /
                          ((minItemWidth ?? (showLabels ? 104 : 44)) + 6))
                      .floor()
                      .clamp(1, maxColumns),
                );
          final width = (constraints.maxWidth - (count - 1) * 6) / count;
          final tileWidth = width;
          final choices = <Widget>[
            for (var i = 0; i < labels.length; i++)
              Semantics(
                button: true,
                selected: i == index && placeholder == null,
                label: shareComposerLabel(context, labels[i]),
                child: Tooltip(
                  message: shareComposerLabel(context, labels[i]),
                  child: InkWell(
                    key: ValueKey('$fieldKey-$i'),
                    onTap: () {
                      if (i != index || placeholder != null) onChanged(i);
                    },
                    borderRadius: BorderRadius.circular(kRadiusField),
                    child: Container(
                      width: tileWidth,
                      height: showLabels
                          ? previewHeight + 46
                          : (previewHeight + 12).clamp(44.0, double.infinity),
                      decoration: selectableDecoration(
                        context.colors,
                        selected: i == index && placeholder == null,
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: previewHeight,
                              child: Center(child: preview(i)),
                            ),
                            if (showLabels) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: _label(context, i),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ];
          if (singleRow) {
            return Row(
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  choices[i],
                ],
              ],
            );
          }
          return Wrap(spacing: 6, runSpacing: 6, children: choices);
        },
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
      width: 22,
      height: 22,
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
  const _PaletteDot(this.palette, {this.reversed = false});
  final _Palette palette;
  final bool reversed;

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
        colors: reversed ? palette.colors.reversed.toList() : palette.colors,
      ),
    ),
  );
}
