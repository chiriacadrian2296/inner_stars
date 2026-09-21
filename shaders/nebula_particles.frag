#version 460 core

#include <flutter/runtime_effect.glsl>

// highp, not mediump: the hash()/valueNoise() below multiply by large
// constants (43758.5453123 etc.), which needs real precision to work —
// desktop/emulator GPUs often silently treat mediump as highp anyway
// (masking this), but real mobile GPUs (Adreno/Mali) enforce the lower
// precision, degrading the hash badly enough that the whole screen reads
// as flat near-black instead of noise.
precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform vec3 uForward;
uniform vec3 uRight;
uniform vec3 uUp;
uniform float uZoom;
uniform float uShowGrid;

out vec4 fragColor;

// The app's own deep-blue "crisis gradient" tones (AppColors.dark) plus its
// gold accent — this shader is meant to feel like part of Inner Stars,
// not a generic copy of whatever reference wallpaper inspired it.
const vec3 kDeepOuter = vec3(0.0196, 0.0275, 0.0510);  // #05070D
const vec3 kDeepMid = vec3(0.0627, 0.0863, 0.1686);    // #10162B
const vec3 kDeepCenter = vec3(0.1098, 0.1529, 0.2784); // #1C2747
const vec3 kGold = vec3(0.9490, 0.7216, 0.2941);       // #F2B84B

