// The Galaxy's sky, shared by nebula_particles.frag (the Quality mode) and
// nebula_particles_lite.frag (the lighter modes): STAR_CACHE, set by each,
// says whether the background stars can come from cached snapshots too
// (see uStarDepth). Two compiled shaders rather than one with a runtime
// switch: the branches that switch needs made the full sky measurably
// slower to draw, even with the switch off.

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
  // The one knob for "how many stars": the share of cells holding one.
  // 0.24 since the stars got their crisp cores (at 0.38, once they could
  // all be seen, there were far too many).
  const float kStarFill = 0.24;
  // Most cells hold no star: stop before any of the work below (the same
  // result as before, just not computed for nothing).
  if (h < 1.0 - kStarFill) return 0.0;
  vec3 starPos =
      (vec3(
        hash3(cell + seed * 2.0),
        hash3(cell + seed * 3.0),
        hash3(cell + seed * 4.0)
      ) - 0.5) * 0.7;
  float dist = length(local - starPos);

  // A crisp, solid, brighter core — about a pixel at least, with a
  // one-pixel edge so it stays sharp at any zoom — inside the soft glow.
  float pixelInCell = density / (uResolution.y * uZoom);
  float coreRadius = clamp(pixelInCell * 0.8, 0.02, 0.09);
  // Beyond the glow and the core's edge this star adds nothing.
  if (dist > max(0.1, coreRadius + pixelInCell * 0.5)) return 0.0;

  float twinkle = 0.6 + 0.4 * sin(uTime * twinkleSpeed + h * 6.2831853);
  float brightness = twinkle;
  float core = 1.0 -
      smoothstep(
        coreRadius - pixelInCell * 0.5,
        coreRadius + pixelInCell * 0.5,
        dist
      );
  float glow = smoothstep(0.1, 0.0, dist) * 0.55;
  return (glow + core * 1.3) * brightness;
}

// PARKED (2026-10-14): no longer drawn. Its gold rays made it read as one
// of the user's own (tappable) stars; see the scenery rule of thumb below.
//
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

// ---------------------------------------------------------------------------
// Galaxy's rule of thumb: gold and cross-shaped rays mean "this is yours,
// tap it". Everything below is pure scenery, so it never uses either —
// cool whites and blues, soft shapes, nothing that looks like a star of
// the user's. (flareStarLayer above did both, and read as a real star; it
// is parked, no longer drawn.)
// ---------------------------------------------------------------------------

// [starLayer]'s tiny twinkling points, in the colors real stars have rather
// than the app's gold — mostly cool white and pale blue, a rare soft warm
// one — and, for depth, in very different brightnesses: most of them faint
// (far away), a few bright (closer).
vec3 dustStarLayer(vec3 dir, float density, float twinkleSpeed, float seed) {
  float s = starLayer(dir, density, twinkleSpeed, seed);
  if (s <= 0.0) return vec3(0.0);
  vec3 cell = floor(dir * density);
  float tone = hash3(cell + seed * 5.0);
  vec3 color = tone < 0.55
      ? vec3(0.86, 0.9, 1.0)
      : tone < 0.92
      ? vec3(0.66, 0.76, 1.0)
      : vec3(1.0, 0.86, 0.74);
  float magnitude = 0.32 + 1.4 * pow(hash3(cell + seed * 6.0), 4.0);
  return color * s * 0.85 * magnitude;
}

