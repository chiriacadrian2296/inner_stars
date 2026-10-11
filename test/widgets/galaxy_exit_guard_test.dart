import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/galaxy_exit_guard.dart';

void main() {
  const strings = StringsIt();
  late int exitCalls;
  setUp(() {
    exitCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') exitCalls++;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, {bool Function()? consumeBack}) async {
    await tester.pumpWidget(
      StringsScope(
        strings: strings,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: GalaxyExitGuard(
            consumeBack: consumeBack,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Other page')),
                    ),
                  ),
                  child: const Text('Open page'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('Back requires confirmation and Cancel keeps the app open', (
    tester,
  ) async {
    await pump(tester);
    await back(tester);
    expect(find.text(strings.exitAppBody), findsOneWidget);
    expect(exitCalls, 0);
    await tester.tap(
      find.widgetWithText(TextButton, strings.cancel.toUpperCase()),
    );
    await tester.pumpAndSettle();
    expect(exitCalls, 0);
    expect(find.text(strings.exitAppBody), findsNothing);

    await back(tester);
    await back(tester); // System Back dismisses the popup safely.
    expect(exitCalls, 0);
    expect(find.text(strings.exitAppBody), findsNothing);

    await back(tester);
    await tester.tap(
      find.widgetWithText(ElevatedButton, strings.exitAppConfirm.toUpperCase()),
    );
    await tester.pumpAndSettle();
    expect(exitCalls, 1);
  });

  testWidgets('Back closes a Galaxy panel before offering to exit', (
    tester,
  ) async {
    var panelOpen = true;
    await pump(
      tester,
      consumeBack: () {
        if (!panelOpen) return false;
        panelOpen = false;
        return true;
      },
    );
    await back(tester);
    expect(panelOpen, isFalse);
    expect(find.text(strings.exitAppBody), findsNothing);
    expect(exitCalls, 0);
    await back(tester);
    expect(find.text(strings.exitAppBody), findsOneWidget);
  });

  testWidgets('Back from another page returns to Galaxy without prompting', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Open page'));
    await tester.pumpAndSettle();
    await back(tester);
    expect(find.text('Other page'), findsNothing);
    expect(find.text(strings.exitAppBody), findsNothing);
    expect(exitCalls, 0);
  });
}
