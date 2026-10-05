#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform vec3 uForward;
uniform vec3 uRight;
uniform vec3 uUp;
uniform float uZoom;
uniform float uSize;
uniform float uIntensity;

out vec4 fragColor;

// Another alternative take on the same slot sky_decorations.frag,
// sky_wisps.frag, and sky_black_hole.frag filled before it (see
// NebulaScreen.build — only one is ever wired in at a time): 8
// simple lens-flare-style "supernovas" — one per LifeArea (see
// lib/models/life_area.dart: the app already has exactly 8, fixed) — each
// a warm glow, a thin ring, a four-point star core, and a tapered
// four-point cross spike, modeled after a plain stock lens-flare graphic
// rather than any photographic nebula/black-hole reference. All 8 share
// the same gold color (an earlier pass gave each its own shade of yellow
// instead) — the 8 are told apart by the area's own icon, drawn at each
// one's center in Dart (see the SkySupernova widget's own painter) since
// a fragment shader has no way to rasterize a font glyph on its own.

// Exactly the number of LifeArea values — see sky_decorations.frag's own
// kSupernovaCount for the fuller reasoning: this set is fixed and closed
// (never grows), so a true Fibonacci sphere lattice — which needs its
// total count up front but gives the most even coverage for a *known*
// N — is the right tool, not an ever-growing placement scheme.
const float kSupernovaCount = 8.0;

// Where the index-th of kSupernovaCount stars sits on the unit sky
// sphere — a Fibonacci sphere lattice; see sky_decorations.frag's
// identical supernovaDirection for the full explanation of why this
// construction (not a plain uniform-random or lat/long grid) is what
// spreads a *known, fixed* point count evenly with no pole clustering.
vec3 supernovaDirection(float index) {
  float goldenAngle = 3.14159265 * (3.0 - sqrt(5.0));
  float y = 1.0 - (index / (kSupernovaCount - 1.0)) * 2.0;
  float radius = sqrt(max(0.0, 1.0 - y * y));
  float theta = goldenAngle * index;
  return vec3(cos(theta) * radius, y, sin(theta) * radius);
}