// The nearest scenery stars: very sparse, bigger and softer, with a small
// halo — no rays, no gold (those are the user's). Drawn in front of the
// dark nebulae, and on the "near" layer of the zoom parallax.
vec3 nearStarLayer(
  vec3 dir,
  float density,
  float seed,
  float threshold,
  float size
) {
  vec3 grid = dir * density;
  vec3 cell = floor(grid);
  vec3 local = fract(grid) - 0.5;
  float h = hash3(cell + seed);
  if (h < threshold) return vec3(0.0);
  vec3 pos = (vec3(
    hash3(cell + seed * 2.0),
    hash3(cell + seed * 3.0),
    hash3(cell + seed * 4.0)
  ) - 0.5) * 0.3;
  // In real angle (radians), so a sparser layer doesn't mean bigger stars.
  float d = length(local - pos) / density;
  // Past its faint halo this star adds nothing visible: skip the rest.
  float pixelAngle = 1.0 / (uResolution.y * uZoom);
  float coreRadius = max(0.00045 * size, pixelAngle * 0.8);
  if (d > max(0.012 * size, coreRadius + pixelAngle)) return vec3(0.0);
  float twinkle = 0.8 + 0.2 * sin(uTime * (0.9 + h * 2.0) + h * 30.0);
  // A crisp solid core (at least about a pixel, one-pixel edge) in a soft
  // glow and a faint halo.
  float core =
      1.0 - smoothstep(coreRadius - pixelAngle * 0.5, coreRadius + pixelAngle * 0.5, d);
  float star = (core * 1.3 + smoothstep(0.0011 * size, 0.0, d) * 0.6 +
      exp(-d / (0.0016 * size)) * 0.3) * twinkle;
  vec3 color = hash3(cell + seed * 5.0) < 0.6
      ? vec3(0.9, 0.94, 1.0)
      : vec3(0.7, 0.8, 1.0);
  return color * star;
}

// A cheaper three-octave [fbm3], for the broad shapes below.
float fbm3lo(vec3 p) {
  return 0.5 * valueNoise3(p) +
      0.25 * valueNoise3(p * 2.0) +
      0.125 * valueNoise3(p * 4.0);
}

// Dark nebulae: clouds of dust out in the sky, at the same depth as the
// glowing gas — broad veils and small round globules — that dim the glow
// and the farther stars behind them. Soft-edged and see-through, with
// their own inner structure, so they read as gas in the sky rather than
// shapes laid over the screen. Returns (darkness 0..1, rim 0..1): the rim
// is a thin band just outside a veil's edge, where the gas behind seems to
// catch a little more light.
vec2 darkNebula(vec3 p) {
  float veilNoise = fbm3lo(p * 2.2 + 31.0);
  float veils = smoothstep(0.52, 0.74, veilNoise);
  float rim = clamp(smoothstep(0.44, 0.6, veilNoise) - veils, 0.0, 1.0);
  // Thicker and thinner patches inside each veil.
  veils *= 0.55 + 0.45 * valueNoise3(p * 9.0 + 13.0);

  vec3 g = p * 7.0;
  vec3 cell = floor(g);
  vec3 local = fract(g) - 0.5;
  float gh = hash3(cell + 71.0);
  float globule = 0.0;
  if (gh > 0.94) {
    vec3 gpos = (vec3(
      hash3(cell + 72.0),
      hash3(cell + 73.0),
      hash3(cell + 74.0)
    ) - 0.5) * 0.3;
    float radius = mix(0.08, 0.17, hash3(cell + 75.0));
    float gd = length(local - gpos) / radius;
    globule = smoothstep(1.0, 0.3, gd) * 0.85;
  }

  float darkness = clamp(max(veils, globule), 0.0, 1.0) * 0.75;
  return vec2(darkness, rim);
}

// The supernovas' light reaching this point of the sky: a wide glow and a
// softer tighter one around each, fading with distance — and the more an
// area has been lit (its intensity level, 0..7, see the SkySupernova
// widget), the wider, stronger and warmer its supernova's light: your
// effort lights your sky.
uniform float uSupernovaLight;
uniform vec3 uSupernovas[8];
uniform vec4 uSupernovaLevels0;
uniform vec4 uSupernovaLevels1;

