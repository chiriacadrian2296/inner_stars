import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/screens/area_image_screen.dart';
import 'package:inner_stars/widgets/area_artwork_header.dart';

void main() {
  const asset = 'assets/images/1. Physical.png';

  testWidgets('collapses to the bottom band and expands when scrolled back', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: AreaArtworkHeader(
                  asset: asset,
                  imageSize: 360,
                  label: 'View image',
                  onTap: () {},
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final crop = find.descendant(
      of: find.byType(SliverPersistentHeader),
      matching: find.byType(ClipRect),
    );
    expect(tester.getSize(crop).height, 360);
    final zoom = find.descendant(
      of: find.byType(SliverPersistentHeader),
      matching: find.byType(Transform),
    );
    expect(tester.widget<Transform>(zoom).transform.getMaxScaleOnAxis(), 1);
    scroll.jumpTo(130);
    await tester.pumpAndSettle();
    expect(tester.widget<Transform>(zoom).transform.getMaxScaleOnAxis(), 1);
    scroll.jumpTo(500);
    await tester.pumpAndSettle();
    expect(tester.getSize(crop).height, closeTo(360 * .23, .01));
    expect(tester.getTopLeft(crop).dy, 0);
    expect(tester.widget<Transform>(zoom).transform.getMaxScaleOnAxis(), 1.25);
    final imageBox = tester.renderObject<RenderBox>(find.byType(Image));
    final tagline = imageBox.localToGlobal(const Offset(180, 360 * .86));
    expect(tagline.dy, greaterThan(tester.getTopLeft(crop).dy));
    expect(tagline.dy, lessThan(tester.getBottomLeft(crop).dy));
    expect(tester.getSize(find.byType(Image)).height, 360);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(crop).height, 360);
    expect(tester.widget<Transform>(zoom).transform.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed header opens viewer and closing preserves scroll', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: AreaArtworkHeader(
                    asset: asset,
                    imageSize: 360,
                    label: 'View image',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AreaImageScreen(asset: asset),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1200)),
              ],
            ),
          ),
        ),
      ),
    );
    scroll.jumpTo(500);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    // Pinch out, then pan the zoomed artwork.
    final first = await tester.startGesture(const Offset(320, 300), pointer: 1);
    final second = await tester.startGesture(
      const Offset(480, 300),
      pointer: 2,
    );
    await first.moveTo(const Offset(220, 300));
    await second.moveTo(const Offset(580, 300));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.drag(find.byType(InteractiveViewer), const Offset(30, 20));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AreaImageScreen), findsNothing);
    expect(scroll.offset, 500);
    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AreaImageScreen), findsNothing);
  });
}
