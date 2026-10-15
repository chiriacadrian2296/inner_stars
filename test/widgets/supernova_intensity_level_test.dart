import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/sky_supernova.dart';

void main() {
  test('the intensity level grows with every milestone and in between', () {
    expect(supernovaIntensityLevel(0), 0);
    expect(supernovaIntensityLevel(5), closeTo(0.5, 1e-9));
    expect(supernovaIntensityLevel(10), 1);
    expect(supernovaIntensityLevel(25), 2);
    expect(supernovaIntensityLevel(75), closeTo(3.5, 1e-9));
    expect(supernovaIntensityLevel(800), 7);
    expect(supernovaIntensityLevel(5000), 7);
    // Never shrinks as intensity grows.
    var previous = 0.0;
    for (var total = 0; total <= 900; total++) {
      final level = supernovaIntensityLevel(total);
      expect(level, greaterThanOrEqualTo(previous));
      previous = level;
    }
  });
}