// How this pass is drawn (see NebulaBackground): 0 live — everything,
// computed fresh (while the camera moves); 1 a snapshot of the clouds (the
// gas, its supernova light and the dust, already dithered); 3 a snapshot of
// the dust's darkness alone; 2 the stars and everything else computed fresh
// over the two latest cloud snapshots ([uCloudsA] → [uCloudsB], crossfaded
// by [uBlend]) and the darkness one — the camera standing still, where the
// slowly drifting clouds don't need recomputing every frame; 4 a snapshot
// of the stars [uStarDepth] says to cache (in the lighter quality modes),
// which mode 2 then crossfades from [uStarsA] → [uStarsB] the same way:
// their twinkle is slow enough to follow at the snapshots' pace.
uniform float uMode;
uniform float uBlend;
#if STAR_CACHE
// Which stars come from the snapshots: 0 none, 1 the ones behind and in
// the dust (and the galaxies), 2 all of them. Comets are always live.
uniform float uStarDepth;
#endif
uniform sampler2D uCloudsA;
uniform sampler2D uCloudsB;
uniform sampler2D uDarkness;
#if STAR_CACHE
uniform sampler2D uStarsA;
uniform sampler2D uStarsB;
#endif
float supernovaLevel(int index) {
  if (index == 0) return uSupernovaLevels0.x;
  if (index == 1) return uSupernovaLevels0.y;
  if (index == 2) return uSupernovaLevels0.z;
  if (index == 3) return uSupernovaLevels0.w;
  if (index == 4) return uSupernovaLevels1.x;
  if (index == 5) return uSupernovaLevels1.y;
  if (index == 6) return uSupernovaLevels1.z;
  return uSupernovaLevels1.w;
}
vec3 supernovaLight(vec3 dir) {
  vec3 light = vec3(0.0);
  for (int i = 0; i < 8; i++) {
    float grown = clamp(supernovaLevel(i) / 7.0, 0.0, 1.0);
    float wide = mix(0.3, 0.6, grown);
    float tight = mix(0.11, 0.18, grown);
    float theta2 = 2.0 * (1.0 - dot(dir, uSupernovas[i]));
    // Far from this supernova its light is far below one shade of color.
    if (theta2 > wide * wide * 10.0) continue;
    float amount = exp(-theta2 / (wide * wide)) * mix(0.18, 0.55, grown) +
        exp(-theta2 / (tight * tight)) * mix(0.1, 0.22, grown);
    vec3 warmth = mix(vec3(1.0, 0.8, 0.6), vec3(1.0, 0.58, 0.3), grown);
    light += warmth * amount;
  }
  return light * uSupernovaLight;
}

// This pixel's direction on the sky for a camera at [zoom] — the same
// inverse stereographic projection main() explains. Layers sampled at a
// slightly different zoom than the real one drift apart as you zoom: the
// zoom parallax that puts the dark nebulae in front and the faint stars
// far behind.
vec3 skyDirection(float zoom) {
  vec2 centered = FlutterFragCoord().xy - uResolution * 0.5;
  vec2 tangent = centered / uResolution.y / zoom;
  float tx = tangent.x;
  float ty = -tangent.y;
  float rho2 = tx * tx + ty * ty;
  float denom = 4.0 + rho2;
  return normalize(
    uRight * (4.0 * tx / denom) +
    uUp * (4.0 * ty / denom) +
    uForward * ((4.0 - rho2) / denom)
  );
}


