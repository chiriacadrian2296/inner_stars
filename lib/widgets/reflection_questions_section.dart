import 'package:flutter/material.dart';

import '../data/reflection_answer_repository.dart';
import '../models/life_area.dart';
import '../models/reflection_answer.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'intensity_bolts.dart';

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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '$answeredCount/${questions.length} '
              '${strings.reflectionAnsweredCountLabel}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
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

  Future<void> _save() async {
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
                        color: Colors.white,
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
                          onChanged: (_) => _save(),
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
                            color: Colors.white,
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
