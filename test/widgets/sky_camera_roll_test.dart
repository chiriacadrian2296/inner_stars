import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/constellation_field.dart';

void main() {
  group('SkyCamera roll', () {
    test('rolling by -cameraRollAngle zeroes the roll at the same direction', () {
      final camera = SkyCamera.lookingAt(
        azimuthTurns: 0.13,
        elevationTurns: 0.07,
      ).rolled(0.9);
      expect(cameraRollAngle(camera), isNot(closeTo(0, 1e-6)));

      final corrected = camera.rolled(-cameraRollAngle(camera));
      expect(cameraRollAngle(corrected), closeTo(0, 1e-6));
    });

    // Regression test for a real bug caught before it shipped: the sky
    // screen's "straighten the roll while flying to a constellation"
    // feature first computed its correction from the *starting* camera's
    // own roll, on the assumption that `rotatedToAlign` preserves the
    // roll reading unchanged across the sweep — it doesn't. The sphere's
    // curvature (holonomy) means the *reading* `cameraRollAngle` gives
    // at a different direction differs from the reading at the start,
    // even though the transport itself adds no gratuitous twist of its
    // own. Correcting against the start camera landed at the wrong angle
    // entirely; only the destination's own roll reading gives the
    // correction that actually zeroes it out there.
    test('rotatedToAlign does not preserve the roll reading at a new direction', () {
      final camera = SkyCamera.lookingAt(
        azimuthTurns: 0.13,
        elevationTurns: 0.07,
      ).rolled(0.9);
      final target = SkyCamera.lookingAt(
        azimuthTurns: 0.5,
        elevationTurns: -0.2,
      );
      final swept = camera.rotatedToAlign(camera.forward, target.forward);

      expect(
        cameraRollAngle(swept),
        isNot(closeTo(cameraRollAngle(camera), 1e-3)),
      );
    });

    test('correcting against the destination camera zeroes the roll there', () {
      final camera = SkyCamera.lookingAt(
        azimuthTurns: 0.13,
        elevationTurns: 0.07,
      ).rolled(0.9);
      final target = SkyCamera.lookingAt(
        azimuthTurns: 0.5,
        elevationTurns: -0.2,
      );
      final swept = camera.rotatedToAlign(camera.forward, target.forward);
      final corrected = swept.rolled(-cameraRollAngle(swept));

      expect(cameraRollAngle(corrected), closeTo(0, 1e-6));
    });
  });
}