// Distant galaxies: rare, small, and — zoomed in — recognisably galaxies,
// not smudges: a warm yellowish core, two (or, for an elliptical one, no)
// spiral arms in cooler blue-white, a thin dark dust lane, a few pink knots
// where new stars are forming, and above all a sprinkle of resolved
// pinpoint stars tracing the arms. Never gold, never rays: far-away
// scenery, not something to tap.
vec3 galaxyLayer(vec3 dir, float density, float seed) {
  vec3 grid = dir * density;
  vec3 cell = floor(grid);
  vec3 local = fract(grid) - 0.5;
  float h = hash3(cell + seed);
  if (h < 0.88) return vec3(0.0);

  vec3 pos = (vec3(
    hash3(cell + seed * 2.0),
    hash3(cell + seed * 3.0),
    hash3(cell + seed * 4.0)
  ) - 0.5) * 0.06;
  vec3 diff = local - pos;
  // Each galaxy's own orientation, in the plane tangent to the sky here.
  vec3 rnd = vec3(
    hash3(cell + seed * 5.0),
    hash3(cell + seed * 6.0),
    hash3(cell + seed * 7.0)
  ) - 0.5;
  vec3 u = normalize(rnd - dir * dot(rnd, dir) + vec3(1e-4));
  vec3 v = cross(dir, u);
  vec2 p = vec2(dot(diff, u), dot(diff, v));
  // Seen at a slant: squashed along one axis.
  float tilt = mix(0.32, 1.0, hash3(cell + seed * 8.0));
  p.y /= tilt;
  float scale = mix(0.055, 0.095, hash3(cell + seed * 9.0));
  p /= scale;
  float r = length(p);
  if (r > 3.0) return vec3(0.0);
  float theta = atan(p.y, p.x);

  bool spiral = hash3(cell + seed * 10.0) > 0.3;
  // How much of this point lies on an arm: two logarithmic arms winding
  // out from the core, sharpened into bands.
  float winding = mix(2.6, 4.2, hash3(cell + seed * 12.0));
  float armWave = 0.5 + 0.5 * cos(2.0 * theta - log(r + 0.08) * winding + h * 40.0);
  float arms = spiral ? pow(armWave, 3.0) : 0.6;

  float disk = exp(-r * 1.6);
  float bulge = exp(-r * r * 9.0);
  // A thin dark lane along the disk, strongest for galaxies seen edge-on.
  float lane = exp(-pow(p.y * tilt / 0.08, 2.0)) *
      smoothstep(0.15, 0.6, r) * (1.0 - tilt) * 0.8;

  // Resolved stars: a fine grid in the galaxy's own plane, each cell maybe
  // holding one pinpoint, far likelier on an arm and near the center.
  const float kStarGrid = 11.0;
  vec2 starGrid = p * kStarGrid;
  vec2 starCell = floor(starGrid);
  vec2 starLocal = fract(starGrid) - 0.5;
  float sh = hash3(vec3(starCell, seed * 13.0) + cell);
  vec2 starOffset = vec2(
    hash3(vec3(starCell, seed * 14.0) + cell),
    hash3(vec3(starCell, seed * 15.0) + cell)
  ) - 0.5;
  float chance = (spiral ? arms * 0.85 + 0.1 : 0.45) * exp(-r * 0.7);
  float starOn = step(1.0 - chance * 0.38, sh);
  vec2 sd = starLocal - starOffset * 0.6;
  float twinkle = 0.7 + 0.3 * sin(uTime * (1.5 + sh * 3.0) + sh * 50.0);
  // One screen pixel, in this star grid's units: a pinpoint is never
  // drawn thinner than about a pixel (it would shimmer); when the view is
  // too far out for that, it widens and dims by the same amount, melting
  // into the disk.
  float pixelAngle = 1.0 / (uResolution.y * uZoom);
  float pixelInGrid = pixelAngle * density / scale * kStarGrid;
  float sigma = max(0.16, pixelInGrid * 0.7);
  float pinpoint = starOn * exp(-dot(sd, sd) / (sigma * sigma)) *
      twinkle * pow(0.16 / sigma, 2.0);

  // Pink star-forming knots, scattered along the arms of spirals only.
  float knotHash = hash3(vec3(floor(p * 4.0), seed * 16.0) + cell);
  vec2 knotLocal = fract(p * 4.0) - 0.5;
  float knot = spiral
      ? step(0.82, knotHash) * arms *
          exp(-dot(knotLocal, knotLocal) / (0.09 * 0.09))
      : 0.0;

  float tone = hash3(cell + seed * 11.0);
  vec3 armColor = tone < 0.5 ? vec3(0.62, 0.74, 1.0) : vec3(0.76, 0.72, 1.0);
  vec3 coreColor = vec3(1.0, 0.88, 0.7);

  vec3 color = coreColor * bulge * 0.55 +
      armColor * disk * (0.12 + arms * 0.32) +
      vec3(0.9, 0.94, 1.0) * pinpoint * (0.55 + disk * 0.6) +
      vec3(1.0, 0.55, 0.75) * knot * 0.35;
  color *= 1.0 - lane;

  float edgeFade = smoothstep(
    0.5,
    0.36,
    max(max(abs(local.x), abs(local.y)), abs(local.z))
  );
  return color * edgeFade;
}

