import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/app_modals.dart';

/// A page with one button that runs [task] behind the progress dialog.
Widget _app(Future<void> Function() task, {void Function(Object)? onError}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              try {
                await runWithProgressDialog<void>(
                  context: context,
                  title: 'Working',
                  message: 'Please wait',
                  task: task,
                );
              } catch (error) {
                onError?.call(error);
              }
            },
            child: const Text('Go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a dialog nobody can dismiss while the task runs', (
    tester,
  ) async {
    final done = Completer<void>();
    await tester.pumpWidget(_app(() => done.future));

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Please wait'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Tapping outside does nothing.
    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Working'), findsOneWidget);

    // Neither does the back button.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Working'), findsOneWidget);

    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsNothing);
    expect(find.text('Go'), findsOneWidget);
  });

  testWidgets('goes away when the task fails, and the error still arrives', (
    tester,
  ) async {
    Object? caught;
    await tester.pumpWidget(
      _app(() async => throw StateError('boom'), onError: (e) => caught = e),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(caught, isA<StateError>());
    expect(find.text('Working'), findsNothing);
  });

  testWidgets('a dialog already closed by someone else is left alone', (
    tester,
  ) async {
    final done = Completer<void>();
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('Page'));
          },
        ),
      ),
    );

    final run = runWithProgressDialog<void>(
      context: pageContext,
      title: 'Working',
      message: 'Please wait',
      task: () => done.future,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Working'), findsOneWidget);

    // Like the login page does after the account is deleted: every route above
    // the first one is removed, the dialog included.
    Navigator.of(pageContext, rootNavigator: true).popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsNothing);

    done.complete();
    await run;
    await tester.pumpAndSettle();
    // The page underneath is still there: nothing extra was popped.
    expect(find.text('Page'), findsOneWidget);
  });
}
