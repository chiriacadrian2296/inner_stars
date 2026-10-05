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

// An alternative take on the same slot/job sky_decorations.frag fills
// (see NebulaScreen.build — only one of the two is ever wired in at a
// time) — wispy, filamentary nebula clouds with bright glowing ridgelines
// threading through a softer body, plus a scatter of colored sparkle
// stars, modeled after a reference photo of a real Hubble-style
// violet/magenta/blue nebula rather than the spiral-galaxy look
// sky_decorations.frag went for. Deliberately not tied to the 8 life
// areas yet (no fixed placement, no per-area color/identity) — this pass
// is purely about nailing the cloud/star *visual style* first; scattered
// everywhere across the sky as loose patches, the same way this file's
// own coverage mask decides, rather than anchored to fixed points.

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

// Folds plain value noise around its midpoint so it peaks at *both* the
// noise's lowest and highest points instead of just its highest — squared
// afterward to pinch those peaks into thin bright lines. This (plus the
// weight feedback in ridgedFbm3 below) is the standard "ridged
// multifractal" trick: it's what actually produces glowing, thread-like
// filaments rather than the round, soft blobs plain fbm3 gives — exactly
// the ropey/veined look the reference nebula's bright edges have that a
// blob-shaped cloud can't reproduce no matter how it's colored.
float ridgedNoise3(vec3 p) {
  float n = valueNoise3(p);
  float ridge = 1.0 - abs(n * 2.0 - 1.0);
  return ridge * ridge;
}

float ridgedFbm3(vec3 p) {
  float total = 0.0;
  float amplitude = 0.55;
  // Each octave's own brightness feeds forward as the *next* octave's
  // weight — a bright ridge stays bright as finer detail is added on top
  // of it, a dark gap stays suppressed — which is what makes the result
  // read as continuous branching filaments instead of independent noise
  // layers that happen to be stacked. 5 octaves (not 4) so the finest
  // layer is thin enough to read as delicate sub-filament branching
  // rather than stopping one octave short of it.
  float weight = 1.0;
  for (int i = 0; i < 5; i++) {
    float n = ridgedNoise3(p) * weight;
    total += n * amplitude;
    weight = clamp(n * 1.8, 0.0, 1.0);
    p *= 2.05;
    amplitude *= 0.5;
  }
  return clamp(total, 0.0, 1.0);
}

vec3 wispStarColor(float h) {
  if (h < 0.38) return vec3(1.0, 1.0, 1.0);         // white
  if (h < 0.6) return vec3(1.0, 0.76, 0.46);        // warm gold/orange
  if (h < 0.82) return vec3(1.0, 0.52, 0.8);        // magenta/pink
  return vec3(0.58, 0.7, 1.0);                      // blue
}

// A scatter of small twinkling points, most plain glows, a minority (the
// larger-drawn ones, via [sizeFactor]) with a four-point diffraction
// spike — matching the reference photo's mix of plain background dust and
// a few standout colored star icons.
vec3 wispStars(vec3 dir, float density, float seed) {
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

  float present = step(0.8, h);
  float sizeFactor = hash3(cell + seed * 5.0);
  float twinkle = 0.6 + 0.4 * sin(uTime * (1.0 + h * 2.0) + h * 6.2831853);

  float glowRadius = mix(0.045, 0.1, sizeFactor * sizeFactor);
  float glow = smoothstep(glowRadius, 0.0, dist);

  float isSpiky = step(0.7, sizeFactor);
  vec2 axisDist = abs(offset.xy);
  float spikeLen = mix(0.09, 0.24, sizeFactor);
  float spike = isSpiky * (
    smoothstep(0.006, 0.0, axisDist.x) * smoothstep(spikeLen, 0.0, axisDist.y) +
    smoothstep(0.006, 0.0, axisDist.y) * smoothstep(spikeLen, 0.0, axisDist.x)
  );

  return wispStarColor(h) * present * twinkle * (glow + spike * 0.8);
}