// Comets: now and then a thin, cold streak — a bright head with a tail
// that widens and fades behind it — slides across the sky. Its end is a
// small event: the head swells into a bigger flash, flickers fast, and is
// gone at once. Each [seed] is its own stream: one comet per [period]
// seconds, somewhere on the sphere, at a random moment.
vec3 cometStream(vec3 dir, float seed, float period) {
  const float kDuration = 1.9;
  float slot = floor(uTime / period);
  float start = hash3(vec3(slot, seed, 1.0)) * (period - kDuration);
  float t = uTime - slot * period - start;
  if (t < 0.0 || t > kDuration) return vec3(0.0);

  vec3 origin = normalize(vec3(
    hash3(vec3(slot, seed, 2.0)),
    hash3(vec3(slot, seed, 3.0)),
    hash3(vec3(slot, seed, 4.0))
  ) - 0.5 + vec3(1e-3));
  vec3 rnd = vec3(
    hash3(vec3(slot, seed, 5.0)),
    hash3(vec3(slot, seed, 6.0)),
    hash3(vec3(slot, seed, 7.0))
  ) - 0.5;
  vec3 travel = normalize(rnd - origin * dot(rnd, origin) + vec3(1e-4));
  vec3 normal = cross(origin, travel);

  // Each comet's own size (small, medium, large) and tone (white, blue,
  // gold — the constellation stars' own families), picked independently,
  // so every size comes in every color. Gold is fine here: a comet has no
  // rays and is gone in two seconds, it can't pass for a tappable star.
  float sizeRoll = hash3(vec3(slot, seed, 8.0));
  float size = sizeRoll < 0.4 ? 0.7 : sizeRoll < 0.8 ? 1.0 : 1.45;
  float toneRoll = hash3(vec3(slot, seed, 9.0));
  vec3 tailColor = toneRoll < 0.34
      ? vec3(0.86, 0.9, 1.0)
      : toneRoll < 0.67
      ? vec3(0.58, 0.76, 1.0)
      : vec3(1.0, 0.8, 0.42);
  // The head is the same tone, nearer white, like a star's hot core.
  vec3 headColor = mix(tailColor, vec3(1.0), 0.6);

  float progress = t / kDuration;
  // Steady speed until 60% of its life, then braking evenly to a stop at
  // 95% — the very last frames, flash and flicker, happen standing still.
  const float kBrakeFrom = 0.6;
  const float kStopAt = 0.95;
  float braking = clamp(progress - kBrakeFrom, 0.0, kStopAt - kBrakeFrom);
  float travelled = min(progress, kBrakeFrom) + braking -
      braking * braking / (2.0 * (kStopAt - kBrakeFrom));
  // Sized against the constellations: a head about as big as one of their
  // stars, a tail about one constellation long, a matching travel.
  float headAngle = travelled * 0.3 * size;
  vec3 head = origin * cos(headAngle) + travel * sin(headAngle);
  // Only the half of the sphere around the head; the angle below would
  // wrap round to the far side otherwise.
  if (dot(dir, head) < 0.8) return vec3(0.0);

  // Its life: a quick fade in, the glide, then the end — a flash peaking
  // at 85%, a fast flicker from about 89%, and nothing left from 96.5%.
  float fadeIn = smoothstep(0.0, 0.12, progress);
  float flash = exp(-pow((progress - 0.85) / 0.045, 2.0));
  float flickerZone = smoothstep(0.885, 0.9, progress);
  float flicker = mix(1.0, step(0.0, sin(t * 70.0)), flickerZone) *
      (1.0 - step(0.965, progress));
  float headBright =
      fadeIn * (1.0 + 0.9 * flash) * flicker * (1.0 - 0.45 * flickerZone);
  // Nearing its end the tail draws back into the head — shorter and
  // narrower, a touch brighter as it gathers — until, as the flash peaks,
  // it has gone back into it entirely.
  float retract = smoothstep(0.6, 0.85, progress);
  float tailLife = fadeIn * (1.0 + 0.4 * retract) *
      (1.0 - smoothstep(0.8, 0.85, progress));

  float off = dot(dir, normal);
  float along = atan(dot(dir, travel), dot(dir, origin));
  float behind = headAngle - along;
  float tailLength = max(0.1 * size * (1.0 - retract), 1e-4);
  float width =
      (0.0007 + max(behind, 0.0) * 0.012 * (1.0 - retract * 0.7)) * size;
  float lateral = exp(-(off * off) / (width * width));
  float tail = behind > 0.0 && behind < tailLength
      ? pow(1.0 - behind / tailLength, 2.2)
      : 0.0;
  vec2 toHead = vec2(along - headAngle, off);
  float d2 = dot(toHead, toHead);
  float headSize = 0.0015 * size * (1.0 + 0.6 * flash);
  float headGlow = exp(-d2 / (headSize * headSize)) +
      exp(-d2 / (headSize * headSize * 6.25)) * 0.18 * flash;
  return tailColor * tail * lateral * 0.55 * tailLife +
      headColor * headGlow * headBright;
}

