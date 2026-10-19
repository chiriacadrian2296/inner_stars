import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/reflection_answer_repository.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'getAnswer() is null for a question that has never been answered',
    () async {
      final repo = await ReflectionAnswerRepository.create();

      expect(repo.getAnswer(LifeArea.physical, '0'), isNull);
    },
  );

  test('setAnswer() persists and getAnswer() reads it back', () async {
    final repo = await ReflectionAnswerRepository.create();

    await repo.setAnswer(
      LifeArea.physical,
      '0',
      answerText: 'Pretty good, actually.',
    );

    final answer = repo.getAnswer(LifeArea.physical, '0');
    expect(answer, isNotNull);
    expect(answer!.answerText, 'Pretty good, actually.');
  });

  test(
    'each (area, question) pair keeps its own answer independently',
    () async {
      final repo = await ReflectionAnswerRepository.create();

      await repo.setAnswer(
        LifeArea.physical,
        '0',
        answerText: 'Physical answer',
      );
      await repo.setAnswer(
        LifeArea.physical,
        '1',
        answerText: 'Second physical answer',
      );
      await repo.setAnswer(
        LifeArea.financial,
        '0',
        answerText: 'Financial answer',
      );

      expect(
        repo.getAnswer(LifeArea.physical, '0')!.answerText,
        'Physical answer',
      );
      expect(
        repo.getAnswer(LifeArea.physical, '1')!.answerText,
        'Second physical answer',
      );
      expect(
        repo.getAnswer(LifeArea.financial, '0')!.answerText,
        'Financial answer',
      );
      expect(repo.getAnswer(LifeArea.social, '0'), isNull);
    },
  );

  test('setAnswer() trims whitespace', () async {
    final repo = await ReflectionAnswerRepository.create();

    await repo.setAnswer(
      LifeArea.social,
      '0',
      answerText: '  Deep friendships.  ',
    );

    expect(
      repo.getAnswer(LifeArea.social, '0')!.answerText,
      'Deep friendships.',
    );
  });

  test(
    'setAnswer() with a blank string clears the entry rather than storing it',
    () async {
      final repo = await ReflectionAnswerRepository.create();
      await repo.setAnswer(LifeArea.spiritual, '0', answerText: 'Something');

      await repo.setAnswer(LifeArea.spiritual, '0', answerText: '   ');

      expect(repo.getAnswer(LifeArea.spiritual, '0'), isNull);
    },
  );

  test('getAnswersForArea() returns only that area\'s answers, keyed by question id', () async {
    final repo = await ReflectionAnswerRepository.create();
    await repo.setAnswer(LifeArea.physical, '0', answerText: 'A');
    await repo.setAnswer(LifeArea.physical, '2', answerText: 'B');
    await repo.setAnswer(LifeArea.financial, '0', answerText: 'C');

    final answers = repo.getAnswersForArea(LifeArea.physical);

    expect(answers.keys, {'0', '2'});
    expect(answers['0']!.answerText, 'A');
    expect(answers['2']!.answerText, 'B');
  });

  test('clear() removes every saved answer', () async {
    final repo = await ReflectionAnswerRepository.create();
    await repo.setAnswer(LifeArea.physical, '0', answerText: 'A');
    await repo.setAnswer(LifeArea.social, '0', answerText: 'B');

    await repo.clear();

    expect(repo.getAnswer(LifeArea.physical, '0'), isNull);
    expect(repo.getAnswer(LifeArea.social, '0'), isNull);
  });

  test(
    'an answer persists across repository instances (same storage)',
    () async {
      final first = await ReflectionAnswerRepository.create();
      await first.setAnswer(
        LifeArea.professional,
        '0',
        answerText: 'Meaningful work.',
      );

      final second = await ReflectionAnswerRepository.create();

      expect(
        second.getAnswer(LifeArea.professional, '0')!.answerText,
        'Meaningful work.',
      );
    },
  );
}
