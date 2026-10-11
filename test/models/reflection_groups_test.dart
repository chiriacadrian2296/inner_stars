import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/app_strings.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_ro.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  final languages = <String, AppStrings>{
    'en': StringsEn(),
    'it': const StringsIt(),
    'ro': const StringsRo(),
  };

  for (final area in LifeArea.values) {
    test('${area.name}: 5 groups of 5, same shape in every language', () {
      for (final entry in languages.entries) {
        final groups = area.reflectionGroups(entry.value);
        expect(groups, hasLength(5), reason: entry.key);
        for (final group in groups) {
          expect(group.title.trim(), isNotEmpty, reason: entry.key);
          expect(group.questions, hasLength(5), reason: entry.key);
          for (final q in group.questions) {
            expect(q.trim(), isNotEmpty, reason: entry.key);
          }
        }
        expect(area.reflectionQuestions(entry.value), hasLength(25));
      }
    });

    test('${area.name}: no duplicate questions within a language', () {
      for (final entry in languages.entries) {
        final all = area.reflectionQuestions(entry.value);
        expect(all.toSet(), hasLength(all.length), reason: entry.key);
      }
    });
  }
}
