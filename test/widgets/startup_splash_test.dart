import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/startup_splash.dart';

class _Destination extends StatefulWidget {
  const _Destination();

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('Destination $taps'),
    ),
  );
}

void main() {
  Widget app({
    required bool ready,
    bool failed = false,
    bool quiet = false,
    required VoidCallback onDismissed,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: quiet),
      child: StartupSplash(
        ready: ready,
        failed: failed,
        loadingLabel: 'Loading',
        tagline: 'Every effort is a star.',
        onDismissed: onDismissed,
        child: const _Destination(),
      ),
    ),
  );

  testWidgets(
    'waits for readiness, blocks input and preserves destination State',
    (tester) async {
      var dismissed = 0;
      Widget build(bool ready) =>
          app(ready: ready, onDismissed: () => dismissed++);
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('startup-splash')), findsOneWidget);
      final destination = tester.state<_DestinationState>(
        find.byType(_Destination),
      );
      await tester.tap(find.text('Destination 0'), warnIfMissed: false);
      expect(destination.taps, 0);
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(find.byKey(const ValueKey('startup-splash')), findsNothing);
      expect(tester.state(find.byType(_Destination)), same(destination));
      await tester.tap(find.text('Destination 0'));
      await tester.pump();
      expect(destination.taps, 1);
      // A later rebuild/resume must not reintroduce a cold-start splash.
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('startup-splash')), findsNothing);
      expect(dismissed, 1);
    },
  );

  testWidgets('a fast launch does not wait for the three-second glow', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      app(ready: true, onDismissed: () => dismissed = true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(dismissed, isTrue);
    expect(find.byKey(const ValueKey('startup-splash')), findsNothing);
  });

  testWidgets('reduced motion keeps the glow still and shortens the exit', (
    tester,
  ) async {
    var dismissed = false;
    Widget build(bool ready) =>
        app(ready: ready, quiet: true, onDismissed: () => dismissed = true);
    await tester.pumpWidget(build(false));
    final glow = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('startup-splash')),
            matching: find.byType(Opacity),
          ),
        )
        .map((w) => w.opacity)
        .toList();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byKey(const ValueKey('startup-splash')),
              matching: find.byType(Opacity),
            ),
          )
          .map((w) => w.opacity)
          .toList(),
      glow,
    );
    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('startup failure reveals the error destination immediately', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      app(ready: false, onDismissed: () => dismissed = true),
    );
    await tester.pumpWidget(
      app(ready: false, failed: true, onDismissed: () => dismissed = true),
    );
    expect(find.byKey(const ValueKey('startup-splash')), findsNothing);
    expect(dismissed, isFalse);
    await tester.tap(find.text('Destination 0'));
    await tester.pump();
    expect(find.text('Destination 1'), findsOneWidget);
  });
}
