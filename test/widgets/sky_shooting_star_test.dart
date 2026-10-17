import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/widgets/sky_shooting_star.dart';

void main() {
  test('shooting-star head advances along its world path', () {
    const anchor = Offset(0.25, -0.1);
    final start = shootingStarWorldPosition(anchor, 0);
    final later = shootingStarWorldPosition(anchor, 10);

    expect(later, isNot(start));
    expect(later.dx.isFinite, isTrue);
    expect(later.dy.isFinite, isTrue);
  });
}
