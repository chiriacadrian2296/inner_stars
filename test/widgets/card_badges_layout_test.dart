import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/habit.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star.dart';
import 'package:inner_stars/models/star_media.dart';
import 'package:inner_stars/theme/app_colors.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/project_card_info.dart';
import 'package:inner_stars/utils/star_card_info.dart';
import 'package:inner_stars/widgets/badge_rows.dart';
import 'package:inner_stars/widgets/gallery/gallery_cards.dart';
import 'package:inner_stars/widgets/sky_area_tooltip.dart';
import 'package:inner_stars/widgets/sky_constellation_tooltip.dart';
import 'package:inner_stars/widgets/sky_pulsar_tooltip.dart';
import 'package:inner_stars/widgets/sky_star_tooltip.dart';

void main() {
  const colors = AppColors.dark;
  const strings = StringsIt();
  final created = DateTime(2026, 1, 1);

  StarMedia media(StarMediaKind kind, String id) => StarMedia(
    id: id,
    kind: kind,
    path: kind == StarMediaKind.link ? null : 'file-$id',
    url: kind == StarMediaKind.link ? 'https://example.com' : null,
    createdAt: created,
  );

  Star victory({List<StarMedia> extras = const []}) => Star(
    id: 1,
    projectId: 1,
    slotSequence: 1,
    title:
        'Un titolo molto lungo che occupa tre righe nella tile della griglia',
    createdAt: created,
    achievedDate: created,
    intensity: 5,
    media: extras,
  );
  final loaded = victory(
    extras: [
      media(StarMediaKind.voice, 'a'),
      media(StarMediaKind.photo, 'b'),
      media(StarMediaKind.video, 'c'),
      media(StarMediaKind.link, 'd'),
    ],
  );
  final project = Project(
    id: 1,
    name: 'Una costellazione con un nome piuttosto lungo',
    area: LifeArea.physical,
    iconSlug: 'pool',
    createdAt: created,
  );

  CardBadges constellationRows({required bool full}) => projectCardBadges(
    stars: full ? [loaded, victory()] : const [],
    habits: const [],
    slotCount: full ? 8 : 0,
    colors: colors,
    strings: strings,
  );
  CardBadges areaRows({required bool full}) => areaCardBadges(
    constellationCount: full ? 4 : 0,
    stars: full ? [loaded] : const [],
    habits: const [],
    emptySlots: full ? 5 : 0,
    colors: colors,
    strings: strings,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(360, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, appChild) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: appChild!,
          ),
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [90.0, 120.0, 170.0, 320.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('tiles at $width px, text $scale: no overflow', (
        tester,
      ) async {
        await pump(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tile in <Widget>[
                GalleryStarTile(
                  data: GalleryStarData.fromStar(
                    loaded,
                    null,
                    badges: starCardBadges(loaded, colors, strings),
                  ),
                ),
                GalleryProjectTile(
                  data: GalleryProjectData(
                    project: project,
                    renderStars: const [],
                    edges: const [],
                    totalStars: 30,
                    litStars: 12,
                    badges: constellationRows(full: true),
                  ),
                ),
                GalleryAreaTile(
                  data: GalleryAreaData(
                    area: LifeArea.physical,
                    constellationCount: 4,
                    starCount: 30,
                    badges: areaRows(full: true),
                  ),
                ),
              ])
                SizedBox(width: width, height: width * 1.5, child: tile),
            ],
          ),
          size: const Size(400, 1800),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('badge size depends on the width only, not the card or data', (
    tester,
  ) async {
    double textSizeOf(WidgetTester t, Finder f) =>
        t.widget<Text>(f.first).style!.fontSize!;

    Future<double> sizeFor(WidgetTester tester, CardBadges badges) async {
      await pump(
        tester,
        SizedBox(width: 100, child: BadgeRows(rows: badges.rows, maxScale: 1)),
      );
      return textSizeOf(tester, find.byType(Text));
    }

    final sizes = <double>{
      await sizeFor(tester, starCardBadges(loaded, colors, strings)),
      await sizeFor(tester, constellationRows(full: true)),
      await sizeFor(tester, constellationRows(full: false)),
      await sizeFor(tester, areaRows(full: true)),
      await sizeFor(tester, areaRows(full: false)),
    };
    expect(sizes.length, 1);
  });

  testWidgets('every tooltip holds its fixed badges without overflow', (
    tester,
  ) async {
    Widget box(Widget child) => SizedBox(width: 348, child: child);
    final habit = Habit(
      id: 1,
      projectId: 1,
      title: 'Nuoto',
      createdAt: created,
      frequency: HabitFrequency.weekly,
      targetPerPeriod: 3,
    );
    await pump(
      tester,
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            box(
              SkyStarTooltip(
                star: loaded,
                project: null,
                onClose: () {},
                onView: () {},
                onEdit: () {},
              ),
            ),
            box(
              SkyPulsarTooltip(
                habit: habit,
                project: null,
                countsByDay: const {},
                isLit: false,
                onClose: () {},
                onView: () {},
                onToday: () {},
                todayActionIcon: Icons.local_fire_department_rounded,
                todayActionLabel: 'Accendi',
                onEdit: () {},
              ),
            ),
            box(
              SkyConstellationTooltip(
                project: project,
                badges: constellationRows(full: true),
                shape: null,
                onClose: () {},
                onView: () {},
                onAddStar: () {},
                onShare: () {},
                onEdit: () {},
                onDelete: () {},
              ),
            ),
            box(
              SkyAreaTooltip(
                area: LifeArea.physical,
                badges: areaRows(full: true),
                onClose: () {},
                onView: () {},
                onVision: () {},
                onMoodboard: () {},
                onReflections: () {},
                onNewConstellation: () {},
              ),
            ),
          ],
        ),
      ),
      size: const Size(400, 1200),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the habit tooltip shows the week count and updates', (
    tester,
  ) async {
    final habit = Habit(
      id: 1,
      projectId: 1,
      title: 'Nuoto',
      createdAt: created,
      frequency: HabitFrequency.weekly,
      targetPerPeriod: 3,
    );
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    Widget tooltip(Map<DateTime, int> counts) => SizedBox(
      width: 348,
      child: SkyPulsarTooltip(
        habit: habit,
        project: null,
        countsByDay: counts,
        isLit: false,
        onClose: () {},
        onView: () {},
        onToday: () {},
        todayActionIcon: Icons.local_fire_department_rounded,
        todayActionLabel: 'Accendi',
        onEdit: () {},
      ),
    );

    await pump(tester, tooltip({}));
    expect(find.text('0/3'), findsOneWidget);
    await pump(tester, tooltip({day: 1}));
    expect(find.text('1/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
