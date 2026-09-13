import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/area_vision_repository.dart';
import '../data/project_repository.dart';
import '../data/reflection_answer_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/life_area.dart';
import '../models/reflection_answer.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final area = widget.area;

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

    return PopScope(
      canPop: true,
      // Autosave, not a "discard changes?" guard — there's nothing to
      // discard, the field just saves whenever it loses focus or the
      // screen closes.
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _saveVision();
      },
      child: Scaffold(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      area.description(strings),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colors.muted,
                      ),
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
                  const SizedBox(height: 28),
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
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: strings.areaVisionHint,
                      ),
                    )
                  else
                    Text(
                      _visionController.text.trim().isEmpty
                          ? strings.areaVisionHint
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
                    order: 2,
                    title: strings.supernovaTourEditTitle,
                    description: strings.supernovaTourEditBody,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _editingVision
                            ? _confirmVision
                            : _startEditingVision,
                        icon: Icon(_editingVision ? Icons.check : Icons.edit),
                        label: Text(
                          _editingVision
                              ? strings.saveChanges
                              : strings.editVisionAction,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ReflectionQuestionsSection(
                    area: area,
                    repository: widget.reflectionAnswerRepository,
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
