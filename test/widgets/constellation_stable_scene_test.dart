import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/constellation_map/constellation_map_view.dart';
import 'package:inner_stars/widgets/constellation_painter.dart';

void main() {
  testWidgets('resizing cards lays them out once, without a second jump', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = TransformationController(
      Matrix4.identity()
        ..translateByDouble(300, 120, 0, 1)
        ..scaleByDouble(0.6, 0.6, 1, 1),
    );
    addTearDown(camera.dispose);
    Widget map(double cardScale) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ConstellationMapView(
          stars: [
            for (var i = 0; i < 4; i++)
              ConstellationStar(
                entityId: (i + 1).toString(),
                position: Offset(0.2 + i * 0.2, 0.3 + (i % 2) * 0.2),
                kind: StarKind.unlit,
                lit: false,
                label: 'Stella ${i + 1}',
                slotSequence: i + 1,
              ),
          ],
          edges: const [(0, 1), (1, 2), (2, 3)],
          transformation: camera,
          canvasSize: const Size(1000, 1000),
          fitScale: 0.6,
          tooltipScale: cardScale,
          matchTooltipFrameToNode: true,
          onStarTap: (_) {},
          connectorStyle: ConstellationConnectorStyle.numbered,
          cardLayout: ConstellationCardLayout.bottomGrid,
          cardBuilder: (_, star) => SizedBox(
            width: 300,
            // Uneven heights: the grid's rows depend on measured sizes.
            height: 70 + star.slotSequence! * 12.0,
            child: Text(star.label),
          ),
        ),
      ),
    );
    await tester.pumpWidget(map(0.45));
    await tester.pumpAndSettle();

    // pumpWidget draws exactly the first frame after the change.
    await tester.pumpWidget(map(0.6));
    final firstFrame = [
      for (var i = 1; i <= 4; i++) tester.getRect(find.text('Stella $i')),
    ];
    await tester.pumpAndSettle();
    for (var i = 1; i <= 4; i++) {
      final settled = tester.getRect(find.text('Stella $i'));
      expect(settled.topLeft.dx, closeTo(firstFrame[i - 1].left, 0.01));
      expect(settled.topLeft.dy, closeTo(firstFrame[i - 1].top, 0.01));
    }
  });

  testWidgets('panning and zooming transform the scene without rebuilding it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = TransformationController(
      Matrix4.identity()
        ..translateByDouble(300, 200, 0, 1)
        ..scaleByDouble(0.6, 0.6, 1, 1),
    );
    addTearDown(camera.dispose);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ConstellationMapView(
            stars: const [
              ConstellationStar(
                entityId: '1',
                position: Offset(0.3, 0.3),
                kind: StarKind.unlit,
                lit: false,
                label: 'A',
                slotSequence: 1,
              ),
              ConstellationStar(
                entityId: '2',
                position: Offset(0.7, 0.6),
                kind: StarKind.lit,
                lit: true,
                label: 'B',
                slotSequence: 2,
              ),
            ],
            edges: const [(0, 1)],
            transformation: camera,
            canvasSize: const Size(1000, 1000),
            fitScale: 0.6,
            onStarTap: (_) {},
            connectorStyle: ConstellationConnectorStyle.numbered,
            cardLayout: ConstellationCardLayout.bottomGrid,
            cardBuilder: (_, star) {
              builds++;
              return SizedBox(width: 300, height: 80, child: Text(star.label));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('A'),
      matching: find.byType(Positioned),
    );
    final before = tester.widget(card.first);
    final rectBefore = tester.getRect(find.text('A'));
    final buildsBefore = builds;

    // Twice the zoom, shifted: a pure camera change.
    camera.value = Matrix4.identity()
      ..translateByDouble(250, 150, 0, 1)
      ..scaleByDouble(1.2, 1.2, 1, 1);
    await tester.pump();

    expect(identical(tester.widget(card.first), before), isTrue);
    expect(builds, buildsBefore);
    final rectAfter = tester.getRect(find.text('A'));
    final expectedTopLeft =
        const Offset(250, 150) +
        (rectBefore.topLeft - const Offset(300, 200)) * 2;
    expect(rectAfter.left, closeTo(expectedTopLeft.dx, 0.01));
    expect(rectAfter.top, closeTo(expectedTopLeft.dy, 0.01));
    expect(rectAfter.width, closeTo(rectBefore.width * 2, 0.01));
  });
}