float hash3(vec3 p) {
  // Wrapping the input keeps sin()'s argument bounded — without this,
  // coordinates that grow large (through fbm's octave doubling, or just
  // uTime accumulating over a long session) push sin() into a range where
  // mobile GPUs lose enough precision to band/tile visibly, even at highp
  // (desktop/emulator GPUs mostly don't show this, which is why it wasn't
  // caught until testing on the real phone).
  p = mod(p, 289.0);
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Trilinear value noise over a 3D lattice — sampled from a point already
// projected onto the sky sphere (see main()), never from a flat 2D
// azimuth/elevation pair. That's deliberate: a 2D (azimuth, elevation)
// coordinate has to wrap at the azimuth seam and do something special at
// the poles, and both of those show up as a visible cut in a smooth cloud
// field no matter how carefully the wrap is patched. A 3D point on the
// sphere has neither problem — there's no seam or pole in 3D space to
// begin with, so the noise it produces is seamless everywhere for free.
float valueNoise3(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  vec3 u = f * f * (3.0 - 2.0 * f);

  float c000 = hash3(i + vec3(0.0, 0.0, 0.0));
  float c100 = hash3(i + vec3(1.0, 0.0, 0.0));
  float c010 = hash3(i + vec3(0.0, 1.0, 0.0));
  float c110 = hash3(i + vec3(1.0, 1.0, 0.0));
  float c001 = hash3(i + vec3(0.0, 0.0, 1.0));
  float c101 = hash3(i + vec3(1.0, 0.0, 1.0));
  float c011 = hash3(i + vec3(0.0, 1.0, 1.0));
  float c111 = hash3(i + vec3(1.0, 1.0, 1.0));

  float x00 = mix(c000, c100, u.x);
  float x10 = mix(c010, c110, u.x);
  float x01 = mix(c001, c101, u.x);
  float x11 = mix(c011, c111, u.x);
  float y0 = mix(x00, x10, u.y);
  float y1 = mix(x01, x11, u.y);
  return mix(y0, y1, u.z);
}

// Fractal Brownian motion — a handful of octaves of valueNoise3 stacked at
// shrinking amplitude/growing frequency, which is what turns flat noise
// into the soft, cloud-like drift a nebula needs.
float fbm3(vec3 p) {
  float total = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 5; i++) {
    total += amplitude * valueNoise3(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return total;
}

// One layer of a procedural starfield: a cubic lattice of cells (through
// which the sky sphere passes), each with a pseudo-random chance of
// holding a star at a pseudo-random offset within the cell, glowing and
// twinkling. No texture asset needed — every star is generated purely
// from its cell's hash. Same seamless-for-free reasoning as valueNoise3:
// a 3D lattice has no wrap seam or pole to patch around.
float starLayer(vec3 dir, float density, float twinkleSpeed, float seed) {
  vec3 grid = dir * density;
  vec3 cell = floor(grid);
  vec3 local = fract(grid) - 0.5;

  float h = hash3(cell + seed);
  vec3 starPos =
      (vec3(
        hash3(cell + seed * 2.0),
        hash3(cell + seed * 3.0),
        hash3(cell + seed * 4.0)
      ) - 0.5) * 0.7;
  float dist = length(local - starPos);

  float twinkle = 0.6 + 0.4 * sin(uTime * twinkleSpeed + h * 6.2831853);
  float brightness = step(0.8, h) * twinkle;
  return smoothstep(0.1, 0.0, dist) * brightness;
}

// A second, far sparser kind of background star — same cell-hash
// placement technique as starLayer, but with actual light rays (a tiny
// cross-shaped flare) and a white-hot core instead of a plain twinkling
// gold dot, echoing sky_supernova.frag's own spike/core treatment at a
// much smaller scale so these read as part of the same visual family as
// the 8 area supernovas, not a different kind of graphic. Only ~1.5% of
// cells hold one (step(0.985, h), vs. starLayer's own 20%) — these are
// meant to be rare, eye-catching accents scattered through the base
// field, not another layer of it.
vec3 flareStarLayer(vec3 dir, float density, float seed) {
  vec3 grid = dir * density;
  vec3 cell = floor(grid);
  vec3 local = fract(grid) - 0.5;

  float h = hash3(cell + seed);
  if (h < 0.985) return vec3(0.0);

  // Kept close to this cell's own center (±0.15/axis, was ±0.3) — this
  // function only ever looks at the current cell, never its neighbors, so
  // a star placed too near an edge would have no way to finish rendering
  // its glow/rays once a pixel crosses into the next cell over.
  vec3 starPos = (vec3(
    hash3(cell + seed * 2.0),
    hash3(cell + seed * 3.0),
    hash3(cell + seed * 4.0)
  ) - 0.5) * 0.3;
  vec3 diff = local - starPos;

  // A local 2-axis frame tangent to the sphere at this pixel's own
  // direction, built from the *camera's* own uRight (Gram-Schmidt: the
  // component of uRight perpendicular to dir) rather than a world-up
  // reference that flips to a different vector near the poles
  // (sky_supernova.frag's supernova() does that, but it's anchored to
  // each supernova's own fixed direction, so the flip only ever happens
  // once per supernova, not once per star scattered across the whole
  // sky). Tying every star's axes to the same camera basis instead makes
  // every one of them line up consistently with the screen, rather than
  // each getting its own, essentially arbitrary rotation depending on
  // where it happens to sit — which is what read as some stars' rays
  // looking crooked relative to the others.
  vec3 axisA = normalize(uRight - dir * dot(uRight, dir));
  vec3 axisB = cross(dir, axisA);
  vec2 uv = vec2(dot(diff, axisA), dot(diff, axisB)) * 2.2;
  float dist = length(uv);

  // A per-star flicker — occasional brief brighten, echoing
  // sky_supernova.frag's own flicker on the area supernovas, so these
  // accent stars feel related rather than a separate, unrelated effect.
  float flickerRaw = sin(uTime * 2.3 + h * 41.0) * sin(uTime * 0.9 + h * 17.0);
  float flicker = pow(clamp(flickerRaw, 0.0, 1.0), 3.0);

  float glow = exp(-dist * 9.0) * (0.7 + flicker * 0.8);
  float baseWidth = 0.045;
  float widthX = baseWidth * exp(-abs(uv.x) * 5.0);
  float widthY = baseWidth * exp(-abs(uv.y) * 5.0);
  float horizSpike = smoothstep(widthX, 0.0, abs(uv.y)) * exp(-abs(uv.x) * 5.0);
  float vertSpike = smoothstep(widthY, 0.0, abs(uv.x)) * exp(-abs(uv.y) * 5.0);
  float spikes = (horizSpike + vertSpike) * (0.8 + flicker * 0.6);
  float core = smoothstep(0.1, 0.0, dist) * (1.0 + flicker * 0.5);

  // Belt-and-braces on top of the tighter falloff above: fades this
  // star's whole contribution to zero as the *pixel* approaches the
  // cell's own boundary (0.5), starting at 0.34. Without this, any
  // leftover reach past the cell edge reads as a hard, asymmetric slice
  // through the star and its glow — this way it fades out smoothly and
  // symmetrically well before the seam, whatever the star's own offset.
  float edgeFade = smoothstep(
    0.5,
    0.34,
    max(max(abs(local.x), abs(local.y)), abs(local.z))
  );

  vec3 colorCore = vec3(1.0, 0.98, 0.9);
  return (kGold * (glow + spikes) + colorCore * core * 1.5) * edgeFade;
}

void main() {
  // A free-orientation camera at the center of the sky sphere — uForward/
  // uRight/uUp are its already-orthonormal basis, straight from
  // constellation_field.dart's SkyCamera (see that class's own comment
  // for why it's a full free orientation rather than an azimuth/elevation
  // pair: the latter always has poles, this doesn't). No trig needed here
  // at all — that's computed once on the Dart side, not per pixel.
  // tangent is this pixel's position on the camera's flat tangent plane,
  // in "zoom = focal length in screen-heights" units — dividing by
  // uResolution.y for *both* axes (not width) is what keeps 1 world unit
  // equal to 1 screen height regardless of aspect ratio, matching every
  // other camera calculation in this app.
  vec2 centered = FlutterFragCoord().xy - uResolution * 0.5;
  vec2 tangent = centered / uResolution.y / uZoom;

  vec3 forward = uForward;
  vec3 right = uRight;
  vec3 up = uUp;

  // Inverse stereographic projection — tangent is treated as a
  // stereographic-plane point, not a gnomonic (plain divide-by-depth)
  // one, matching constellation_field.dart's worldToScreen exactly (see
  // its own comment for why gnomonic isn't used: it stretches things into
  // ellipses toward the edge of a wide field of view, an oblong
  // "football" look rather than a sphere; stereographic doesn't). tangent.y
  // is negated first because screen Y grows downward while "up" (and
  // elevation) grow upward — without that the sky would pan backwards
  // vertically relative to how NebulaScreen's gestures move it.
  float tx = tangent.x;
  float ty = -tangent.y;
  float rho2 = tx * tx + ty * ty;
  float denom = 4.0 + rho2;
  vec3 dir = normalize(
    right * (4.0 * tx / denom) +
    up * (4.0 * ty / denom) +
    forward * ((4.0 - rho2) / denom)
  );

  // A bigger sky sphere reads as one with finer, denser detail — more (and
  // smaller) stars, and finer-grained gas structure — the same way a
  // deeper, more distant starfield looks busier than a small one right in
  // front of you. Bumped up again from the previous pass, in step with
  // NebulaScreen's own zoom range moving farther back (see
  // NebulaScreen._maxZoom's comment) — the same visible field of view now
  // covers noticeably more of the sky than before, so it needs more detail
  // packed into it to read as "farther away" rather than just "emptier."
  vec3 timeDrift = vec3(uTime * 0.02, -uTime * 0.015, uTime * 0.008);
  float n = fbm3(dir * 6.0 + timeDrift);
  float n2 = fbm3(dir * 10.0 + timeDrift * 1.7 + 4.0);

  // Mostly the deep blue palette, with gold reserved for the brightest
  // noise peaks only (pow(n2, 4.0) stays low until n2 is high, so it reads
  // as scattered highlights rather than a wash of gold across the screen).
  vec3 nebula = mix(kDeepOuter, kDeepCenter, n);
  nebula = mix(nebula, kGold, pow(n2, 4.0) * 0.65);

  float stars = 0.0;
  stars += starLayer(dir, 15.0, 1.6, 1.0);
  stars += starLayer(dir, 27.0, 2.3, 7.0) * 0.8;
  stars += starLayer(dir, 48.0, 3.1, 13.0) * 0.6;
  stars += starLayer(dir, 75.0, 4.0, 19.0) * 0.4;

  // Only at the two sparser/larger-celled densities — a flare star this
  // small already reads clearly at this scale; the denser layers would
  // just place too many too close together.
  vec3 flareStars = flareStarLayer(dir, 15.0, 31.0) + flareStarLayer(dir, 27.0, 37.0);

  vec3 color = nebula + kGold * stars + flareStars;

  // Debug aid, toggled from NebulaScreen's own switch (uShowGrid) —
  // meridians/parallels every 15°, so panning/zoom can be calibrated by
  // eye (how close to a pole, how much of the sky is visible at once)
  // instead of guessing. Computed from the true (asin/atan2)
  // elevation/azimuth of this pixel's own ray direction, so the lines
  // land at their real position on the sphere regardless of camera
  // orientation.
  if (uShowGrid > 0.5) {
    float trueAzimuthTurns = atan(dir.z, dir.x) / 6.28318530718;
    float trueElevationTurns = asin(clamp(dir.y, -1.0, 1.0)) / 6.28318530718;
    float meridianDist = abs(fract(trueAzimuthTurns * 24.0 + 0.5) - 0.5);
    float parallelDist = abs(
      fract((trueElevationTurns + 0.25) * 12.0 + 0.5) - 0.5
    );
    // The poles should read as a single point where every meridian
    // converges, not another ring — which is what the parallel closest
    // to ±0.25 turns would otherwise draw right on top of. Fading both
    // grid lines out over a small cap there leaves a clean point,
    // meridians included (they naturally taper to a point on their own
    // as they approach it, so fading them too doesn't lose the "lines
    // converge here" cue).
    float poleFade = smoothstep(0.22, 0.25, abs(trueElevationTurns));
    // Two separately-colored layers, echoing a star's own bright
    // core/gold-glow pairing (see sky_supernova.frag's `supernova()`, and
    // the same white-core/gold-glow pairing `ConstellationPainter`'s own
    // stars use) rather than one flat white-tinted band: a thin, largely
    // opaque near-white core — the line itself — plus a softer, wider
    // gold glow around it, tinted with the same [kGold] this shader
    // already reserves for its brightest star peaks.
    //
    // meridianDist/parallelDist aren't on the same scale: meridianDist is
    // measured in units of a 1/24-turn cell, parallelDist in units of a
    // coarser 1/12-turn-equivalent cell (see this block's own
    // azimuth/elevation setup above — parallels use half the divisor
    // meridians do). The same numeric threshold applied to both therefore
    // used to draw parallels at *twice* the real angular width of
    // meridians — halving the parallel core threshold (and doubling its
    // glow falloff rate below) corrects for that scale difference, so
    // both read as the same width.
    const float kMeridianCoreWidth = 0.0009;
    const float kParallelCoreWidth = kMeridianCoreWidth * 0.5;

    // A pixel-width antialiasing edge instead of a fixed one in
    // dist-units — a fixed-in-angle soft edge covers more and more screen
    // pixels the further in you zoom (the same tiny sliver of real angle
    // just spans more of the view), which is exactly what read as a
    // clean line from far away but a blurry, imprecise one zoomed in
    // close. `fwidth()` (the usual GLSL tool for this) isn't supported by
    // Flutter's shader compiler target, so this approximates it
    // analytically instead: near the view's own optical center, one
    // screen pixel spans very close to 1/(uResolution.y * uZoom) radians
    // of real angle — the same relationship the projection's own
    // `tangent` above already relies on — so dividing that by each grid's
    // own real angular spacing (2π/24 for meridians, 2π/12 for the
    // coarser parallels) converts it into the same dist-unit `fwidth()`
    // would have measured directly.
    //
    // This AA width — not kMeridianCoreWidth/kParallelCoreWidth above —
    // is what actually controls how thick the line reads zoomed all the
    // way out: at the minimum zoom, the core's own true angular width
    // rasterizes to a small fraction of one screen pixel (it's a genuinely
    // thin line at that scale), so the AA edge sized below is the only
    // part of the line with enough coverage to render at all, and
    // shrinking the core width further has no visible effect until zoom
    // is high enough for the core to catch up to it. The multiplier here
    // (was 1.5, still enough headroom to avoid the line shimmering in and
    // out as the camera pans, without staying as thick as a full 1.5px at
    // every zoom level) is the one to touch for "thinner at low zoom."
    float pixelAngle = 1.0 / (uResolution.y * uZoom);
    float meridianAA = max(pixelAngle * 24.0 / 6.28318530718 * 0.75, 1e-5);
    float parallelAA = max(pixelAngle * 12.0 / 6.28318530718 * 0.75, 1e-5);

    float meridianCore =
        1.0 - smoothstep(kMeridianCoreWidth, kMeridianCoreWidth + meridianAA, meridianDist);
    float parallelCore =
        1.0 - smoothstep(kParallelCoreWidth, kParallelCoreWidth + parallelAA, parallelDist);
    float core = clamp(meridianCore + parallelCore, 0.0, 1.0) * (1.0 - poleFade);

    float meridianGlow = exp(-meridianDist * 130.0) * 0.75;
    float parallelGlow = exp(-parallelDist * 260.0) * 0.75;
    float glow = clamp(meridianGlow + parallelGlow, 0.0, 1.0) * (1.0 - poleFade);

    // Overall grid opacity, tried at 10% to read as a subtle overlay
    // rather than a bright cage over the sky.
    const float kGridOpacity = 0.3;
    color = mix(color, kGold, glow * 0.65 * kGridOpacity);
    color = mix(color, vec3(1.0, 0.98, 0.92), core * 0.95 * kGridOpacity);
  }

  fragColor = vec4(color, 1.0);
}
