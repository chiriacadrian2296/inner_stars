import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/app_modals.dart';
import 'package:inner_stars/widgets/animated_presence.dart';
import 'package:inner_stars/widgets/staggered_entrance.dart';

Widget _app(Widget home, {bool reduceMotion = false}) {
  return MaterialApp(
    theme: buildAppTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  group('StaggeredEntrance', () {
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(StaggeredEntrance),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;

    testWidgets('starts hidden and is fully visible once settled', (
      tester,
    ) async {
      await _app(
        const Scaffold(body: StaggeredEntrance(index: 2, child: Text('row'))),
      ).pump(tester);
      expect(opacity(tester), 0);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('an item outside the screen just appears', (tester) async {
      await _app(
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 3000),
                StaggeredEntrance(index: 1, child: Text('below the fold')),
              ],
            ),
          ),
        ),
      ).pump(tester);
      await tester.pump(); // layout done -> visibility decided
      await tester.pump();
      expect(opacity(tester), 1);
    });

    testWidgets('an on-screen item animates instead', (tester) async {
      await _app(
        const Scaffold(body: StaggeredEntrance(index: 20, child: Text('row'))),
      ).pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(opacity(tester), lessThan(1)); // delayed, not skipped
      // The delay is a plain timer, which pumpAndSettle alone doesn't wait
      // for once nothing else is animating.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('appears immediately under reduced motion', (tester) async {
      await _app(
        const Scaffold(body: StaggeredEntrance(index: 3, child: Text('row'))),
        reduceMotion: true,
      ).pump(tester);
      await tester.pump();
      expect(opacity(tester), 1);
    });

    testWidgets('enabled: false shows the child as-is', (tester) async {
      await _app(
        const Scaffold(
          body: StaggeredEntrance(index: 3, enabled: false, child: Text('row')),
        ),
      ).pump(tester);
      expect(opacity(tester), 1);
    });

    testWidgets('changing replayKey plays it again', (tester) async {
      Widget build(Object key) => _app(
        Scaffold(
          body: StaggeredEntrance(
            index: 0,
            replayKey: key,
            child: const Text('row'),
          ),
        ),
      );
      await build('a').pump(tester);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);

      await build('b').pump(tester);
      expect(opacity(tester), 0);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });
  });

  group('StaggeredEntrance axis', () {
    Offset startOffset(WidgetTester tester) => tester
        .widget<SlideTransition>(find.byType(SlideTransition).last)
        .position
        .value;

    testWidgets('vertical rises from below', (tester) async {
      await _app(
        const Scaffold(body: StaggeredEntrance(index: 1, child: Text('a'))),
      ).pump(tester);
      final offset = startOffset(tester);
      expect(offset.dx, 0);
      expect(offset.dy, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('horizontal enters from the reading-direction end', (
      tester,
    ) async {
      await _app(
        const Scaffold(
          body: StaggeredEntrance(
            index: 1,
            axis: Axis.horizontal,
            child: Text('a'),
          ),
        ),
      ).pump(tester);
      expect(startOffset(tester).dx, greaterThan(0));
      expect(startOffset(tester).dy, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('horizontal mirrors for right-to-left', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: StaggeredEntrance(
                index: 1,
                axis: Axis.horizontal,
                child: Text('a'),
              ),
            ),
          ),
        ),
      );
      expect(startOffset(tester).dx, lessThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('all() numbers children from start', (tester) async {
      final wrapped = StaggeredEntrance.all(const [
        Text('a'),
        Text('b'),
      ], start: 3);
      expect(wrapped.map((w) => (w as StaggeredEntrance).index), [3, 4]);
    });
  });

  group('AnimatedPresence', () {
    Widget row(bool visible) => _app(
      Scaffold(
        body: Row(
          children: [
            const Expanded(child: SizedBox(key: Key('field'))),
            AnimatedPresence(
              visible: visible,
              child: const SizedBox(key: Key('button'), width: 100, height: 40),
            ),
          ],
        ),
      ),
    );

    double fieldWidth(WidgetTester tester) =>
        tester.getSize(find.byKey(const Key('field'))).width;

    testWidgets('starts hidden and the neighbour takes the whole row', (
      tester,
    ) async {
      await row(false).pump(tester);
      expect(find.byKey(const Key('button')), findsNothing);
      expect(fieldWidth(tester), 800);
    });

    testWidgets('animates in, opening its space, then out again', (
      tester,
    ) async {
      await row(false).pump(tester);
      await row(true).pump(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final mid = fieldWidth(tester);
      expect(find.byKey(const Key('button')), findsOneWidget);
      expect(mid, lessThan(800)); // already giving way
      expect(mid, greaterThan(700)); // but not finished

      await tester.pumpAndSettle();
      expect(fieldWidth(tester), 700);

      await row(false).pump(tester);
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-exit: still there, still animating — not popped out.
      expect(find.byKey(const Key('button')), findsOneWidget);
      expect(fieldWidth(tester), greaterThan(700));
      expect(fieldWidth(tester), lessThan(800));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('button')), findsNothing);
      expect(fieldWidth(tester), 800);
    });

    testWidgets('appears and vanishes at once under reduced motion', (
      tester,
    ) async {
      Widget r(bool v) => _app(
        Scaffold(
          body: Row(
            children: [
              const Expanded(child: SizedBox(key: Key('field'))),
              AnimatedPresence(
                visible: v,
                child: const SizedBox(key: Key('button'), width: 100),
              ),
            ],
          ),
        ),
        reduceMotion: true,
      );
      await r(true).pump(tester);
      await tester.pumpAndSettle();
      expect(fieldWidth(tester), 700);
      await r(false).pump(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('button')), findsNothing);
    });
  });

  group('app modals and route transitions', () {
    testWidgets('showAppDialog opens and dismisses', (tester) async {
      await _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('hello')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ).pump(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsNothing);
    });

    testWidgets('showAppSheet opens and dismisses', (tester) async {
      await _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 120, child: Text('sheet')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ).pump(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
    });

    testWidgets('pushed routes animate in and settle, pop returns', (
      tester,
    ) async {
      await _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('second')),
                ),
              ),
              child: const Text('first'),
            ),
          ),
        ),
      ).pump(tester);
      await tester.tap(find.text('first'));
      await tester.pump(); // route built at animation value 0
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('second'), findsOneWidget); // mid-transition
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('second'), findsNothing);
      expect(find.text('first'), findsOneWidget);
    });
  });
}

extension on Widget {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(this);
}
