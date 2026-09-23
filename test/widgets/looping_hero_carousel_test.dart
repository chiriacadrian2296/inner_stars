import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/looping_hero_carousel.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('first and last areas center and open across repeated cycles', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    int? tapped;
    var freeScroll = false;
    late StateSetter changeMode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: StatefulBuilder(
                builder: (context, setState) {
                  changeMode = setState;
                  return LoopingHeroCarousel(
                    freeScroll: freeScroll,
                    onTap: (index) => tapped = index,
                    children: List.generate(
                      8,
                      (index) => ColoredBox(
                        color: Colors.blue,
                        child: Center(child: Text('Area $index')),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final carousel = find.byType(LoopingHeroCarousel);
    final center = tester.getCenter(carousel);
    Future<void> expectArea(int index) async {
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(tapped, index);
      expect(tester.takeException(), isNull);
    }

    await expectArea(0);
    tapped = null;
    await tester.tapAt(center + const Offset(-170, -80));
    await tester.pumpAndSettle();
    expect(tapped, isNull, reason: 'A side card centers without opening');
    await expectArea(7);
    tapped = null;
    await tester.tapAt(center + const Offset(170, -80));
    await tester.pumpAndSettle();
    expect(tapped, isNull);
    await expectArea(0);
    tapped = null;
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(tapped, isNull, reason: 'Arrow navigation does not open an area');
    await expectArea(1);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await expectArea(0);
    // A fast fling spanning several slots must still advance only once.
    await tester.fling(carousel, const Offset(-280, 0), 2500);
    await tester.pumpAndSettle();
    await expectArea(1);
    await tester.fling(carousel, const Offset(280, 0), 2500);
    await tester.pumpAndSettle();
    await expectArea(0);
    for (var i = 1; i <= 17; i++) {
      await tester.timedDrag(
        carousel,
        const Offset(80, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      await expectArea((-i) % 8);
    }
    for (var i = 1; i <= 17; i++) {
      await tester.timedDrag(
        carousel,
        const Offset(-80, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      await expectArea((-17 + i) % 8);
    }
    changeMode(() => freeScroll = true);
    await tester.pumpAndSettle();
    await expectArea(0);
    final mouse = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 12; i++) {
      await mouse.moveTo(center + Offset(-20.0 * i, 0));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await mouse.up();
    await tester.pumpAndSettle();
    await expectArea(3);
    changeMode(() => freeScroll = false);
    await tester.pumpAndSettle();
    await expectArea(3);
    await tester.fling(carousel, const Offset(-280, 0), 2500);
    await tester.pumpAndSettle();
    await expectArea(4);
  });

  testWidgets('hides arrow navigation on native mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: LoopingHeroCarousel(
              onTap: (_) {},
              children: List.generate(
                3,
                (_) => const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
