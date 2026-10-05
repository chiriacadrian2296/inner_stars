#version 460 core

#include <flutter/runtime_effect.glsl>

// See nebula_particles.frag's own comment on this: the hash below needs
// real precision to avoid degrading into flat near-black bands on real
// mobile GPUs that enforce mediump.
precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform vec3 uForward;
uniform vec3 uRight;
uniform vec3 uUp;
uniform float uZoom;

out vec4 fragColor;

// A second, purely additive layer painted between NebulaBackground and the
// constellations (see NebulaScreen.build) — 8 nebula clouds evenly spread
// over the sky sphere, one per LifeArea (see lib/models/life_area.dart:
// the app already has exactly 8, fixed, closed set), each with its own
// "supernova" star blazing at its center, plus a sparser field of colored,
// multi-speed-flickering accent stars on top of the base nebula/starfield.
// Kept in its own file/widget/uniform set (deliberately not folded into
// nebula_particles.frag) specifically so it can be dropped from the Stack
// wholesale if it doesn't work out, without touching the proven base
// layer.

// Exactly the number of LifeArea values — one nebula+supernova pair per
// area. Not meant to grow: unlike constellations (which need a new spot
// added every time a project is created, hence constellationWorldPosition's
// additive-recurrence sequence in constellation_field.dart), this set is
// fixed and closed, so a true Fibonacci sphere lattice — which needs its
// total count up front but gives the most even coverage for a *known* N —
// is the better fit here, not a second copy of that recurrence.
const float kSupernovaCount = 8.0;

