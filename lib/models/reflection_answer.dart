import 'life_area.dart';

/// One written answer to one reflection question in a [LifeArea] — the
/// area's own "prepared questions" mechanism, sitting alongside its free-form
/// vision (see `AreaVisionRepository`) but scoped to a single fixed prompt
/// rather than one open canvas per area.
///
/// [questionId] is the prompt's index into [LifeAreaX.reflectionQuestions]
/// rather than its text, so an answer stays attached to the right question
/// even if its wording is later reworded, and survives a language switch
/// (the questions are looked up fresh per [AppStrings], the id never
/// changes). An area/question pair with no answer simply has no
/// [ReflectionAnswer] at all — see [ReflectionAnswerRepository.setAnswer].
class ReflectionAnswer {
  const ReflectionAnswer({
    required this.area,
    required this.questionId,
    required this.answerText,
    required this.answeredDate,
  });

  final LifeArea area;
  final String questionId;
  final String answerText;

  /// When this answer was last written or edited.
  final DateTime answeredDate;

  /// Answers saved before intensity was dropped still carry an `intensity`
  /// key; it is simply ignored.
  factory ReflectionAnswer.fromJson(Map<String, dynamic> json) {
    return ReflectionAnswer(
      area: LifeArea.values.byName(json['area'] as String),
      questionId: json['questionId'] as String,
      answerText: json['answerText'] as String,
      answeredDate: DateTime.parse(json['answeredDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'area': area.name,
      'questionId': questionId,
      'answerText': answerText,
      'answeredDate': answeredDate.toIso8601String(),
    };
  }
}
