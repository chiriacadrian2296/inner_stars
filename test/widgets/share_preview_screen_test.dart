import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/screens/share_preview_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/share_arrangement.dart';
import 'package:inner_stars/widgets/shareable_goal_card.dart';

void main() {
  testWidgets('share preview offers three arrangements before sharing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SharePreviewScreen(
            shareText: 'La mia stella',
            fileName: 'stella.png',
            content: _ArrangementProbe(),
          ),
        ),
      ),
    );

    expect(find.text('Anteprima condivisione'), findsOneWidget);
    expect(find.text('Editoriale'), findsOneWidget);
    expect(find.text('Fotografica'), findsOneWidget);
    expect(find.text('Frase'), findsOneWidget);
    expect(find.text('Condividi'), findsOneWidget);
    expect(find.text('editorial'), findsOneWidget);

    await tester.tap(find.text('Fotografica'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('photographic'), findsOneWidget);

    await tester.tap(find.text('Frase'));
    await tester.pump();
    expect(find.text('statement'), findsOneWidget);
  });

  testWidgets('a real share card lays out every composition', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final createdAt = DateTime(2026, 9, 18);
    final project = Project(
      id: 1,
      name: 'Maratona',
      area: LifeArea.physical,
      iconSlug: 'flag',
      createdAt: createdAt,
    );
    final star = Star(
      id: 1,
      projectId: project.id,
      slotSequence: 1,
      title: 'Completare la mia prima maratona',
      description: 'Allenarmi con costanza e arrivare fino al traguardo.',
      createdAt: createdAt,
      targetDate: DateTime(2027, 4, 12),
    );

    await tester.pumpWidget(
      StringsScope(
        strings: const StringsIt(),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: SharePreviewScreen(
            shareText: star.title,
            fileName: 'goal.png',
            content: ShareableGoalCard(star: star, project: project),
          ),
        ),
      ),
    );

    for (final label in ['Editoriale', 'Fotografica', 'Frase']) {
      await tester.tap(find.text(label));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}

class _ArrangementProbe extends StatelessWidget {
  const _ArrangementProbe();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.indigo,
    child: Center(child: Text(ShareArrangementScope.of(context).name)),
  );
}
