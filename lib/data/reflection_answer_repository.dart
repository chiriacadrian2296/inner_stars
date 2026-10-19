import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';
import '../models/reflection_answer.dart';

/// Reads and writes the user's answers to each [LifeArea]'s reflection
/// questions (see `LifeAreaX.reflectionQuestions`), one [ReflectionAnswer]
/// per (area, question) pair, as a single JSON-encoded map under one
/// [SharedPreferences] key — the same shape as [AreaVisionRepository], just
/// keyed by area *and* question instead of area alone.
class ReflectionAnswerRepository {
  ReflectionAnswerRepository(this._prefs);

  static const _storageKey = 'reflection-answers-v1';

  final SharedPreferences _prefs;

  static Future<ReflectionAnswerRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ReflectionAnswerRepository(prefs);
  }

  static String _key(LifeArea area, String questionId) =>
      '${area.name}|$questionId';

  Map<String, ReflectionAnswer> _readAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          ReflectionAnswer.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Null when this question hasn't been answered yet.
  ReflectionAnswer? getAnswer(LifeArea area, String questionId) =>
      _readAll()[_key(area, questionId)];

  /// Every answer written for [area] so far, keyed by question id — used to
  /// count how many of that area's questions have been answered.
  Map<String, ReflectionAnswer> getAnswersForArea(LifeArea area) {
    final prefix = '${area.name}|';
    final all = _readAll();
    return {
      for (final entry in all.entries)
        if (entry.key.startsWith(prefix)) entry.value.questionId: entry.value,
    };
  }

  /// A blank (or all-whitespace) [answerText] removes the entry entirely
  /// rather than storing an empty string, so [getAnswer] and "has the user
  /// answered this question" stay the same question — same rule
  /// [AreaVisionRepository.setVision] uses for a whole area's vision.
  Future<void> setAnswer(
    LifeArea area,
    String questionId, {
    required String answerText,
  }) async {
    final all = _readAll();
    final key = _key(area, questionId);
    final trimmed = answerText.trim();
    if (trimmed.isEmpty) {
      all.remove(key);
    } else {
      all[key] = ReflectionAnswer(
        area: area,
        questionId: questionId,
        answerText: trimmed,
        answeredDate: DateTime.now(),
      );
    }
    await _saveAll(all);
  }

  /// Used by the "reset all data" action — there's no undo.
  Future<void> clear() async {
    await _prefs.remove(_storageKey);
  }

  Future<void> _saveAll(Map<String, ReflectionAnswer> answers) async {
    final encoded = jsonEncode(
      answers.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs.setString(_storageKey, encoded);
  }
}
