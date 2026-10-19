import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/moodboard_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

void main() {
  testWidgets('the full board disables adding and explains the 12-item limit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await MoodboardRepository.create();
    await repo.save(LifeArea.physical, [
      for (var i = 0; i < 12; i++)
        MoodboardItem(
          id: 'q$i',
          kind: MoodboardKind.quote,
          content: 'Quote $i',
        ),
    ]);
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MoodboardScreen(area: LifeArea.physical, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('moodboard-add')),
    );
    expect(button.onPressed, isNull);
    expect(find.text(const StringsIt().moodboardLimitReached), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding offers photos and quotes without video', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await MoodboardRepository.create();
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MoodboardScreen(area: LifeArea.physical, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moodboard-add')));
    await tester.pumpAndSettle();
    expect(
      find.text(const StringsIt().photoLabel.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(const StringsIt().moodboardQuote.toUpperCase()),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.video_library_outlined), findsNothing);
    expect(
      find.text(const StringsIt().moodboardVideo.toUpperCase()),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
