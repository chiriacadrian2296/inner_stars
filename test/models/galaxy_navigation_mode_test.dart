import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/models/galaxy_navigation_mode.dart';

void main() {
  test('cinematic navigation keeps drag and release speed continuous', () {
    expect(
      GalaxyNavigationMode.cinematic.dragDistanceFactor,
      lessThan(GalaxyNavigationMode.direct.dragDistanceFactor),
    );
    expect(
      GalaxyNavigationMode.cinematic.inertiaVelocityFactor,
      GalaxyNavigationMode.cinematic.dragDistanceFactor,
    );
    expect(GalaxyNavigationMode.cinematic.inertiaVelocityFactor, 0.3);
  });

  test('cinematic gravity ranges from endless drift to a strong brake', () {
    final mode = GalaxyNavigationMode.cinematic;

    expect(mode.velocityDecayPerSecond(0), 1);
    expect(
      mode.velocityDecayPerSecond(0.25),
      greaterThan(mode.velocityDecayPerSecond(1)),
    );
    expect(mode.velocityDecayPerSecond(1), closeTo(0.08, 0.000001));
    expect(GalaxyNavigationMode.direct.velocityDecayPerSecond(0), 0.04);
  });

  test('extreme release velocity is capped without changing direction', () {
    final mode = GalaxyNavigationMode.cinematic;
    const extreme = Offset(3, 4);

    final limited = mode.limitInertiaVelocity(extreme);

    expect(limited.distance, closeTo(mode.maxInertiaTurnsPerSecond, 0.000001));
    expect(limited.dx / limited.dy, closeTo(extreme.dx / extreme.dy, 0.000001));
    expect(
      mode.limitInertiaVelocity(const Offset(0.01, 0.02)),
      const Offset(0.01, 0.02),
    );
    expect(
      GalaxyNavigationMode.cinematic.maxInertiaTurnsPerSecond,
      lessThan(GalaxyNavigationMode.direct.maxInertiaTurnsPerSecond),
    );
    expect(GalaxyNavigationMode.cinematic.maxInertiaTurnsPerSecond, 0.085);
  });

  test('direct preserves its original unbounded release velocity', () {
    final mode = GalaxyNavigationMode.direct;
    const release = Offset(3, 4);

    expect(mode.limitInertiaVelocity(release), release);
    expect(mode.maxInertiaTurnsPerSecond, double.infinity);
  });

  test('direct release replaces rather than inherits an existing glide', () {
    final velocity = GalaxyNavigationMode.direct.combineInertiaVelocity(
      releaseVelocity: const Offset(-0.03, 0.02),
      carriedVelocity: const Offset(0.08, 0.07),
      gestureSeconds: 0,
      cinematicGravity: 0,
    );

    expect(velocity, const Offset(-0.03, 0.02));
  });

  test('a new gesture steers instead of replacing existing momentum', () {
    final mode = GalaxyNavigationMode.cinematic;

    final curved = mode.combineInertiaVelocity(
      releaseVelocity: const Offset(0, 0.02),
      carriedVelocity: const Offset(0.03, 0),
      gestureSeconds: 0,
      cinematicGravity: 0,
    );
    final cancelled = mode.combineInertiaVelocity(
      releaseVelocity: const Offset(-0.02, 0),
      carriedVelocity: const Offset(0.03, 0),
      gestureSeconds: 0,
      cinematicGravity: 0,
    );

    expect(curved.dx, closeTo(0.03, 0.000001));
    expect(curved.dy, closeTo(0.02, 0.000001));
    expect(cancelled.dx, closeTo(0.01, 0.000001));
    expect(cancelled.dy, 0);
  });

  test('live steering must cancel old momentum before reversing it', () {
    final mode = GalaxyNavigationMode.cinematic;

    final fromRest = mode.steerInertiaVelocity(
      currentVelocity: Offset.zero,
      impulse: const Offset(0.02, 0),
    );
    final slowed = mode.steerInertiaVelocity(
      currentVelocity: const Offset(0.06, 0),
      impulse: const Offset(-0.02, 0),
    );
    final curved = mode.steerInertiaVelocity(
      currentVelocity: const Offset(0.06, 0),
      impulse: const Offset(0, 0.02),
    );

    expect(fromRest.dx, closeTo(0.02, 0.000001));
    expect(fromRest.dy, 0);
    expect(slowed.dx, closeTo(0.04, 0.000001));
    expect(slowed.dx, isPositive);
    expect(curved.dx, closeTo(0.06, 0.000001));
    expect(curved.dy, closeTo(0.02, 0.000001));
  });

  test('carried momentum keeps decaying while the new gesture is held', () {
    final mode = GalaxyNavigationMode.cinematic;

    final combined = mode.combineInertiaVelocity(
      releaseVelocity: Offset.zero,
      carriedVelocity: const Offset(0.04, 0),
      gestureSeconds: 1,
      cinematicGravity: 1,
    );

    expect(combined.dx, closeTo(0.04 * 0.08, 0.000001));
    expect(combined.dy, 0);
  });
}
