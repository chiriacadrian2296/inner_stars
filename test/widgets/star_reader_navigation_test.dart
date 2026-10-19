import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/screens/star_reader_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Star star(int id) => Star(
    id: id.toString(),
    projectId: '1',
    slotSequence: id,
    title: 'Star $id',
    createdAt: DateTime(2026, 1, id),
    achievedDate: DateTime(2026, 1, id),
    intensity: 3,
  );

  Future<void> pumpReader(WidgetTester tester, List<Star> stars) async {
    SharedPreferences.setMockInitialValues({});
    final repository = StarRepository(await SharedPreferences.getInstance());
    final tours = InMemoryTourStorage();
    await tours.markCompleted('star-reader');
    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: TourScope(
          storage: tours,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: StarReaderScreen(
              repository: repository,
              initialStars: stars,
              startIndex: 0,
              projectsById: const {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Vedi hides previous and next for a one-item list', (
    tester,
  ) async {
    await pumpReader(tester, [star(1)]);

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('Vedi shows previous and next from two items onward', (
    tester,
  ) async {
    await pumpReader(tester, [star(1), star(2)]);

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