// One star's full color contribution — [midColor]/[outerColor] are the
// same for all 8 calls in main() below (see that function's own comment
// for why); kept as parameters anyway since a per-star tint was tried
// here before and may be again.
vec3 supernova(vec3 dir, vec3 center, vec3 midColor, vec3 outerColor) {
  vec3 reference = abs(center.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
  vec3 axisA = normalize(cross(reference, center));
  vec3 axisB = cross(center, axisA);
  vec2 uv = vec2(dot(dir - center, axisA), dot(dir - center, axisB));

  // An occasional, irregular flicker — on top of [pulse]'s own steady
  // breathing further down — brightening and slightly growing a star for
  // a moment before fading back. Three sines at frequencies with no
  // common period, multiplied together rather than added, stay near zero
  // almost all the time and only spike when all three happen to crest
  // together — an "every so often" flicker rather than another smooth,
  // fully periodic pulse. [center]'s own components phase-shift each
  // star's own flicker independently, the same trick [pulse] already
  // uses, so the 8 never flicker in lockstep.
  float flickerRaw = sin(uTime * 2.7 + center.x * 11.0) *
      sin(uTime * 1.3 + center.y * 7.0) *
      sin(uTime * 0.41 + center.z * 5.0);
  float flicker = pow(clamp(flickerRaw, 0.0, 1.0), 4.0);

  // Shrinks the whole icon uniformly — dividing the coordinate itself
  // (rather than rescaling every radius/width constant below by hand) is
  // what makes each star read as farther away/smaller, the same way a
  // more distant real star still has the same *shape*, just less of it
  // fills your view. [flicker] nudges that divisor up slightly at its own
  // peak, growing the star a little rather than just brightening it (see
  // [brightness]'s own flicker term further down).
  uv /= 0.45 * uSize * (1.0 + flicker * 0.15);

  // {center, axisA, axisB} is an orthonormal basis, so any unit [dir] is
  // exactly c*center + a*axisA + b*axisB with c² + a² + b² = 1 — and [uv]
  // above is just (a, b). Both hemispheres of the sphere (c > 0, near
  // [center], and c < 0, near its antipode) sweep through the exact same
  // range of (a, b), so without discarding one of them the same star
  // pattern would get drawn twice: once where it belongs, and once,
  // mirrored, on the far side of the sky.
  //
  // [hemisphereFade] ramps down to 0 smoothly *before* the actual
  // hemisphere boundary (c == 0), rather than a hard cutoff exactly at
  // it: the spikes/glow below still have real brightness left at c == 0
  // (their own exp() falloff hasn't fully reached zero by the time [dist]
  // — which is exactly 1.0 right at that boundary, since a² + b² = 1
  // there — gets that large), so clipping at a hard c < 0.0 boundary
  // would slice off a visibly nonzero tail instead of letting it fade out
  // on its own.
  float hemisphereFade = smoothstep(0.0, 0.22, dot(dir, center));
  if (hemisphereFade <= 0.0) return vec3(0.0);

  float dist = length(uv);

  // A slow, gentle breathing pulse — subtle on purpose, since the
  // reference is a clean, mostly-static graphic; anything stronger would
  // fight the composed, iconic look rather than just bring it to life.
  float pulse = 0.94 + 0.06 * sin(uTime * 0.6 + center.x * 3.0);

  // Soft outer glow — a wide, gentle radial falloff — plus a second,
  // much steeper near-center glow layered on top: [glow] alone stays at
  // its previous reach/intensity, [nearGlow] decays so fast it's already
  // negligible by the time [glow] would start mattering, so this only
  // makes the very center noticeably brighter without extending the
  // glow's own reach any farther.
  float glow = exp(-dist * 3.0) * 0.9;
  float nearGlow = exp(-dist * 22.0) * 1.1;

  // A thin ring, pulled in to a smaller diameter than an earlier pass had
  // it.
  float ringRadius = 0.09;
  float ring = smoothstep(0.014, 0.0, abs(dist - ringRadius)) * 0.5;

  // The four-point cross spike — wide at its own base and tapering to a
  // point as it goes, rather than a constant-width bar: [widthX]/[widthY]
  // shrink with distance along the spike's own length via exp(), so the
  // mask narrows continuously instead of just fading in brightness at a
  // fixed width.
  float baseWidth = 0.014;
  float widthX = baseWidth * exp(-abs(uv.x) * 5.0);
  float widthY = baseWidth * exp(-abs(uv.y) * 5.0);
  float horizSpike = smoothstep(widthX, 0.0, abs(uv.y)) * exp(-abs(uv.x) * 6.0);
  float vertSpike = smoothstep(widthY, 0.0, abs(uv.x)) * exp(-abs(uv.y) * 6.0);
  float spikes = horizSpike + vertSpike;

  // A fainter, shorter diagonal cross underneath the main one — the small
  // extra glints a stock lens-flare graphic shows near its core, giving
  // it an 8-point sparkle rather than a plain 4-point one up close. Same
  // tapered-width shape as the main spikes, just smaller/dimmer
  // throughout.
  vec2 diag = vec2(uv.x + uv.y, uv.x - uv.y) * 0.7071;
  float diagBaseWidth = 0.008;
  float diagWidthX = diagBaseWidth * exp(-abs(diag.x) * 9.0);
  float diagWidthY = diagBaseWidth * exp(-abs(diag.y) * 9.0);
  float diagSpikes = (
    smoothstep(diagWidthY, 0.0, abs(diag.y)) * exp(-abs(diag.x) * 10.0) +
    smoothstep(diagWidthX, 0.0, abs(diag.x)) * exp(-abs(diag.y) * 10.0)
  ) * 0.4;

  // The core itself: a four-pointed star/sparkle shape (an astroid — the
  // curve |x|^0.5 + |y|^0.5 = const — not a disc), built straight from
  // |uv.x|/|uv.y| so its own four points automatically point along the
  // same horizontal/vertical axes the main spikes do, with no separate
  // alignment needed.
  float starMetric = sqrt(abs(uv.x)) + sqrt(abs(uv.y));
  float core = smoothstep(0.22, 0.0, starMetric);

  // A second flicker, just for the spikes/rays — distinct from [flicker]
  // above (which brightens/grows the *whole* star, rarely). Only two
  // sines rather than three, and higher frequencies, so it crests far
  // more often — frequent small flickers along the rays rather than the
  // whole star's own occasional, bigger flare-up — and a lower power (3
  // vs. 4) widens each crest a touch, since "more, smaller hits" was the
  // point rather than sharp, rare spikes.
  float spikeFlicker = pow(clamp(
      sin(uTime * 5.3 + center.x * 13.0) * sin(uTime * 3.7 + center.y * 9.0),
      0.0, 1.0), 3.0);

  float brightness = (
      core * 2.2 +
      (spikes * 1.4 + diagSpikes) * (1.0 + spikeFlicker * 0.2) +
      ring + glow + nearGlow
    ) * pulse * (1.0 + flicker * 0.3);

  vec3 colorCore = vec3(1.0, 0.98, 0.9);
  vec3 color = mix(outerColor, midColor, smoothstep(0.0, 0.25, glow + spikes * 0.3));
  color = mix(color, colorCore, clamp(core * 1.5 + nearGlow * 0.3, 0.0, 1.0));

  return color * brightness * hemisphereFade * uIntensity;
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
  // explanation of every step.
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

  // Back to one shared gold for all 8 (an earlier pass spread a narrow
  // hue band across them instead) — they're now told apart by the area
  // icon drawn at each one's center instead (see the SkySupernova widget,
  // which paints those on top of this shader's own output in Dart, since
  // rendering actual icon glyphs isn't something a fragment shader can do
  // on its own).
  vec3 midColor = vec3(1.0, 0.78, 0.4);
  vec3 outerColor = vec3(0.85, 0.5, 0.15);

  vec3 total = vec3(0.0);
  for (int i = 0; i < 8; i++) {
    vec3 center = supernovaDirection(float(i));
    total += supernova(dir, center, midColor, outerColor);
  }

  // Painted with BlendMode.plus (see the SkySupernova widget) — a pure
  // glow with nothing to occlude, unlike sky_black_hole.frag.
  fragColor = vec4(max(total + ditherNoise() * uIntensity / 255.0, 0.0), 1.0);
}
