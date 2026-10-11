import 'dart:async';

import 'package:flutter/material.dart';

import '../data/reflection_answer_repository.dart';
import '../models/life_area.dart';
import '../models/reflection_answer.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'intensity_bolts.dart';
import 'staggered_entrance.dart';

class ReflectionQuestionsSection extends StatefulWidget {
  const ReflectionQuestionsSection({
    super.key,
    required this.area,
    required this.repository,
  });

  final LifeArea area;
  final ReflectionAnswerRepository repository;

  @override
  State<ReflectionQuestionsSection> createState() =>
      ReflectionQuestionsSectionState();
}

class ReflectionQuestionsSectionState
    extends State<ReflectionQuestionsSection> {
  /// The groups currently open. All start closed, so a long list of
  /// questions never greets the reader all at once.
  final Set<int> _open = {};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final groups = widget.area.reflectionGroups(strings);
    final questions = widget.area.reflectionQuestions(strings);
    // Where each group's first question sits in the flattened list; a
    // question's id is that flat position.
    final offsets = <int>[];
    var running = 0;
    for (final group in groups) {
      offsets.add(running);
      running += group.questions.length;
    }
    final answers = widget.repository.getAnswersForArea(widget.area);
    final answeredCount = answers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredEntrance(
          index: 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  strings.reflectionQuestionsSectionLabel,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text,
                  ),
                ),
              ),
              Text(
                '$answeredCount/${questions.length} '
                '${strings.reflectionAnsweredCountLabel}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.colors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        StaggeredEntrance(
          index: 1,
          child: Text(
            strings.reflectionQuestionsSubtitle,
            style: TextStyle(fontSize: 13, height: 1.4, color: colors.muted),
          ),
        ),
        const SizedBox(height: 14),
        for (var g = 0; g < groups.length; g++) ...[
          if (g > 0) const SizedBox(height: 10),
          StaggeredEntrance(
            index: 2 + offsets[g] + g,
            child: InkWell(
              onTap: () => setState(
                () => _open.contains(g) ? _open.remove(g) : _open.add(g),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groups[g].title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: colors.text,
                        ),
                      ),
                    ),
                    Text(
                      '${[for (var q = 0; q < groups[g].questions.length; q++)
                        if (answers.containsKey('${offsets[g] + q}')) q].length}/${groups[g].questions.length}',
                      style: TextStyle(fontSize: 16, color: colors.text),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: _open.contains(g) ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 24,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open.contains(g)
                ? Column(
                    children: [
                      for (var q = 0; q < groups[g].questions.length; q++) ...[
                        StaggeredEntrance(
                          index: q,
                          child: _ReflectionQuestionTile(
                            area: widget.area,
                            questionId: '${offsets[g] + q}',
                            questionText: groups[g].questions[q],
                            repository: widget.repository,
                            onSaved: () => setState(() {}),
                          ),
                        ),
                        if (q != groups[g].questions.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }
}

/// One question of [ReflectionQuestionsSection]: a header row that, on
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

  // Typing saves after a pause rather than on every key: the write and the
  // parent's rebuild (onSaved) are far heavier than a keystroke should cost.
  // Losing focus, collapsing and dispose all still flush it immediately.
  Timer? _saveDebounce;

  void _saveSoon() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await widget.repository.setAnswer(
      widget.area,
      widget.questionId,
      answerText: _controller.text,
      intensity: _intensity,
    );
    if (mounted) widget.onSaved();
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
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      widget.repository.setAnswer(
        widget.area,
        widget.questionId,
        answerText: _controller.text,
        intensity: _intensity,
      );
    }
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
                      child: StaggeredEntrance(
                        index: 0,
                        axis: Axis.horizontal,
                        child: Icon(
                          Icons.offline_bolt,
                          size: 16,
                          color: context.colors.gold,
                        ),
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
                    // Mounted only while open, so the parts cascade in each
                    // time the tile is expanded.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StaggeredEntrance(
                          index: 0,
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => _saveSoon(),
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
                        ),
                        const SizedBox(height: 14),
                        StaggeredEntrance(
                          index: 1,
                          child: Text(
                            strings.reflectionDifficultyLabel,
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StaggeredEntrance(
                          index: 1,
                          child: Center(
                            child: IntensityBolts(
                              intensity: _intensity,
                              color: context.colors.gold,
                              size: 22,
                              spacing: 6,
                              emphasizeLast: true,
                            ),
                          ),
                        ),
                        StaggeredEntrance(
                          index: 2,
                          child: Center(
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
