import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/reflection_answer.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../theme/nightlight_style.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/physical_art_tone.dart';
import '../utils/responsive.dart';
import '../utils/star_stats.dart';
import '../widgets/area_tag.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/responsive_content.dart';

/// One Supernova's own page — reached by tapping it in the Sky's
/// search popup (`SkyExplorerView`'s Supernovas view). Shows the area's
/// icon, name, and description, three big numbers (constellations/stars/
/// intensity), and that area's "vision" — their own words for what they
/// want out of it — editable via the Edit button. Nothing to navigate
/// onward to from here, only back; constellations and stars live in that
/// same popup's own Constellations/Stars views instead.
///
/// For an area with hero art of its own (currently just Physical, see
/// assets/images), this opens on a "cover" — [_AreaCoverPage] — showing
/// that art full and pressing forward into the management content above;
/// every other area has no cover and opens straight on that content. The
/// two are a metaphor ("like a card with two faces"), not a literal
/// page-flip visual — see [_showCover] and [build]'s own PopScope for how
/// stepping between them also folds into this screen's own back
/// navigation, rather than being a second pushed route.
class AreaDetailScreen extends StatefulWidget {
  const AreaDetailScreen({
    super.key,
    required this.area,
    required this.areaVisionRepository,
    required this.reflectionAnswerRepository,
    required this.projectRepository,
    required this.starRepository,
  });

  final LifeArea area;
  final AreaVisionRepository areaVisionRepository;
  final ReflectionAnswerRepository reflectionAnswerRepository;
  final ProjectRepository projectRepository;
  final StarRepository starRepository;

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  late final _visionController = TextEditingController(
    text: widget.areaVisionRepository.getVision(widget.area),
  );
  late final _visionFocusNode = FocusNode()..addListener(_handleFocusChange);
  bool _editingVision = false;

  void _handleFocusChange() {
    if (!_visionFocusNode.hasFocus) {
      _saveVision();
      setState(() => _editingVision = false);
    }
  }

  Future<void> _saveVision() {
    return widget.areaVisionRepository.setVision(
      widget.area,
      _visionController.text,
    );
  }

  void _startEditingVision() {
    setState(() => _editingVision = true);
    _visionFocusNode.requestFocus();
  }

  Future<void> _confirmVision() async {
    await _saveVision();
    if (!mounted) return;
    setState(() => _editingVision = false);
  }

  @override
  void dispose() {
    _visionFocusNode.removeListener(_handleFocusChange);
    _visionFocusNode.dispose();
    _visionController.dispose();
    super.dispose();
  }

  // Only Physical has hero art of its own so far (see assets/images) — its
  // own "cover" (see [_AreaCoverPage]) shows this full, lightly toned
  // toward the app's own navy (see [tonedPhysicalArt]), before the
  // management content below. Every other area has no cover at all and
  // opens straight on that content.
  static const _coverAsset = 'assets/images/1. Physical.png';

  bool get _hasCover => widget.area == LifeArea.physical;

  // Which of this screen's two "pages" (see the class doc comment) is
  // showing — not a separate route, just an internal step, so the system
  // back gesture/button can step from management back to the cover before
  // it ever closes this screen (see [build]'s own PopScope).
  late bool _showCover = _hasCover;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final area = widget.area;

    // While a cover-having area is showing its management content, a pop
    // attempt (system back, or the on-screen back arrow below — both go
    // through this same check) should step back to the cover instead of
    // leaving the screen entirely.
    final blockPopForCover = _hasCover && !_showCover;

