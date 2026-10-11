import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/dead_star_card.dart';
import 'package:inner_stars/widgets/gallery/gallery_cards.dart';
import 'package:inner_stars/widgets/reader_entry_content.dart';
import 'package:inner_stars/widgets/search_result_card.dart';
import 'package:inner_stars/widgets/sky_pulsar_tooltip.dart';
import 'package:inner_stars/widgets/sky_star_tooltip.dart';
import 'package:inner_stars/widgets/star_type_text.dart';

void main() {
  const strings = StringsIt();
  const entrance = ReaderEntrance(
    animate: false,
    axis: Axis.vertical,
    reverse: false,
    lead: 0,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(child: SizedBox(width: 280, child: child)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final type in [StarKind.lit, StarKind.unlit, StarKind.pulsar]) {
    final date = DateTime(2026, 10, 11);
    final star = Star(
      id: 1,
      projectId: 1,
      slotSequence: 1,
      title: 'Attività',
      createdAt: date,
      achievedDate: type == StarKind.lit ? date : null,
      intensity: type == StarKind.lit ? 3 : null,
      dead: true,
    );
    final habit = Habit(
      id: 2,
      projectId: 1,
      title: 'Abitudine',
      createdAt: date,
      dead: true,
    );

    testWidgets('archived $type keeps its original icon across all labels', (
      tester,
    ) async {
      final widgets = <Widget>[
        SearchCardTextContent(
          title: 'Attività',
          eyebrow: strings.starKindDeadName,
          archivedOriginalKind: type == StarKind.pulsar
              ? type
              : star.originalKind,
        ),
        type == StarKind.pulsar
            ? SkyPulsarTooltip(
                habit: habit,
                project: null,
                countsByDay: const {},
                isLit: false,
                onClose: () {},
                onView: () {},
                onToday: () {},
                todayActionIcon: Icons.check,
                todayActionLabel: 'Completa',
                onEdit: () {},
              )
            : SkyStarTooltip(
                star: star,
                project: null,
                onClose: () {},
                onView: () {},
                onEdit: () {},
              ),
        type == StarKind.pulsar
            ? PulsarReaderContent(
                habit: habit,
                project: null,
                number: null,
                lit: false,
                streak: 0,
                weekProgress: 0,
                entrance: entrance,
              )
            : StarReaderContent(star: star, project: null, entrance: entrance),
        GalleryStarTile(
          data: type == StarKind.pulsar
              ? GalleryStarData.fromHabit(
                  habit,
                  null,
                  streak: 0,
                  pulsarLit: false,
                )
              : GalleryStarData.fromStar(star, null),
        ),
        type == StarKind.pulsar
            ? DeadStarCard.fromHabit(habit: habit)
            : DeadStarCard.fromStar(star: star),
      ];
      for (final widget in widgets) {
        await pump(tester, widget);
        final labelFinder = find.byType(StarTypeText);
        expect(labelFinder, findsOneWidget, reason: '${widget.runtimeType}');
        final label = tester.widget<StarTypeText>(labelFinder);
        expect(label.originalKind, type, reason: '${widget.runtimeType}');
        final iconFinder = find.descendant(
          of: labelFinder,
          matching: find.byType(Icon),
        );
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.icon, type.icon);
        expect(icon.color, label.style!.color);
        expect(icon.size, label.style!.fontSize! * (label.compact ? 1.4 : 1));
        final textFinder = find.descendant(
          of: labelFinder,
          matching: find.byType(Text),
        );
        expect(
          tester.getTopLeft(iconFinder).dx,
          greaterThan(tester.getTopRight(textFinder).dx),
        );
        expect(tester.takeException(), isNull, reason: '${widget.runtimeType}');
      }
    });
  }

  testWidgets(
    'archived icon follows accessibility text scaling in a narrow label',
    (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 130,
          child: StarTypeText(
            'ARCHIVIATO',
            originalKind: StarKind.pulsar,
            style: TextStyle(fontSize: 17, color: Colors.white),
          ),
        ),
        textScale: 2,
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 34);
      expect(tester.takeException(), isNull);
    },
  );
}
