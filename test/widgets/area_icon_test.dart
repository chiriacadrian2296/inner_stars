import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/widgets/area_icon.dart';

void main() {
  testWidgets('area vectors load and preserve icon footprints', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final area in LifeArea.values)
                for (final size in [16.0, 24.0, 54.0])
                  AreaIcon(
                    key: ValueKey('${area.name}-$size'),
                    area: area,
                    size: size,
                  ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final area in LifeArea.values) {
      for (final size in [16.0, 24.0, 54.0]) {
        final icon = find.byKey(ValueKey('${area.name}-$size'));
        expect(tester.getSize(icon), Size.square(size));
      }
    }
    expect(tester.takeException(), isNull);
  });
}
