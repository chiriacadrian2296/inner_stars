import 'dart:math' as math;
import 'dart:ui';

/// How a manual drag moves the camera through Galaxy.
enum GalaxyNavigationMode {
  /// The touched point follows the finger exactly, with a Maps-like glide
  /// after release.
  direct,

  /// Deliberately resists the gesture while the finger is down, then lets the
  /// released camera drift through the sky with configurable gravity.
  cinematic;

  double get dragDistanceFactor => switch (this) {
    GalaxyNavigationMode.direct => 1,
    GalaxyNavigationMode.cinematic => 0.3,
  };

  double get inertiaVelocityFactor => switch (this) {
    GalaxyNavigationMode.direct => 1,
    // Match the live drag factor so releasing the finger does not create a
    // visible burst of speed before gravity starts slowing the camera.
    GalaxyNavigationMode.cinematic => 0.3,
  };

  /// Maximum angular launch speed in camera turns per second. This only caps
  /// unusually violent flicks; ordinary swipes keep their full velocity.
  double get maxInertiaTurnsPerSecond => switch (this) {
    // Direct preserves the original unbounded release velocity. The cap is
    // part of Cinematic's deliberately controlled, slower movement only.
    GalaxyNavigationMode.direct => double.infinity,
    GalaxyNavigationMode.cinematic => 0.085,
  };

  /// Caps magnitude without changing the direction of the release gesture.
  Offset limitInertiaVelocity(Offset velocity) {
    if (this == GalaxyNavigationMode.direct) return velocity;
    final speed = velocity.distance;
    final maximum = maxInertiaTurnsPerSecond;
    return speed > maximum ? velocity / speed * maximum : velocity;
  }

  /// Applies one live steering impulse to a moving camera. Repeated impulses
  /// bend the existing vector; an opposite gesture must first cancel its
  /// momentum before it can reverse the direction of travel.
  Offset steerInertiaVelocity({
    required Offset currentVelocity,
    required Offset impulse,
  }) => limitInertiaVelocity(currentVelocity + impulse);

  /// Applies a new release as an impulse on top of the motion Galaxy already
  /// had. The carried velocity keeps decaying under the configured gravity
  /// while the new gesture is held, then both vectors are combined and capped.
  Offset combineInertiaVelocity({
    required Offset releaseVelocity,
    required Offset carriedVelocity,
    required double gestureSeconds,
    required double cinematicGravity,
  }) {
    // Original Direct navigation forgets the previous glide as soon as a new
    // gesture grabs the sky; its release becomes the new velocity verbatim.
    if (this == GalaxyNavigationMode.direct) return releaseVelocity;
    final carriedDecay = math
        .pow(
          velocityDecayPerSecond(cinematicGravity),
          math.max(0, gestureSeconds),
        )
        .toDouble();
    return steerInertiaVelocity(
      currentVelocity: carriedVelocity * carriedDecay,
      impulse: releaseVelocity,
    );
  }

  /// The share of velocity still present one second later. Cinematic gravity
  /// ranges from true zero-gravity (all velocity survives) to a strong but
  /// still fluid brake at 1 G.
  double velocityDecayPerSecond(double cinematicGravity) => switch (this) {
    GalaxyNavigationMode.direct => 0.04,
    GalaxyNavigationMode.cinematic =>
      cinematicGravity <= 0
          ? 1
          : math.pow(0.08, cinematicGravity.clamp(0.0, 1.0)).toDouble(),
  };

  static GalaxyNavigationMode fromName(
    String? name, {
    GalaxyNavigationMode fallback = GalaxyNavigationMode.cinematic,
  }) => GalaxyNavigationMode.values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}
