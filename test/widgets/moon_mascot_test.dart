import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/moon_mascot.dart';

void main() {
  Widget harness({
    MoonExpression expression = MoonExpression.neutral,
    double size = 180,
    bool animate = true,
    bool disableAnimations = false,
    MoonMascotController? controller,
    MoonPalette palette = MoonPalette.original,
    MoonAppearance? appearance,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: MoonMascot(
          key: const Key('moon'),
          expression: expression,
          size: size,
          animate: animate,
          controller: controller,
          palette: palette,
          appearance: appearance,
        ),
      ),
    ),
  );

  for (final expression in MoonExpression.values) {
    testWidgets('renders ${expression.name} without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(expression: expression, disableAnimations: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MoonMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps its requested size at icon scale', (tester) async {
    await tester.pumpWidget(harness(size: 32, disableAnimations: true));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('moon'))),
      const Size.square(32),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the app palette with the same mascot API', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(palette: MoonPalette.app, disableAnimations: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MoonMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the gold palette with the original face', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(palette: MoonPalette.gold, disableAnimations: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MoonMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders custom layer visibility and extreme hues safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        disableAnimations: true,
        appearance: const MoonAppearance(
          showEyeStars: false,
          showEyeAccent: false,
          showOuterGlow: false,
          showBlush: false,
          showMouth: false,
          showBrows: false,
          showForeheadShine: false,
          showRim: false,
          useBodyGradient: false,
          bodyHue: 360,
          rimHue: 0,
          glowHue: 360,
          faceHue: 0,
          starHue: 360,
          eyeAccentHue: 0,
          blushHue: 360,
          shineHue: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MoonMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion settles without ambient frames', (tester) async {
    await tester.pumpWidget(harness(disableAnimations: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes active blink timers and tickers safely', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(seconds: 25));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a complete blink keeps curve inputs inside their domain', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    // The first blink is scheduled no later than five seconds. Small pumps
    // exercise the closing and reopening frames instead of jumping over them.
    for (var frame = 0; frame < 380; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('transitions through every expression without curve errors', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    for (final expression in MoonExpression.values.skip(1)) {
      await tester.pumpWidget(harness(expression: expression));
      for (var frame = 0; frame < 28; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
    }
  });

  for (final reaction in MoonReaction.values) {
    testWidgets('plays ${reaction.name} through its final frame', (
      tester,
    ) async {
      final controller = MoonMascotController();
      await tester.pumpWidget(harness(controller: controller));
      expect(controller.isAttached, isTrue);
      var completed = false;
      controller.play(reaction).then((_) => completed = true);
      for (var frame = 0; frame < 65; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      expect(completed, isTrue);
    });
  }

  testWidgets('a new reaction completes and replaces the previous one', (
    tester,
  ) async {
    final controller = MoonMascotController();
    await tester.pumpWidget(harness(controller: controller));
    var acknowledgeCompleted = false;
    var celebrateCompleted = false;
    controller
        .play(MoonReaction.acknowledge)
        .then((_) => acknowledgeCompleted = true);
    await tester.pump(const Duration(milliseconds: 120));
    controller
        .play(MoonReaction.celebrate)
        .then((_) => celebrateCompleted = true);
    await tester.pump();
    expect(acknowledgeCompleted, isTrue);
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(celebrateCompleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pauses safely with the app lifecycle and resumes motion', (
    tester,
  ) async {
    final controller = MoonMascotController();
    await tester.pumpWidget(harness(controller: controller));
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await controller.play(MoonReaction.celebrate);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    controller.play(MoonReaction.acknowledge);
    for (var frame = 0; frame < 36; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaction control is a safe no-op with reduced motion', (
    tester,
  ) async {
    final detached = MoonMascotController();
    await detached.play(MoonReaction.celebrate);
    final attached = MoonMascotController();
    await tester.pumpWidget(
      harness(controller: attached, disableAnimations: true),
    );
    await attached.play(MoonReaction.celebrate);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