    return PopScope(
      canPop: !blockPopForCover,
      // Autosave, not a "discard changes?" guard — there's nothing to
      // discard, the field just saves whenever it loses focus or the
      // screen closes (or, now, whenever a pop steps back to the cover).
      onPopInvokedWithResult: (didPop, result) {
        _saveVision();
        if (!didPop) setState(() => _showCover = true);
      },
      child: _showCover
          ? _AreaCoverPage(
              asset: _coverAsset,
              visionTitle: strings.areaCoverVisionTitle,
              visionText: _visionController.text.trim().isEmpty
                  ? area.visionPlaceholder(strings)
                  : _visionController.text,
              actionLabel: strings.areaCoverEnterAction,
              onBack: () => Navigator.of(context).pop(),
              onEnter: () => setState(() => _showCover = false),
            )
          : _buildManagement(context, colors, strings, area),
    );
  }

  // How much of the banner image's own width is cropped away on a native
  // phone build (see [isTouchOnlyMobile] — deliberately not just a narrow
  // *window*, which web/desktop can also be) — asked for explicitly as
  // "circa il 30%". Expressed as the box's own width:height ratio rather
  // than a crop percentage directly: for a *square* source image,
  // `BoxFit.cover`'s own crop math reduces to exactly "visible width
  // fraction == box aspect ratio" once the box is taller than it is wide,
  // so this number *is* the visible fraction (0.7 visible == 30% cropped)
  // with no extra transform needed. On web/desktop the box stays square
  // (1.0) — the image's own natural shape, uncropped — absent any request
  // to zoom it there too.
  static const _phoneBannerAspectRatio = 0.7;
  static const _wideBannerAspectRatio = 1.0;

  Widget _buildManagement(
    BuildContext context,
    AppColors colors,
    AppStrings strings,
    LifeArea area,
  ) {
    final constellationCount = widget.projectRepository
        .getProjectsForArea(area)
        .length;
    final starCount = starsInArea(
      area,
      widget.projectRepository,
      widget.starRepository,
    );
    final totalIntensity = totalIntensityInArea(
      area,
      widget.projectRepository,
      widget.starRepository,
    );

    // The vision section and the description+stats block are the same
    // widgets regardless of area — only their *order* differs (see below).
    final visionSection = [
      Text(
        strings.areaVisionLabel,
        style: TextStyle(fontSize: 13, color: colors.muted),
      ),
      const SizedBox(height: 6),
      if (_editingVision)
        TextField(
          controller: _visionController,
          focusNode: _visionFocusNode,
          minLines: 6,
          maxLines: null,
          style: TextStyle(color: colors.text, fontSize: 15, height: 1.5),
          decoration: InputDecoration(hintText: strings.areaVisionHint),
        )
      else
        Text(
          _visionController.text.trim().isEmpty
              ? area.visionPlaceholder(strings)
              : _visionController.text,
          style: TextStyle(
            color: _visionController.text.trim().isEmpty
                ? colors.muted
                : colors.text,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      const SizedBox(height: 16),
      HintTarget(
        tour: 'supernova-vision',
        order: 3,
        showArrow: true,
        contentBuilder: appTourStepCard,
        title: strings.supernovaTourEditTitle,
        description: strings.supernovaTourEditBody,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _editingVision ? _confirmVision : _startEditingVision,
            icon: Icon(_editingVision ? Icons.check : Icons.edit),
            label: Text(
              _editingVision ? strings.saveChanges : strings.editVisionAction,
            ),
          ),
        ),
      ),
    ];

    final descriptionAndStats = [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          area.description(strings),
          style: TextStyle(fontSize: 14, height: 1.4, color: colors.muted),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: _StatBlock(
              value: '$constellationCount',
              label: strings.areaConstellationsStatLabel,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatBlock(
              value: '$starCount',
              label: strings.areaStarsStatLabel,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatBlock(
              value: '$totalIntensity',
              label: strings.areaIntensityStatLabel,
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: colors.muted),
                    ),
                    Expanded(
                      child: AreaTag(area: area, iconSize: 22, fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Image up top, vision right underneath it — only for a
                // cover-having area (currently just Physical); every other
                // area has no art and keeps its old order (description and
                // stats first, vision below that).
                if (_hasCover) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: isTouchOnlyMobile
                          ? _phoneBannerAspectRatio
                          : _wideBannerAspectRatio,
                      child: tonedPhysicalArt(
                        child: Image.asset(_coverAsset, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...visionSection,
                  const SizedBox(height: 32),
                  ...descriptionAndStats,
                ] else ...[
                  ...descriptionAndStats,
                  const SizedBox(height: 28),
                  ...visionSection,
                ],
                const SizedBox(height: 32),
                HintTarget(
                  tour: 'supernova-vision',
                  order: 4,
                  showArrow: true,
                  contentBuilder: appTourStepCard,
                  title: strings.supernovaTourReflectionTitle,
                  description: strings.supernovaTourReflectionBody,
                  child: _ReflectionQuestionsSection(
                    area: area,
                    repository: widget.reflectionAnswerRepository,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "front of the card" — a cover-having area's own hero art shown full,
/// lightly toned toward the app's own navy/white (see
/// [tonedPhysicalArt] — its raw color read as too saturated next to the
/// rest of the app; a full fade/vignette tint was tried and dropped for
/// using the art as a background behind the management content instead,
/// which read as too subdued for what's meant to be a striking full-bleed
/// page in its own right; see git history), the area's own vision
/// underneath it, and one button forward into the management content
/// proper. Purely a navigation
/// metaphor, not a literal page-flip/card visual — nothing here animates
/// like one.
///
/// The vision and the action button both sit *below* the image, in normal
/// document flow (`Column`), not floated on top of it — asked for
/// explicitly, after a first pass overlaid the button on the art via a
/// `Stack`. That costs the image some of its own height (the two claim
/// real space rather than borrowing the image's own), which is the
/// intended trade.
class _AreaCoverPage extends StatelessWidget {
  const _AreaCoverPage({
    required this.asset,
    required this.visionTitle,
    required this.visionText,
    required this.actionLabel,
    required this.onBack,
    required this.onEnter,
  });

  final String asset;

  /// The glowing heading above [visionText] — see
  /// [AppStrings.areaCoverVisionTitle]'s own doc comment.
  final String visionTitle;

  /// The area's own vision, or [LifeArea.visionPlaceholder] when they
  /// haven't written one yet.
  final String visionText;

  final String actionLabel;
  final VoidCallback onBack;
  final VoidCallback onEnter;

  // How far in from each edge (as a fraction of the image's own width/
  // height) the fade-to-transparent runs — see the nested ShaderMasks
  // below. Much smaller than the sky backdrop's own vignette (which starts
  // fading at 0.35 of its radius): only a thin sliver right at each edge
  // fades here, asked for explicitly as "molto meno" than the sky's.
  static const _edgeFadeExtent = 0.06;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Back button, image, vision, button: one single page, one single
    // `SingleChildScrollView`, the same shape every other screen in the
    // app uses (see e.g. `_buildManagement`'s own
    // `SafeArea > ResponsiveContent > SingleChildScrollView > Column`) —
    // not the back button pinned outside the scroll region over a
    // separately-sized image (tried first, twice: once with a
    // hand-computed height budget, once with the image still its own
    // Expanded sibling next to a scrolling one). Both read as the image
    // sitting in a different, disconnected layer from the rest of the
    // page rather than just being its first piece of content — asked for
    // explicitly to undo, in favor of this ordinary single-page layout.
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            // Caps the whole column — back button, image, and all — at
            // the app's usual central width on a wide/web viewport.
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      // Two orthogonal fades stacked — each
                      // ShaderMask multiplies its own alpha onto
                      // what's already been masked below it, so the
                      // pair together fade a square edge (all four
                      // sides, corners included) rather than the
                      // sky's own circular vignette (see
                      // sky_area_backdrop.dart), and much more
                      // subtly — only the outer [_edgeFadeExtent]
                      // sliver on each side fades at all, the rest
                      // of the image stays fully visible.
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [
                            0.0,
                            _edgeFadeExtent,
                            1 - _edgeFadeExtent,
                            1.0,
                          ],
                        ).createShader(rect),
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [
                              0.0,
                              _edgeFadeExtent,
                              1 - _edgeFadeExtent,
                              1.0,
                            ],
                          ).createShader(rect),
                          child: tonedPhysicalArt(
                            child: Image.asset(asset, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Generous space above the vision section (title +
                  // body), separating it clearly from the image above.
                  const SizedBox(height: 48),
                  // The heading asked for explicitly — "Visione",
                  // centered and big. No glow (tried first; asked to
                  // remove it from both this and the button below).
                  Text(
                    visionTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: kFontBranding,
                      fontSize: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      visionText,
                      textAlign: TextAlign.center,
                      // No line cap — the whole vision shows,
                      // however long; this section scrolls rather
                      // than the text truncating.
                      style: const TextStyle(
                        fontFamily: kFontStarTitle,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        // Brought down from an earlier 24 — at full,
                        // uncapped length a long vision read better
                        // a size smaller.
                        fontSize: 19,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Same generous space below the vision section,
                  // before the button.
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    // White-on-navy, the same look the Nightlight
                    // section's own primary buttons use (see
                    // nightlight_style.dart) — reads better here
                    // than the app's usual gold-on-navy, which
                    // would clash with the art's own blue. No glow
                    // (tried first, a blue BoxShadow behind this —
                    // asked to remove it, along with the title's
                    // own). Sized to its own label (no
                    // `SizedBox(width: double.infinity)`) — a
                    // full-width button here read as too heavy.
                    child: ElevatedButton(
                      style: nightlightButtonStyle(colors),
                      onPressed: onEnter,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three big numbers on a Supernova's detail page — value up top
/// in gold, a small muted label underneath. Styled after `stats_screen.dart`'s
/// `_StatCard`, minus its tap target — nothing to drill into here.
class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: panelDecoration(colors),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: kFontMono,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colors.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// The "Domande di riflessione" section on a Supernova's own page: a header
/// showing how many of [area]'s four prepared prompts have an answer so
/// far, then one accordion tile per question. Its own [StatefulWidget]
/// (rather than folded into [_AreaDetailScreenState]) so the answered count
/// can refresh itself whenever a tile saves, without rebuilding the vision
/// field above it.
class _ReflectionQuestionsSection extends StatefulWidget {
  const _ReflectionQuestionsSection({
    required this.area,
    required this.repository,
  });

  final LifeArea area;
  final ReflectionAnswerRepository repository;

  @override
  State<_ReflectionQuestionsSection> createState() =>
      _ReflectionQuestionsSectionState();
}

class _ReflectionQuestionsSectionState
    extends State<_ReflectionQuestionsSection> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final questions = widget.area.reflectionQuestions(strings);
    final answeredCount = widget.repository
        .getAnswersForArea(widget.area)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                strings.reflectionQuestionsSectionLabel,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
            ),
            Text(
              '$answeredCount/${questions.length} '
              '${strings.reflectionAnsweredCountLabel}',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          strings.reflectionQuestionsSubtitle,
          style: TextStyle(fontSize: 13, height: 1.4, color: colors.muted),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < questions.length; i++) ...[
          _ReflectionQuestionTile(
            area: widget.area,
            questionId: '$i',
            questionText: questions[i],
            repository: widget.repository,
            onSaved: () => setState(() {}),
          ),
          if (i != questions.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One question of [_ReflectionQuestionsSection]: a header row that, on
/// tap, expands downward — pushing the tiles below it rather than
/// overlaying them — into a free-text answer field and a difficulty
/// picker using the same 1-5 intensity scale a star's own effort is rated
/// on. Collapsed, the header alone shows (via a small gold bolt) whether
/// the question's been answered; the answer text itself only exists while
/// expanded, never truncated inline.
class _ReflectionQuestionTile extends StatefulWidget {
  const _ReflectionQuestionTile({
    required this.area,
    required this.questionId,
    required this.questionText,
    required this.repository,
    required this.onSaved,
  });

  final LifeArea area;
  final String questionId;
  final String questionText;
  final ReflectionAnswerRepository repository;
  final VoidCallback onSaved;

  @override
  State<_ReflectionQuestionTile> createState() =>
      _ReflectionQuestionTileState();
}

class _ReflectionQuestionTileState extends State<_ReflectionQuestionTile> {
  late final ReflectionAnswer? _existing = widget.repository.getAnswer(
    widget.area,
    widget.questionId,
  );
  late final _controller = TextEditingController(
    text: _existing?.answerText ?? '',
  );
  late final _focusNode = FocusNode()..addListener(_handleFocusChange);
  late int _intensity = _existing?.intensity ?? 3;
  bool _expanded = false;

  bool get _hasAnswer => _controller.text.trim().isNotEmpty;

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _save();
  }

  Future<void> _save() async {
    await widget.repository.setAnswer(
      widget.area,
      widget.questionId,
      answerText: _controller.text,
      intensity: _intensity,
    );
    widget.onSaved();
  }

  // Collapsing (rather than losing focus) is the other moment an edit needs
  // to be saved — a slider drag alone never touches the text field's focus,
  // so relying on [_handleFocusChange] by itself could lose a difficulty
  // change made without ever typing.
  void _toggleExpanded() {
    if (_expanded) _save();
    setState(() => _expanded = !_expanded);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  if (_hasAnswer)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.offline_bolt,
                        size: 16,
                        color: colors.gold,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.questionText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(Icons.keyboard_arrow_down, color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 3,
                          maxLines: null,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 14,
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText: strings.reflectionAnswerHint,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          strings.reflectionDifficultyLabel,
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: IntensityBolts(
                            intensity: _intensity,
                            size: 22,
                            spacing: 6,
                            emphasizeLast: true,
                          ),
                        ),
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.7,
                            child: SliderTheme(
                              data: SliderTheme.of(context)
                                  .copyWith(padding: EdgeInsets.zero),
                              child: Slider(
                                value: _intensity.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                onChanged: (value) {
                                  setState(() => _intensity = value.round());
                                  _save();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