// A rare tier of large, prominent stars with long, crisp diffraction
// spikes — the handful of standout star icons the reference photo has
// that [wispStars] (tuned for a dense field of small background points)
// never gets big enough to reproduce. A faint diagonal cross layered on
// top of the main one gives the brightest of these an 8-point sparkle
// rather than a plain 4-point one, matching the reference's own biggest
// stars.
vec3 heroStars(vec3 dir, float density, float seed) {
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

  // Rare — most cells hold nothing at this tier, unlike wispStars' dense
  // background field.
  float present = step(0.93, h);
  float sizeFactor = hash3(cell + seed * 5.0);
  float twinkle = 0.75 + 0.25 * sin(uTime * (0.5 + h * 1.0) + h * 6.2831853);

  float core = smoothstep(mix(0.03, 0.05, sizeFactor), 0.0, dist);
  float glow = smoothstep(mix(0.1, 0.18, sizeFactor), 0.0, dist) * 0.45;

  vec2 axisDist = abs(offset.xy);
  float spikeLen = mix(0.3, 0.6, sizeFactor);
  float spike =
      smoothstep(0.008, 0.0, axisDist.x) * smoothstep(spikeLen, 0.0, axisDist.y) +
      smoothstep(0.008, 0.0, axisDist.y) * smoothstep(spikeLen, 0.0, axisDist.x);

  vec2 diag = vec2(offset.x + offset.y, offset.x - offset.y) * 0.7071;
  vec2 diagDist = abs(diag);
  float diagLen = spikeLen * 0.45;
  float diagSpike = (
    smoothstep(0.006, 0.0, diagDist.x) * smoothstep(diagLen, 0.0, diagDist.y) +
    smoothstep(0.006, 0.0, diagDist.y) * smoothstep(diagLen, 0.0, diagDist.x)
  ) * 0.5;

  return wispStarColor(h) * present * twinkle *
      (core * 1.6 + glow + spike * 1.1 + diagSpike);
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

  // Which patches of sky have any nebula at all — the single biggest miss
  // in the previous pass was *scale*: at a typical zoom this noise's
  // period was so much wider than the visible field of view that any one
  // view sat entirely inside (or entirely outside) one patch, with no
  // boundary in frame at all — reading as "one giant blob fills the
  // screen" instead of "a delicate patch surrounded by plain starfield".
  // A frequency around 3 keeps several patch boundaries visible within a
  // normal view at any zoom level this app allows.
  float shapeNoise = fbm3(dir * 1.1 + vec3(3.0, -2.0, 1.0) + uTime * 0.003);
  float shape = smoothstep(0.44, 0.62, shapeNoise);

  vec3 cloud = vec3(0.0);
  if (shape > 0.002) {
    // A single, modest warp — enough to bend the noise lattice into
    // organic curls, not so much that the underlying structure folds
    // over on itself into a smeared/melted look (a much stronger,
    // two-pass warp was tried first and produced exactly that).
    vec3 warp = vec3(
      valueNoise3(dir * 5.0 + vec3(0.0, 0.0, uTime * 0.01)),
      valueNoise3(dir * 5.0 + vec3(5.2, 1.3, uTime * 0.012)),
      valueNoise3(dir * 5.0 + vec3(9.1, 7.7, uTime * 0.008))
    ) - 0.5;
    vec3 drift = vec3(uTime * 0.008, -uTime * 0.006, uTime * 0.005);
    vec3 p = dir * 9.0 + warp * 0.35 + drift;

    // The soft billowy body — pow() after fbm3 keeps its own low valleys
    // genuinely dark instead of every pixel inside [shape] reading as an
    // even wash of mid-brightness fog; real dark gaps *inside* a nebula's
    // silhouette (not just around it) are a big part of what reads as
    // "gas" rather than "flat tinted cloud".
    float bodyRaw = fbm3(p * 0.3);
    float body = pow(bodyRaw, 1.6);

    // A cheap finite-difference gradient of [bodyRaw] (not a screen-space
    // derivative — one extra fbm3 sample offset slightly in the same
    // noise space) — [edge] is large exactly where the body's density
    // changes fastest. Gating the bright veins below by this, rather than
    // letting them show wherever the fine ridge noise itself happens to
    // peak, is what turns "ridges packed edge-to-edge everywhere" (an
    // earlier pass — it read as a uniform cracked/cellular texture, not a
    // nebula) into filaments that trace the *contours* of the soft body
    // shape instead, the way a real nebula's brightest threads sit along
    // its own density transitions (ionization fronts) rather than being
    // sprinkled uniformly through open gas.
    float bodyShift = fbm3((p + vec3(0.15, 0.1, 0.06)) * 0.3);
    float edge = smoothstep(0.05, 0.35, abs(bodyRaw - bodyShift) * 9.0);

    // Fine filament veins, sampled at roughly 5x [body]'s own frequency —
    // that gap is what actually reads as "delicate lace over soft
    // billows" instead of one texture at a single scale. pow() at a high
    // exponent (not a smoothstep band) is what keeps the brightest
    // result — [hot] — to genuinely thin threads: a smoothstep band over
    // this same signal (tried first) stayed "on" across too wide a value
    // range and rendered as broad white plateaus, not veins.
    float veins = ridgedFbm3(p * 2.5);
    float hot = pow(veins, 6.0) * edge;
    float magentaAmount = smoothstep(0.16, 0.5, veins) * edge;

    vec3 colorDeepBlue = vec3(0.08, 0.14, 0.42);
    vec3 colorViolet = vec3(0.3, 0.16, 0.58);
    vec3 colorMagenta = vec3(0.85, 0.26, 0.62);
    vec3 colorHot = vec3(1.0, 0.95, 0.98);

    // Blue-violet halo first, filling most of [shape]'s own footprint —
    // this is what was missing in the previous pass (nothing but black,
    // then straight to magenta/white, with no surrounding glow at all).
    vec3 col = mix(vec3(0.0), colorDeepBlue, smoothstep(0.0, 0.3, body) * shape);
    col = mix(col, colorViolet, smoothstep(0.22, 0.65, body) * shape);
    col = mix(col, colorMagenta, magentaAmount * shape);
    col = mix(col, colorHot, clamp(hot * 3.0, 0.0, 1.0));

    cloud = col * shape;
  }

  vec3 stars = vec3(0.0);
  stars += wispStars(dir, 26.0, 5.0);
  stars += wispStars(dir, 42.0, 19.0) * 0.85;
  stars += wispStars(dir, 68.0, 37.0) * 0.65;
  stars += heroStars(dir, 7.0, 71.0);
  stars += heroStars(dir, 11.0, 83.0) * 0.85;

  // Painted with BlendMode.plus (see the SkyWisps widget) — additive, so
  // alpha here isn't coverage, it's just always fully "on"; a pixel with
  // cloud+stars == 0 already adds nothing on its own.
  fragColor = vec4(max(cloud + stars + ditherNoise() / 255.0, 0.0), 1.0);
}
