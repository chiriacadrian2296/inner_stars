import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/widgets/area_icon.dart';

void main() {
  testWidgets('area artwork preserves icon footprints and uses small assets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final area in LifeArea.values)
                for (final size in [16.0, 20.0, 54.0])
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
      for (final size in [16.0, 20.0, 54.0]) {
        final icon = find.byKey(ValueKey('${area.name}-$size'));
        expect(tester.getSize(icon), Size.square(size));
      }
      await tester.runAsync(() async {
        for (final scale in [1, 2, 3]) {
          final variant = scale == 1 ? '' : '$scale.0x/';
          final data = await rootBundle.load(
            'assets/images/area_icons/$variant${area.name}.png',
          );
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 64 * scale);
          expect(frame.image.height, 64 * scale);
          final pixels = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(pixels!.getUint8(3), 0, reason: 'transparent canvas corner');
          frame.image.dispose();
          codec.dispose();
        }
      });
    }
    expect(tester.takeException(), isNull);
  });
}
