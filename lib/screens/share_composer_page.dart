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

/// A background and watermark combination in one tap.
class _StylePreset {
  const _StylePreset(
    this.label, {
    required this.gradient,
    required this.palette,
    this.watermark = _Watermark.none,
  });
  final String label;
  final _GradientShape gradient;
  final int palette;
  final _Watermark watermark;
}

const _stylePresets = [
  _StylePreset('Classico', gradient: _GradientShape.halo, palette: 0),
  _StylePreset(
    'Dorato',
    gradient: _GradientShape.vertical,
    palette: 3,
    watermark: _Watermark.logo,
  ),
  _StylePreset('Editoriale', gradient: _GradientShape.vertical, palette: 5),
  _StylePreset(
    'Lunare',
    gradient: _GradientShape.radial,
    palette: 6,
    watermark: _Watermark.logo,
  ),
  _StylePreset('Grafico', gradient: _GradientShape.diagonal, palette: 2),
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

  int? get _style {
    final match = _stylePresets.indexWhere(
      (style) =>
          style.gradient == _gradient &&
          style.palette == _palette &&
          style.watermark == _effectiveWatermark,
    );
    return match < 0 ? null : match;
  }

  bool _compactPreview = false;

  // Background.
  _GradientShape _gradient = _GradientShape.halo;
  int _palette = 0;
  _PhotoMode _photoMode = _PhotoMode.none;

  // Signature colors are linked to the title and watermark.
  _BrandContent _brandContent = _BrandContent.both;
  _BrandLayout _brandLayout = _BrandLayout.logoLeft;

  // Watermark.
  _Watermark _watermark = _Watermark.none;
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
      gradient: _gradient,
      palette: _palette,
      photoMode: _photoMode,
      brandContent: _brandContent,
      brandLayout: _brandLayout,
      watermark: _watermark,
      excerpt: _excerpt.text,
    );
    return () {
      _subjectIndex = draft.subject;
      _composition = draft.composition;
      _format = draft.format;
      _gradient = draft.gradient;
      _palette = draft.palette;
      _photoMode = draft.photoMode;
      _brandContent = draft.brandContent;
      _brandLayout = draft.brandLayout;
      _watermark = draft.watermark;
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

  void _edit(VoidCallback change) => _change(change);

  void _applyPreset(int index) {
    final s = _stylePresets[index];
    if (_style == index) return;
    _change(() {
      _gradient = s.gradient;
      _palette = s.palette;
      _watermark = s.watermark;
    });
  }

  _TitlePosition _signaturePosition(int composition) =>
      switch (_layoutMap[_subject]![composition].$1) {
        _Layout.free || _Layout.poster => _TitlePosition.topRight,
        _ => _TitlePosition.bottomCenter,
      };

  List<_PhotoMode> get _photoModes => _PhotoMode.values;

  _Ink _elementInkFor(int composition) =>
      switch (_layoutMap[_subject]![composition].$1) {
        _Layout.centered || _Layout.free => _Ink.gold,
        _ => _Ink.auto,
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

  Widget _specimen({int? composition, _StylePreset? preset}) => _ShareSpecimen(
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
    gradient: preset?.gradient ?? _gradient,
    palette: preset?.palette ?? _palette,
    format: _format,
    photoMode: _photoMode,
    titlePosition: _TitlePosition.bottomLeft,
    brandPosition: _signaturePosition(composition ?? _composition),
    badgePosition: _BadgePosition.top,
    titleInk: _Ink.auto,
    watermark: preset?.watermark ?? _effectiveWatermark,
    watermarkInk: _elementInkFor(composition ?? _composition),
    watermarkArea: _watermarkArea,
    brandContent: _brandContent,
    logoStyle: _LogoStyle.current,
    logoDisc: false,
    nameInk: _elementInkFor(composition ?? _composition),
    logoInk: _elementInkFor(composition ?? _composition),
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
            if (_data.photos.isEmpty) {
              _photoMode = _PhotoMode.none;
            }
            _excerpt.text = _data.description;
          }),
        ),
      _VisualChoices(
        fieldKey: 'scheda-composizione',
        label: 'Composizione',
        labels: _compositionLabels(_subject),
        index: _composition,
        columns: 3,
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
      if (_data.isReflection)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('share-reflection-excerpt'),
            onPressed: _editExcerpt,
            child: Text(shareComposerLabel(context, 'Modifica Estratto')),
          ),
        ),
    ],
  );

  Widget _styleBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'stile-preset',
        label: 'Stili Pronti',
        labels: [for (final p in _stylePresets) p.label],
        index: _style,
        columns: 5,
        singleRow: true,
        previewHeight: 64,
        preview: (i) => FittedBox(
          child: SizedBox(
            width: _format == _ShareFormat.landscape ? 640 : 360,
            height:
                (_format == _ShareFormat.landscape ? 640 : 360) /
                _shareAspectRatio(_format),
            child: MediaQuery.withNoTextScaling(
              child: _specimen(preset: _stylePresets[i]),
            ),
          ),
        ),
        onChanged: _applyPreset,
      ),
    ],
  );

  Widget _backgroundBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'sfondo-colori',
        label: 'Colori',
        labels: [for (final p in _palettes) p.label],
        preview: (i) => _PaletteDot(_palettes[i]),
        columns: 4,
        index: _palette,
        onChanged: (i) => _edit(() => _palette = i),
      ),
      _VisualChoices(
        fieldKey: 'sfondo-forma',
        label: 'Forma dello Sfondo',
        labels: [for (final g in _GradientShape.values) _gradientLabel(g)],
        index: _gradient.index,
        columns: 4,
        previewHeight: 64,
        preview: (i) => SizedBox(
          width: 48,
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
                  ),
                ),
              ),
            ),
          ),
        ),
        onChanged: (i) => _edit(() => _gradient = _GradientShape.values[i]),
      ),
    ],
  );

  Widget _photoBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'sfondo-foto',
        label: 'Foto',
        labels: [for (final m in _photoModes) _photoLabel(m)],
        index: _photoModes.indexOf(_photoMode),
        columns: 4,
        previewHeight: 64,
        preview: (i) => _photoChoice(_photoModes[i]),
        onChanged: (i) => _edit(() => _photoMode = _photoModes[i]),
      ),
    ],
  );

  Widget _photoChoice(_PhotoMode mode) {
    final photo = _ContentPhoto(
      url: _data.photos.first,
      fit: BoxFit.cover,
      moodboard: _subject == ShareSubject.moodboard,
    );
    return Container(
      key: ValueKey('share-photo-sample-${mode.name}'),
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: context.colors.night,
        borderRadius: BorderRadius.circular(5),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: context.colors.muted),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            switch (mode) {
              _PhotoMode.none => Icon(
                Icons.block_rounded,
                size: 20,
                color: context.colors.muted,
              ),
              _PhotoMode.background => photo,
              _PhotoMode.integrated => _integratedPhotoChoice(photo),
            },
            if (mode == _PhotoMode.background) const _PhotoBackdropScrim(),
            if (mode == _PhotoMode.background)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 2, color: context.colors.text),
                    const SizedBox(height: 3),
                    Container(width: 16, height: 2, color: context.colors.text),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _integratedPhotoChoice(Widget photo) {
    final layout = _layoutMap[_subject]![_composition].$1;
    return switch (layout) {
      _Layout.polaroid => Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
        child: Container(
          color: const Color(0xFFF4F1E8),
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 9),
          child: photo,
        ),
      ),
      _Layout.collage => Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            Expanded(child: photo),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: photo),
                  const SizedBox(height: 2),
                  Expanded(child: photo),
                ],
              ),
            ),
          ],
        ),
      ),
      _Layout.gallery => Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    i == 0 ? 0 : 1,
                    i == 1 ? 10 : 0,
                    0,
                    i == 1 ? 0 : 10,
                  ),
                  child: photo,
                ),
              ),
          ],
        ),
      ),
      _Layout.constellation => Stack(
        children: [
          Center(
            child: Icon(
              Icons.auto_awesome,
              size: 26,
              color: context.colors.muted,
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: SizedBox.square(
              dimension: 10,
              child: ClipOval(child: photo),
            ),
          ),
        ],
      ),
      _ => Center(
        child: SizedBox.square(
          dimension:
              48 /
              (_format == _ShareFormat.landscape ? 640 : 360) *
              34 *
              3.2 *
              (_format == _ShareFormat.landscape ? .72 : 1),
          child: ClipOval(child: photo),
        ),
      ),
    };
  }

  Widget _signatureBlock() => _BlockCard(
    children: [
      _VisualChoices(
        fieldKey: 'firma-disposizione',
        label: 'Disposizione',
        labels: const ['Solo Logo', 'Sinistra', 'Sopra'],
        index: _brandContent == _BrandContent.logo
            ? 0
            : _brandLayout == _BrandLayout.logoLeft
            ? 1
            : 2,
        columns: 3,
        previewHeight: 44,
        preview: (i) {
          final color = context.colors.muted;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: _AppBrand(
              content: i == 0 ? _BrandContent.logo : _BrandContent.both,
              logoStyle: _LogoStyle.current,
              disc: false,
              ink: color,
              logoInk: color,
              logoSize: 16,
              layout: i == 2 ? _BrandLayout.logoAbove : _BrandLayout.logoLeft,
              foreground: color,
              secondary: color,
              accent: color,
              compact: _format == _ShareFormat.landscape,
            ),
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

  Widget _watermarkBlock() {
    final kinds = [
      _Watermark.none,
      _Watermark.logo,
      if (_data.area != null) _Watermark.area,
    ];
    return _BlockCard(
      children: [
        _VisualChoices(
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
              width: 36,
              height: 36,
              colorFilter: ColorFilter.mode(
                context.colors.muted,
                BlendMode.srcIn,
              ),
            ),
            _Watermark.area => Image.asset(
              kAreaHeroArt[_data.area]!.coverAsset,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              color: context.colors.muted,
              colorBlendMode: BlendMode.srcIn,
            ),
          },
          onChanged: (i) => _edit(() => _watermark = kinds[i]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    const noInk = ButtonStyle(
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    );
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        iconButtonTheme: IconButtonThemeData(
          style: theme.iconButtonTheme.style?.merge(noInk) ?? noInk,
        ),
        textButtonTheme: TextButtonThemeData(
          style: theme.textButtonTheme.style?.merge(noInk) ?? noInk,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: theme.elevatedButtonTheme.style?.merge(noInk) ?? noInk,
        ),
      ),
      child: Scaffold(
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
                ('Sfondo', Icons.gradient_rounded),
                ('Firma', Icons.verified_outlined),
              ];
              final sections = [
                [_styleBlock(), _cardBlock()],
                [
                  if (_data.photos.isNotEmpty) _photoBlock(),
                  _backgroundBlock(),
                  _watermarkBlock(),
                ],
                [_signatureBlock()],
              ];
              final history = SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const ValueKey('share-undo'),
                      tooltip: shareComposerLabel(context, 'Annulla Modifica'),
                      color: colors.gold,
                      disabledColor: colors.muted,
                      onPressed: _undo.isEmpty
                          ? null
                          : () => _travel(_undo, _redo),
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    IconButton(
                      key: const ValueKey('share-toggle-preview'),
                      iconSize: 32,
                      tooltip: shareComposerLabel(
                        context,
                        _compactPreview
                            ? 'Espandi Anteprima'
                            : 'Espandi Controlli',
                      ),
                      color: _compactPreview ? colors.gold : colors.muted,
                      onPressed: () =>
                          setState(() => _compactPreview = !_compactPreview),
                      icon: Icon(
                        _compactPreview
                            ? Icons.expand_more_rounded
                            : Icons.expand_less_rounded,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('share-redo'),
                      tooltip: shareComposerLabel(
                        context,
                        'Ripristina Modifica',
                      ),
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
                          if (i > 0) const SizedBox(height: 32),
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
                                        style: context.typography.sectionHeading
                                            .copyWith(fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                          for (var j = 0; j < sections[i].length; j++) ...[
                            if (j > 0) const SizedBox(height: 16),
                            sections[i][j],
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
              final body = LayoutBuilder(
                builder: (context, bounds) {
                  final maxControlsHeight = (bounds.maxHeight - 96).clamp(
                    0.0,
                    double.infinity,
                  );
                  double controlHeight(bool compact) =>
                      ((compact
                                  ? (constraints.maxHeight * .60).clamp(
                                      180.0,
                                      600.0,
                                    )
                                  : (constraints.maxHeight * .38).clamp(
                                      240.0,
                                      310.0,
                                    )) -
                              48 +
                              gap)
                          .clamp(0.0, maxControlsHeight);
                  final normalHeight = controlHeight(false);
                  final compactHeight = controlHeight(true);
                  final sideWidth = (constraints.maxWidth * .42).clamp(
                    320.0,
                    480.0,
                  );
                  final normalPreview = Rect.fromLTWH(
                    0,
                    0,
                    wide ? bounds.maxWidth - sideWidth - gap : bounds.maxWidth,
                    bounds.maxHeight - 48 - (wide ? 0 : normalHeight),
                  );
                  final compactPreview = Rect.fromLTWH(
                    0,
                    0,
                    bounds.maxWidth,
                    bounds.maxHeight - compactHeight - 48,
                  );
                  final normalControls = wide
                      ? Rect.fromLTWH(
                          bounds.maxWidth - sideWidth,
                          0,
                          sideWidth,
                          bounds.maxHeight,
                        )
                      : Rect.fromLTWH(
                          0,
                          bounds.maxHeight - normalHeight,
                          bounds.maxWidth,
                          normalHeight,
                        );
                  final compactControls = Rect.fromLTWH(
                    0,
                    bounds.maxHeight - compactHeight,
                    bounds.maxWidth,
                    compactHeight,
                  );
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _compactPreview ? 1 : 0),
                    duration: motionDuration(context, kMotionSlow),
                    curve: kMotionEnter,
                    builder: (context, progress, _) {
                      final previewRect = Rect.lerp(
                        normalPreview,
                        compactPreview,
                        progress,
                      )!;
                      final controlsRect = Rect.lerp(
                        normalControls,
                        compactControls,
                        progress,
                      )!;
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: previewRect,
                            child: preview,
                          ),
                          Positioned.fromRect(
                            rect: Rect.fromLTWH(
                              0,
                              previewRect.bottom,
                              previewRect.width,
                              48,
                            ),
                            child: history,
                          ),
                          Positioned.fromRect(
                            rect: controlsRect,
                            child: controls,
                          ),
                        ],
                      );
                    },
                  );
                },
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
  _PhotoMode.integrated => 'Foto Integrata',
};

String _watermarkLabel(_Watermark value) => switch (value) {
  _Watermark.none => 'Nessuno',
  _Watermark.logo => 'Logo',
  _Watermark.area => 'Area',
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
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
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
    final labelText = AppFieldLabel(shareComposerLabel(context, label));
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

/// Visual choices with muted captions outside their selection borders.
class _VisualChoices extends StatelessWidget {
  const _VisualChoices({
    required this.fieldKey,
    required this.label,
    required this.labels,
    required this.index,
    required this.preview,
    required this.onChanged,
    this.columns = 6,
    this.previewHeight = 26,
    this.minItemWidth,
    this.singleRow = false,
  });
  final String fieldKey;
  final String label;
  final List<String> labels;
  final int? index;
  final Widget Function(int) preview;
  final ValueChanged<int> onChanged;
  final int columns;
  final double previewHeight;
  final double? minItemWidth;
  final bool singleRow;

  Widget _label(BuildContext context, int index) {
    final text = Text(
      key: ValueKey('$fieldKey-caption-$index'),
      shareComposerLabel(context, labels[index]),
      textAlign: TextAlign.center,
      maxLines: singleRow ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: context.typography.supporting.copyWith(
        fontSize: 11,
        height: 1.2,
        color: index == this.index ? context.colors.gold : context.colors.muted,
        fontWeight: index == this.index ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    return singleRow ? FittedBox(fit: BoxFit.scaleDown, child: text) : text;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: kFieldLabelGap),
        child: AppFieldLabel(
          shareComposerLabel(context, label),
          key: ValueKey('$fieldKey-label'),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final maxColumns = columns.clamp(1, labels.length);
          final count = singleRow
              ? maxColumns
              : maxColumns.clamp(
                  1,
                  ((constraints.maxWidth + 6) / ((minItemWidth ?? 44) + 6))
                      .floor()
                      .clamp(1, maxColumns),
                );
          final width = (constraints.maxWidth - (count - 1) * 6) / count;
          final tileWidth = width;
          final choices = <Widget>[
            for (var i = 0; i < labels.length; i++)
              Semantics(
                button: true,
                selected: i == index,
                label: shareComposerLabel(context, labels[i]),
                child: Tooltip(
                  message: shareComposerLabel(context, labels[i]),
                  child: InkWell(
                    key: ValueKey('$fieldKey-$i'),
                    onTap: () {
                      if (i != index) onChanged(i);
                    },
                    borderRadius: BorderRadius.circular(kRadiusField),
                    child: SizedBox(
                      width: tileWidth,
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            SizedBox(
                              key: ValueKey('$fieldKey-tile-$i'),
                              height: (previewHeight + 12).clamp(
                                44.0,
                                double.infinity,
                              ),
                              child: Center(
                                child: SizedBox(
                                  height: previewHeight,
                                  child: Center(child: preview(i)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: singleRow ? 14 : 28,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: _label(context, i),
                              ),
                            ),
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
  _Ink.navyDark => colors.night,
  _Ink.navyLight => const Color(0xFF7C8FC4),
};

/// A small preview of a background palette.
class _PaletteDot extends StatelessWidget {
  const _PaletteDot(this.palette);
  final _Palette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 26,
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