// Interleaved-gradient-noise dither, ±½ of one 8-bit step. These glows fade
// over hundreds of pixels at high zoom, so without it the 8-bit output
// quantizes into visible bands/grain instead of a smooth gradient.
float ditherNoise() {
  return fract(52.9829189 * fract(dot(FlutterFragCoord().xy, vec2(0.06711056, 0.00583715)))) - 0.5;
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
  // Zoom parallax (see [skyDirection]): five depths of stars, each one
  // magnified a little faster (nearer) or slower (farther) than the real
  // zoom, so zooming in reads as moving through them. The gas, the dark
  // dust and everything else stay at the real zoom, out in the sky.
  vec3 dirFarthest = skyDirection(uZoom * pow(uZoom, -0.16));
  vec3 dirFar = skyDirection(uZoom * pow(uZoom, -0.08));
  vec3 dirNear = skyDirection(uZoom * pow(uZoom, 0.12));
  vec3 dirNearest = skyDirection(uZoom * pow(uZoom, 0.26));
  vec3 dirClose1 = skyDirection(uZoom * pow(uZoom, 0.4));
  vec3 dirClose2 = skyDirection(uZoom * pow(uZoom, 0.55));
  vec3 dirClose3 = skyDirection(uZoom * pow(uZoom, 0.7));

  // A bigger sky sphere reads as one with finer, denser detail — more (and
  // smaller) stars, and finer-grained gas structure — the same way a
  // deeper, more distant starfield looks busier than a small one right in
  // front of you. Bumped up again from the previous pass, in step with
  // NebulaScreen's own zoom range moving farther back (see
  // NebulaScreen._maxZoom's comment) — the same visible field of view now
  // covers noticeably more of the sky than before, so it needs more detail
  // packed into it to read as "farther away" rather than just "emptier."
  vec3 nebula;
  float darkness;
  vec2 texel = FlutterFragCoord().xy / uResolution;
  if (uMode > 1.5 && uMode < 2.5) {
    // The clouds and dust from their snapshots.
    nebula = mix(
      texture(uCloudsA, texel).rgb,
      texture(uCloudsB, texel).rgb,
      uBlend
    );
    darkness = texture(uDarkness, texel).r;
  } else {
  // Dust out in the sky, at the gas's own depth.
  vec2 dark = darkNebula(dir);
  darkness = dark.x;
  if (uMode > 2.5 && uMode < 3.5) {
    fragColor = vec4(vec3(darkness), 1.0);
    return;
  }

#if STAR_CACHE
  if (uMode > 3.5) {
    // The stars snapshot: no clouds under them.
    nebula = vec3(0.0);
  } else
#endif
  {
  vec3 timeDrift = vec3(uTime * 0.02, -uTime * 0.015, uTime * 0.008);
  float n = fbm3(dir * 6.0 + timeDrift);
  float n2 = fbm3(dir * 10.0 + timeDrift * 1.7 + 4.0);

  // Deep voids and lit gas: the noise pushed apart so the empty sky sinks
  // toward black and only the clouds keep the blue — contrast is depth.
  // Gold stays reserved for the brightest noise peaks only.
  const vec3 kVoid = vec3(0.006, 0.009, 0.02);
  float cloud = smoothstep(0.32, 0.78, n);
  nebula = mix(kVoid, kDeepCenter, cloud);
  nebula = mix(nebula, kGold, pow(n2, 4.0) * 0.65);
  // Warm light around each supernova, on the gas only — never the empty
  // sky — as wide and warm as its area's intensity. (Lighting only the
  // cloud side facing the supernova was tried and dropped: it looked
  // wrong.)
  nebula += supernovaLight(dir) * cloud * 0.6;

  // The dust dims the gas behind it.
  const vec3 kRimLight = vec3(0.32, 0.4, 0.62);
  nebula = nebula * (1.0 - darkness) + kRimLight * dark.y * 0.06;
  if (uMode > 0.5) {
    // The clouds snapshot, dithered here exactly as the live sky is at
    // the end — where no star shines, the cached sky is the same pixel
    // for pixel.
    fragColor = vec4(max(nebula + ditherNoise() / 255.0, 0.0), 1.0);
    return;
  }
  }
  }

  // Which star depths are computed here, and which come from the stars
  // snapshots — see [uStarDepth].
#if STAR_CACHE
  bool starsSnapshot = uMode > 3.5;
  bool starsCached = uMode > 1.5 && uMode < 2.5 && uStarDepth > 0.5;
  bool liveDeep = !starsCached;
  bool liveFront = starsSnapshot
      ? uStarDepth > 1.5
      : !(starsCached && uStarDepth > 1.5);
  // A real branch, not a ?: — that may sample both sides on the GPU.
  vec3 cachedStars = vec3(0.0);
  if (starsCached) {
    cachedStars = mix(
      texture(uStarsA, texel).rgb,
      texture(uStarsB, texel).rgb,
      uBlend
    );
  }
#else
  // The full sky computes them all, always.
  const bool starsSnapshot = false;
  const bool liveDeep = true;
  const bool liveFront = true;
  const vec3 cachedStars = vec3(0.0);
#endif

  // Scenery only — see the rule of thumb above the scenery functions: no
  // gold, no rays. From the farthest depth to the nearest: the two far
  // ones sit behind the dust, the mid one half veiled, the near ones in
  // front of it.
  // The stars carry the zoom parallax, so there are plenty at every depth.
  vec3 deep = vec3(0.0);
  if (liveDeep) {
  vec3 farthest = dustStarLayer(dirFarthest, 240.0, 4.1, 97.0) * 0.28 +
      dustStarLayer(dirFarthest, 200.0, 3.9, 31.0) * 0.3 +
      dustStarLayer(dirFarthest, 150.0, 3.8, 23.0) * 0.35 +
      dustStarLayer(dirFarthest, 110.0, 4.2, 29.0) * 0.4;
  vec3 far = dustStarLayer(dirFar, 95.0, 3.7, 101.0) * 0.45 +
      dustStarLayer(dirFar, 80.0, 4.0, 19.0) * 0.5 +
      dustStarLayer(dirFar, 60.0, 3.4, 37.0) * 0.55 +
      dustStarLayer(dirFar, 45.0, 3.1, 13.0) * 0.6;
  vec3 mid = dustStarLayer(dir, 38.0, 2.8, 103.0) * 0.7 +
      dustStarLayer(dir, 32.0, 2.6, 41.0) * 0.75 +
      dustStarLayer(dir, 22.0, 2.3, 7.0) * 0.85 +
      dustStarLayer(dir, 15.0, 1.6, 1.0);
  // The galaxies stay at the sky's real depth: the stars do the parallax.
  vec3 galaxies =
      galaxyLayer(dir, 2.4, 43.0) + galaxyLayer(dir, 3.6, 47.0) * 0.85;
  deep = (farthest + far + galaxies) * (1.0 - 0.95 * darkness) +
      mid * (1.0 - 0.5 * darkness);
  }

  vec3 front = vec3(0.0);
  if (liveFront) {
  vec3 near = dustStarLayer(dirNear, 24.0, 1.7, 107.0) * 1.0 +
      dustStarLayer(dirNear, 18.0, 1.5, 59.0) * 1.1 +
      dustStarLayer(dirNear, 12.0, 1.3, 53.0) * 1.1 +
      nearStarLayer(dirNear, 14.0, 67.0, 0.8, 1.0) * 0.7;
  vec3 nearest = nearStarLayer(dirNearest, 13.0, 109.0, 0.82, 1.0) * 0.85 +
      nearStarLayer(dirNearest, 11.0, 89.0, 0.8, 1.0) * 0.9 +
      nearStarLayer(dirNearest, 9.0, 61.0, 0.78, 1.0) +
      nearStarLayer(dirNearest, 6.0, 83.0, 0.75, 1.0);
  // Three more depths right in front of the camera: few stars each, a
  // little bigger, magnified ever faster as you zoom — the strongest pull
  // of the parallax.
  vec3 closeStars =
      nearStarLayer(dirClose1, 5.0, 113.0, 0.82, 1.2) * 0.85 +
      nearStarLayer(dirClose2, 3.6, 127.0, 0.8, 1.4) * 0.8 +
      nearStarLayer(dirClose3, 2.6, 131.0, 0.78, 1.6) * 0.75;
  front = near + nearest + closeStars;
  }

  if (starsSnapshot) {
    fragColor = vec4(deep + front, 1.0);
    return;
  }

  // Six streams with different periods, scaled by [kCometPeriodScale]:
  // at 1.0 about one comet a second somewhere on the sphere. Lower means
  // more often (never below ~0.4: a period must outlast a comet's 1.9 s).
  // REVIEW (2026-10-15): 0.45, more than twice as many, so the user can
  // watch them closely; set back to 1.0 once they are tuned.
  const float kCometPeriodScale = 0.45;
  vec3 comets = cometStream(dir, 1.0, 5.0 * kCometPeriodScale) +
      cometStream(dir, 2.0, 6.0 * kCometPeriodScale) +
      cometStream(dir, 3.0, 7.0 * kCometPeriodScale) +
      cometStream(dir, 4.0, 8.0 * kCometPeriodScale) +
      cometStream(dir, 5.0, 9.0 * kCometPeriodScale) +
      cometStream(dir, 6.0, 11.0 * kCometPeriodScale);

  vec3 color = nebula + deep + front + cachedStars + comets;

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

  // The cached clouds already carry their dither (see the snapshot above).
  float dither = uMode > 1.5 ? 0.0 : ditherNoise() / 255.0;
  fragColor = vec4(max(color + dither, 0.0), 1.0);
}
