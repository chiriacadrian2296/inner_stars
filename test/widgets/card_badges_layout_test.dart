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
import 'package:inner_stars/utils/star_card_info.dart';
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

  final loaded = Star(
    id: 1,
    projectId: 1,
    slotSequence: 1,
    title:
        'Un titolo molto lungo che occupa tre righe nella tile della griglia',
    description: 'Descrizione',
    createdAt: created,
    achievedDate: created,
    intensity: 5,
    media: [
      media(StarMediaKind.voice, 'a'),
      media(StarMediaKind.photo, 'b'),
      media(StarMediaKind.video, 'c'),
      media(StarMediaKind.link, 'd'),
    ],
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
      testWidgets('grid tile at $width px, text scale $scale: no overflow', (
        tester,
      ) async {
        final data = GalleryStarData.fromStar(
          loaded,
          null,
          badges: starCardBadges(loaded, colors, strings),
        );
        await pump(
          tester,
          SizedBox(
            width: width,
            height: width * 1.5,
            child: GalleryStarTile(data: data),
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the victory tooltip holds every badge without overflow', (
    tester,
  ) async {
    await pump(
      tester,
      SizedBox(
        width: 348,
        child: SkyStarTooltip(
          star: loaded,
          project: null,
          onClose: () {},
          onView: () {},
          onEdit: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // intensity, description and four attachments
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
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
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
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

  projectAndAreaLayoutTests();
}

// ---- Constellation and area cards ----------------------------------------

void projectAndAreaLayoutTests() {
  const colors = AppColors.dark;
  const strings = StringsIt();

  final project = Project(
    id: 1,
    name: 'Una costellazione con un nome piuttosto lungo',
    area: LifeArea.physical,
    iconSlug: 'pool',
    createdAt: DateTime(2026, 1, 1),
  );

  final fullProject = [
    for (final label in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
      CardBadge(
        icon: Icons.star_rounded,
        value: '12/30',
        iconColor: colors.gold,
        valueColor: colors.text,
        semanticLabel: label,
        secondary: label != 'a',
      ),
  ];

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
    testWidgets('constellation tile at $width px has no overflow', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(
          width: width,
          height: width * 1.5,
          child: GalleryProjectTile(
            data: GalleryProjectData(
              project: project,
              renderStars: const [],
              edges: const [],
              totalStars: 30,
              litStars: 12,
              badges: fullProject,
            ),
          ),
        ),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('area tile at $width px has no overflow', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: width,
          height: width * 1.5,
          child: GalleryAreaTile(
            data: GalleryAreaData(
              area: LifeArea.physical,
              constellationCount: 4,
              starCount: 30,
              badges: fullProject,
            ),
          ),
        ),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('constellation and area tooltips hold many badges', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 348,
            child: SkyConstellationTooltip(
              project: project,
              badges: fullProject,
              shape: null,
              onClose: () {},
              onView: () {},
              onAddStar: () {},
              onShare: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
          SizedBox(
            width: 348,
            child: SkyAreaTooltip(
              area: LifeArea.physical,
              badges: fullProject,
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
    );
    expect(tester.takeException(), isNull);
  });
}
