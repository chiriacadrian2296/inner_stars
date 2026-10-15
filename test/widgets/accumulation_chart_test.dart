import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/utils/celebration_stats.dart';
import 'package:inner_stars/widgets/stats/accumulation_chart.dart';

void main() {
  testWidgets('tap and drag expose actual totals, including flat intervals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AccumulationChart(
              points: [
                CelebrationPoint(DateTime(2026, 10, 1), 0),
                CelebrationPoint(DateTime(2026, 10, 2), 3),
                CelebrationPoint(DateTime(2026, 10, 10), 9),
              ],
              dateLabel: (date) => '${date.day}/${date.month}/${date.year}',
              axisLabel: 'Completed actions',
            ),
          ),
        ),
      ),
    );
    final touch = find.byKey(const ValueKey('accumulation-chart-touch'));
    final selection = find.byKey(
      const ValueKey('accumulation-chart-selection'),
    );
    expect(
      tester.getBottomLeft(selection).dy,
      lessThan(tester.getTopLeft(touch).dy),
    );
    final rect = tester.getRect(touch);
    await tester.tapAt(rect.center);
    await tester.pump();
    final selected = tester.widget<Text>(
      find.byKey(const ValueKey('accumulation-chart-selection')),
    );
    expect(selected.data, endsWith(' · 3'));
    await tester.dragFrom(rect.center, Offset(rect.width / 2, 0));
    await tester.pumpAndSettle();
    expect(find.text('10/10/2026 · 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