float hash3(vec3 p) {
  p = mod(p, 289.0);
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

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

float fbm3(vec3 p) {
  float total = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 4; i++) {
    total += amplitude * valueNoise3(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return total;
}

vec3 starPalette(float h) {
  if (h < 0.5) return vec3(0.75, 0.85, 1.0);  // ice blue-white
  if (h < 0.8) return vec3(1.0, 0.85, 0.55);  // warm gold
  return vec3(1.0, 0.55, 0.72);               // rose
}

// Standard HSV->RGB (see e.g. Inigo Quilez's writeups on this exact
// formula) — used to give each of the 8 areas its own hue, evenly spread
// around the color wheel, rather than picking from a small fixed palette
// like starPalette above: with exactly kSupernovaCount of them and no more
// ever added, an even hue spread *is* the natural palette.
vec3 hsv2rgb(vec3 c) {
  vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
  return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// This area's identifying color — shared between its nebula cloud (dimmer,
// less saturated) and its supernova (full brightness) below, so the two
// visibly read as one pair rather than an unrelated cloud plus star.
vec3 areaHue(float index) {
  // +0.07 just rotates the whole wheel off pure 0.0 (red) so index 0 isn't
  // a stock primary — which hue lands on which area is otherwise arbitrary.
  return vec3(fract(index / kSupernovaCount + 0.07), 1.0, 1.0);
}

// Where the index-th of kSupernovaCount areas sits on the unit sky sphere —
// a Fibonacci sphere lattice, the standard construction for spreading a
// *known, fixed* point count evenly over a sphere with no clustering at
// the poles (unlike, say, a plain uniform-random or lat/long grid
// placement). y is "up", matching _directionOn in constellation_field.dart
// and dir's own axes below.
vec3 supernovaDirection(float index) {
  float goldenAngle = 3.14159265 * (3.0 - sqrt(5.0));
  float y = 1.0 - (index / (kSupernovaCount - 1.0)) * 2.0;
  float radius = sqrt(max(0.0, 1.0 - y * y));
  float theta = goldenAngle * index;
  return vec3(cos(theta) * radius, y, sin(theta) * radius);
}

// This area's own cloud, in the tangent plane at [center] (see main()'s
// axisA/axisB — the same stable per-star frame [supernova] below anchors
// its own flare to) — one coherent blob per area, not several arm-shaped
// clumps (an earlier version of this used distinct spiral arm bands,
// which at a glance read as more than one cloud per star — exactly the
// "looks doubled, should be 8" mix-up this was rewritten to avoid).
//
// The cloud color/shape itself is *the same two-fbm3-layer technique*
// nebula_particles.frag's own gold highlights use in its main() (a base
// tone warped by one fbm3 layer, a brighter highlight color picked out of
// a second, higher-frequency one) — same math, just fed this area's own
// hue instead of the fixed deep-blue/gold palette, and fed a slowly
// spiraling coordinate (see [swirled] below) instead of the base layer's
// raw [dir], which is what makes it visibly wind around its own
// supernova like a spiral galaxy rather than just drift in place.
vec3 spiralNebula(vec3 dir, vec3 center, vec3 axisA, vec3 axisB, float index) {
  vec3 offset = dir - center;
  float u = dot(offset, axisA);
  float v = dot(offset, axisB);
  float r = length(vec2(u, v));

  // Outer radius of this cloud, in the same chord-distance units as [r] —
  // Well inside the ~1.13 typical spacing between neighboring
  // supernovaDirection() points (an 8-point Fibonacci sphere) — kept
  // deliberately small (not just "not overlapping") so each cloud reads
  // as one sparse, special point of interest in a mostly-plain sky rather
  // than filling the view with color; a much bigger radius (0.42, tried
  // first) meant several were visible and butting up against each other
  // in a typical view, reading as "too many colored zones" rather than 8
  // distinct landmarks. Bailing out early past it also skips the rest of
  // this function's noise/trig for the vast majority of pixels, which
  // matters since this runs 8x per pixel from main()'s loop.
  float extent = 0.2;
  if (r > extent) return vec3(0.0);

  float rn = r / extent;
  float angle = atan(v, u);

  // Differential rotation, same as a real spiral galaxy: material farther
  // from the center winds around more than material near it, since the
  // swirl offset added to [angle] grows with [rn]. [spin]'s sign/speed is
  // per-star so the 8 don't all turn identically.
  float spin = hash3(vec3(index, 83.0, 12.0)) - 0.5; // -0.5..0.5
  float swirlAngle = angle + rn * 2.5 * 6.2831853 + uTime * spin * 0.06;
  vec2 swirled = vec2(cos(swirlAngle), sin(swirlAngle)) * r;

  // From here down: nebula_particles.frag's own cloud technique, verbatim
  // in structure — see that file's main() for the original.
  vec3 timeDrift = vec3(uTime * 0.02, -uTime * 0.015, uTime * 0.008);
  float n = fbm3(vec3(swirled, rn) * 6.0 + timeDrift);
  float n2 = fbm3(vec3(swirled, rn) * 10.0 + timeDrift * 1.7 + 4.0);

  vec3 dim = hsv2rgb(areaHue(index) * vec3(1.0, 0.7, 0.16));
  vec3 mid = hsv2rgb(areaHue(index) * vec3(1.0, 0.6, 0.32));
  vec3 highlight = hsv2rgb(areaHue(index) * vec3(1.0, 0.55, 1.0));
  vec3 cloudColor = mix(dim, mid, n);
  cloudColor = mix(cloudColor, highlight, pow(n2, 4.0) * 0.65);

  float edgeFade = smoothstep(1.0, 0.5, rn);
  vec3 cloud = cloudColor * edgeFade;

  // A scatter of small twinkling flecks, riding the same [swirled]
  // coordinate so they turn together with the cloud beneath them, mostly
  // landing on its brighter highlight (step(0.5, n2)) rather than
  // scattered evenly across the whole disc.
  vec2 sparkleGrid = swirled * 90.0;
  vec2 sparkleCell = floor(sparkleGrid);
  vec2 sparkleLocal = fract(sparkleGrid) - 0.5;
  float sh = hash3(vec3(sparkleCell + index * 41.0, 3.0));
  vec2 sparklePos = (vec2(
        hash3(vec3(sparkleCell, index * 5.0 + 1.0)),
        hash3(vec3(sparkleCell, index * 9.0 + 2.0))
      ) - 0.5) * 0.7;
  float sd = length(sparkleLocal - sparklePos);
  float sparklePresent = step(0.9, sh) * step(0.5, n2);
  float sparkleTwinkle = 0.5 + 0.5 * sin(uTime * (2.5 + sh * 3.0) + sh * 6.2831853);
  float sparkleGlow = smoothstep(0.16, 0.0, sd);
  vec3 sparkleColor = mix(highlight, vec3(1.0), 0.5);
  vec3 sparkles =
      sparkleColor * sparklePresent * sparkleTwinkle * sparkleGlow * edgeFade * 0.8;

  return cloud + sparkles;
}

// The "very important, big and bright" star at each nebula's own center —
// one supernova per LifeArea, shaped like a lit sphere/dome rather than a
// flat radial glow: d/coreRadius is treated as the sine of the angle from
// dead center, so sqrt(1 - t*t) is exactly the orthographic height of a
// hemisphere — the sphere's own far side is never visible from any camera
// angle this app allows, so there's nothing gained by modeling it. A
// small offset highlight (a cheap stand-in for a specular glint, since
// this is a self-lit object with no external light source to actually
// reflect) is what sells "sphere" over "flat disc" — a radially symmetric
// gradient alone reads as either.
vec3 supernova(vec3 dir, vec3 center, vec3 axisA, vec3 axisB, float index) {
  float d = distance(dir, center);

  vec3 col = hsv2rgb(areaHue(index));

  // A slow overall shimmer plus a faster fine sparkle layered on top, so
  // it reads as a living, blazing thing rather than a static bright dot.
  float shimmer = 0.85 + 0.15 * sin(uTime * 0.35 + index * 2.7);
  float sparkle = 0.9 + 0.1 * sin(uTime * 5.3 + index * 11.0);
  float brightness = shimmer * sparkle;

  float coreRadius = 0.06;
  float t = clamp(d / coreRadius, 0.0, 1.0);
  float height = sqrt(1.0 - t * t);
  float sphere = pow(height, 0.6);

  // [axisA]/[axisB] are main()'s stable per-star tangent frame — the same
  // one [spiralNebula] is drawn in, so the flare below lines up with that
  // disc rather than the pixel-local grid trick coloredStarLayer() uses
  // (fine for tiny twinkling points, but at this size a grid-relative
  // feature would visibly swim as the camera panned).
  vec2 local = vec2(dot(dir - center, axisA), dot(dir - center, axisB));

  vec2 highlightOffset = local - vec2(-0.022, 0.022);
  float highlight = smoothstep(0.02, 0.0, length(highlightOffset)) * 0.5;

  float halo = smoothstep(0.16, 0.0, d) * 0.35;

  // A lens-flare-style spike rather than a plain symmetric plus (see the
  // reference photo): one long, thin, dominant ray crossed by a shorter
  // one, each fading smoothly along its own length via exp() instead of
  // cutting off hard — closer to how a bright point source actually
  // flares on camera. Rotated per star (via the index hash) so the 8
  // don't all flare in the same direction.
  float spikeAngle = hash3(vec3(index, 71.0, 5.0)) * 6.2831853;
  float cosA = cos(spikeAngle);
  float sinA = sin(spikeAngle);
  vec2 rotated = vec2(
    local.x * cosA - local.y * sinA,
    local.x * sinA + local.y * cosA
  );
  float longRay = smoothstep(0.006, 0.0, abs(rotated.x)) * exp(-abs(rotated.y) * 7.0);
  float shortRay = smoothstep(0.008, 0.0, abs(rotated.y)) * exp(-abs(rotated.x) * 14.0);
  float spike = longRay + shortRay * 0.5;

  return col * (sphere * 1.3 + highlight + halo + spike * 0.5) * brightness;
}

// A sparser, colored accent starfield layered over the base one in
// nebula_particles.frag — same lattice-cell placement trick (see that
// file's starLayer() for why a 3D lattice needs no seam/pole handling),
// but with per-star color and a two-frequency flicker so it doesn't read
// as a mechanical single-sine pulse. The brightest ~3.5% of these stars
// also get a four-point diffraction-spike cross.
vec3 coloredStarLayer(vec3 dir, float density, float seed) {
  vec3 grid = dir * density;
  vec3 cell = floor(grid);
  vec3 local = fract(grid) - 0.5;

  float h = hash3(cell + seed);
  vec3 starPos = (vec3(
        hash3(cell + seed * 2.0),
        hash3(cell + seed * 3.0),
        hash3(cell + seed * 4.0)
      ) - 0.5) * 0.7;
  vec3 offset = local - starPos;
  float dist = length(offset);

  float phase = h * 6.2831853;
  float flicker = 0.55 +
      0.3 * sin(uTime * (1.2 + h * 1.8) + phase) +
      0.15 * sin(uTime * (3.1 + h * 2.7) + phase * 1.7);
  float present = step(0.88, h);
  float glow = smoothstep(0.09, 0.0, dist);

  float isBright = step(0.965, h);
  vec2 axisDist = abs(offset.xy);
  float spike = isBright *
      (smoothstep(0.025, 0.0, axisDist.x) + smoothstep(0.025, 0.0, axisDist.y)) *
      smoothstep(0.35, 0.0, dist);

  float brightness = present * clamp(flicker, 0.0, 1.0) * (glow + spike * 0.6);
  return starPalette(h) * brightness;
}

// Interleaved-gradient-noise dither, ±½ of one 8-bit step. These glows fade
// over hundreds of pixels at high zoom, so without it the 8-bit output
// quantizes into visible bands/grain instead of a smooth gradient.
float ditherNoise() {
  return fract(52.9829189 * fract(dot(FlutterFragCoord().xy, vec2(0.06711056, 0.00583715)))) - 0.5;
}

void main() {
  // Same free-orientation inverse-stereographic projection as
  // nebula_particles.frag — see that file's main() for the full
  // explanation of every step; kept identical here so this layer's
  // features line up exactly with the base sky underneath it.
  vec2 centered = FlutterFragCoord().xy - uResolution * 0.5;
  vec2 tangent = centered / uResolution.y / uZoom;

  float tx = tangent.x;
  float ty = -tangent.y;
  float rho2 = tx * tx + ty * ty;
  float denom = 4.0 + rho2;
  vec3 dir = normalize(
    uRight * (4.0 * tx / denom) +
    uUp * (4.0 * ty / denom) +
    uForward * ((4.0 - rho2) / denom)
  );

  vec3 total = vec3(0.0);
  for (int i = 0; i < 8; i++) {
    float index = float(i);
    vec3 center = supernovaDirection(index);

    // One stable tangent frame per star, shared by both the spiral disc
    // and the supernova's own flare below, so the two are drawn in
    // lockstep rather than each inventing its own orientation.
    // {center, axisA, axisB} is an orthonormal basis, so both hemispheres
    // of the sphere sweep through the exact same (axisA, axisB) range —
    // without this check, spiralNebula/supernova's own local (u, v)
    // coordinates (built from center/axisA/axisB the same way) can't tell
    // "near center" from "near center's antipode", and draw the same
    // pattern mirrored on the far side of the sky too. This is what
    // caused an earlier "the 8 supernovas look doubled" bug, misdiagnosed
    // at the time as the spiral-arm shape itself reading as more than one
    // cloud — the real cause was this hemisphere ambiguity all along.
    if (dot(dir, center) < 0.0) continue;

    vec3 reference = abs(center.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 axisA = normalize(cross(reference, center));
    vec3 axisB = cross(center, axisA);

    total += spiralNebula(dir, center, axisA, axisB, index);
    total += supernova(dir, center, axisA, axisB, index);
  }

  total += coloredStarLayer(dir, 21.0, 31.0);
  total += coloredStarLayer(dir, 36.0, 47.0) * 0.85;
  total += coloredStarLayer(dir, 58.0, 61.0) * 0.7;

  // Painted with BlendMode.plus (see SkyDecorations widget) — an additive
  // blend, so alpha here isn't coverage, it's just always fully "on"; a
  // pixel with total == 0 already adds nothing on its own.
  fragColor = vec4(max(total + ditherNoise() / 255.0, 0.0), 1.0);
}
