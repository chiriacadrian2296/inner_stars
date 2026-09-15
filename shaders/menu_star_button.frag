#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
// World-units-to-pixels for the glow math below — chosen in Dart so the
// shader's own fixed ringRadius (0.09 world units) lands at whatever
// pixel radius the caller wants (see `_MenuStarButton`: sized to match
// the icon drawn on top of this).
uniform float uScale;
// 0 at rest, ramping to 1 over the short wait between a tap and the menu
// actually opening (see `_MenuStarButtonState`'s own charge controller)
// — driven by an [AnimationController], not [uTime], since it needs to
// start from an arbitrary point in that continuous cycle on every tap.
uniform float uCharge;

out vec4 fragColor;

// One ray, tapering as it goes, extending in only *one* direction from
// center (unlike sky_supernova.frag's own horiz/vert/diag spikes, each
// really a bidirectional line straight through center) — a 5-pointed
// star has no opposite-side symmetry to mirror through, so each of its
// 10 vertices gets its own ray rather than sharing one line with another
// vertex 180 degrees away.
float uniRay(vec2 v, float angle, float baseW, float taperRate, float falloffRate) {
  float c = cos(angle);
  float s = sin(angle);
  float along = max(v.x * c + v.y * s, 0.0);
  float perp = -v.x * s + v.y * c;
  float width = baseW * exp(-along * taperRate);
  return smoothstep(width, 0.0, abs(perp)) * exp(-along * falloffRate);
}

// One fixed supernova glow — the same look shaders/sky_supernova.frag
// draws for each of the 8 life areas (see that file for the fuller
// per-term reasoning behind every one of these: glow, ring, a four-point
// star core, tapered four-point cross spikes, all the same shared gold),
// but with the 3D sky-direction/camera projection stripped out entirely.
// This decoration never moves with the sky — it always sits fixed right
// behind the menu button — so it has no camera to project through in the
// first place; [uv] here is just this canvas's own centered, scaled 2D
// coordinate.
vec3 supernovaGlow(vec2 uv, vec3 midColor, vec3 outerColor, float maxRadius, float charge) {
  float dist = length(uv);

  // A touch gentler than sky_supernova.frag's own 0.94/0.06 — that pulse
  // reads fine spread across a whole life area's worth of sky, but once
  // [glow]/[nearGlow] below were brought back up closer to that file's
  // own strength, the same swing here was rocking the button's own
  // brightness harder than a small, always-on control should.
  float pulse = 0.955 + 0.045 * sin(uTime * 0.6);

  // Brought back up again — dimmed twice before (most recently to
  // 0.4/1.05) for reading too bright next to a press, but that turned out
  // too washed-out at rest, which is what this control spends the vast
  // majority of its time doing. Sits above even the once-tried
  // sky_supernova.frag-matching 0.9/1.1 now, not just back to it. [glow]'s
  // own reach is still pulled way in (rate 3.0 -> 18.0): it's the soft
  // background disc behind everything else here, and at the old, much
  // slower decay it kept glowing well past `ringRadius`, past where a
  // "glow around the ring" should still read as tucked behind it.
  float glow = exp(-dist * 18.0) * 0.55;
  // The button's one central glow — purely a function of [dist], so it
  // never traces any shape (not the star's outline, not the ring): a
  // soft blob sitting underneath both, lighting them from below, the
  // same role sky_supernova.frag's own glow/nearGlow pair plays for the
  // real supernovas. This is the resting/idle glow, seen the vast
  // majority of the time the button just sits there unpressed — brought
  // back up along with [glow] above, see its own note.
  float nearGlow = exp(-dist * 22.0) * 1.4;

  // The ring itself moved to Dart, painted *after* the icon (see
  // `_MenuStarSupernovaPainter.paint`'s own paintRing) instead of being
  // part of this additive glow drawn first: at 0.09 world units its own
  // radius sits well inside the icon's, so drawn here it was the icon
  // sitting on top of the ring rather than the other way around.
  float ring = 0.0;
  float ringGlow = 0.0;

  // [Icons.star]'s glyph isn't drawn around the exact center of its own
  // em-square: measuring its actual path (a regular pentagram fits its
  // 5 tips to within a fraction of a degree once you do), the glyph's
  // true center sits about half a unit further down its 24-unit grid
  // than the box TextPainter centers on this canvas — worth correcting
  // for here since it's exactly the kind of few-degree miss that made
  // the rays look *close* to the points but not quite on them. Rays are
  // aimed from that true center instead of straight uv (0,0).
  vec2 rayUv = uv - vec2(0.0, 0.0043);

  // The 10 vertices of a 5-pointed star (screen angle, radians): 5 outer
  // "points" every 72 degrees starting straight up (-90 degrees, i.e.
  // -pi/2 — up is -y in this Y-down screen space), and 5 inner "valley"
  // vertices offset 36 degrees (pi/5) from those, right in between each
  // consecutive pair. On screen, [Icons.star]'s own glyph vertices land
  // on the *inner* angle here, not the outer one — the opposite
  // assumption had the long/bright rays shooting from the valleys and
  // the short/dim ones from the points, backwards from how a twinkling
  // star should read — so the inner angle gets the main (brighter,
  // longer) rays and the outer angle gets the secondary (dimmer,
  // shorter) ones. Both sized way down from the first pass (tuned for a
  // supernova far from the icon drawn on top of it, way too big for one
  // sitting right behind it) and shortened again since, three times over
  // now — each pass roughly halving the reach of the one before it. The
  // main rays' own taper is steeper still on top of that, so they thin
  // out faster toward their own tips instead of holding a near-constant
  // width.
  //
  // Disabled for now, just to see the button with no rays at all — the
  // loop's left in place rather than deleted, both values one line away
  // from coming right back.
  float spikes = 0.0;
  // for (int k = 0; k < 5; k++) {
  //   float outerAngle = -1.5707963 + float(k) * 1.2566371;
  //   float innerAngle = outerAngle + 0.6283185;
  //   spikes += uniRay(rayUv, innerAngle, 0.005, 17.0, 100.0) * 1.4;
  //   spikes += uniRay(rayUv, outerAngle, 0.0025, 24.0, 150.0) * 0.4;
  // }

  // [core] was the same small four-point star-shaped blob
  // sky_supernova.frag draws at its own center — disabled, since unlike
  // [nearGlow] it isn't purely radial (it's a 4-point diamond, built
  // from uv.x/uv.y directly), so it's still a shape of its own layered
  // on top of the star's.
  // `float starMetric = sqrt(abs(uv.x)) + sqrt(abs(uv.y));`
  // `float core = smoothstep(0.22, 0.0, starMetric);`
  float core = 0.0;

  // A second, separate glow that only exists while the button is being
  // held down (see `_MenuStarButtonState`'s own charge controller — a
  // press doesn't open the menu immediately, it has to be held instead,
  // so there's something to see growing under the finger the whole
  // time it's down). Both wider and brighter as [charge] ramps 0 -> 1 —
  // an actual growing glow, not just a brightening one.
  //
  // This glow's own *reach* is roughly 1/chargeRate (where exp(-dist *
  // chargeRate) drops to a fixed fraction) — so interpolating chargeRate
  // itself linearly (mix(40.0, 2.0, charge), tried first) made the
  // reach 1/mix(40,2,charge), which barely grows for most of the hold
  // and then balloons in the last moment as the rate bottoms out — a
  // sudden jump right at the end, not a smooth grow. Interpolating the
  // *radius* linearly instead (chargeRadius below) and deriving the
  // rate from that keeps the actual on-screen growth even across the
  // whole charge.
  // Max-charge radius pulled in to half of what it was (1/4.0, was
  // 1/2.0) — still noticeably bigger than the resting glow, just not
  // as large as it had grown to.
  float chargeRadius = mix(1.0 / 40.0, 1.0 / 4.0, charge);
  float chargeRate = 1.0 / chargeRadius;
  float chargeGlow = exp(-dist * chargeRate) * charge * 1.4;

  float brightness = (
      core * 2.2 +
      spikes +
      glow + nearGlow + ringGlow + chargeGlow
    ) * pulse + ring;

  // A safety net regardless of how [glow]/[spikes] above happen to be
  // tuned: this canvas is a small, fixed square (see
  // `_MenuStarButton._glowCanvasSize`), and any term whose value is
  // still nonzero right at that square's edge stops dead the instant
  // the canvas does — a faint but sharp square silhouette around the
  // button instead of a glow fading into nothing. Ramping brightness
  // down to exactly 0 before [dist] reaches the canvas edge (in these
  // same world units) removes that edge rather than just hiding it
  // better. Starts even earlier now (0.18, was then 0.35, was 0.6): at
  // full charge, [chargeGlow] is still quite bright right where a
  // narrower window would begin, so the same amount of brightness had
  // to drop to 0 over too short a span — a visible edge where the glow
  // stopped, not the long, soft fade this is supposed to be. Starting
  // the taper earlier spreads that same drop over more of the canvas
  // instead.
  brightness *= 1.0 - smoothstep(maxRadius * 0.18, maxRadius, dist);

  // colorCore is pale, not pure white — mixing toward it as brightness
  // climbs is what keeps a genuinely bright spot reading as "glowing
  // hot" (whiter) rather than just a more saturated version of the same
  // blue; [chargeGlow] is in this mix for the same reason [nearGlow]
  // already was — without it, the held-button glow stayed fully
  // saturated blue right up until individual color channels clipped on
  // their own, which read as harsh rather than bright. Cool/neutral now
  // (was warm — 1.0/0.98/0.9 — left over from when this whole glow was
  // still gold): whitening *toward warm* is what a hot ember does, but
  // this glow is blue, and mixing blue toward a warm target just turned
  // it an odd purple on the way rather than paling cleanly.
  vec3 colorCore = vec3(0.95, 0.97, 1.0);
  vec3 color = mix(outerColor, midColor, smoothstep(0.0, 0.25, glow + spikes * 0.3));
  color = mix(
    color,
    colorCore,
    clamp(core * 1.5 + nearGlow * 0.3 + ring * 0.96 + chargeGlow * 0.35, 0.0, 1.0)
  );

  return color * brightness;
}

void main() {
  vec2 centered = FlutterFragCoord().xy - uResolution * 0.5;
  vec2 uv = centered / uScale;

  // Blue here instead of the shared gold every other glow in the app uses
  // (sky_supernova.frag included) — same two-stop mid/outer structure,
  // just a cooler hue. midColor is outerColor lifted toward white (same
  // ~0.55 mix in both) for the glow's brighter center, so the logo (see
  // assets/icon/app_icon_ring_centered_white.png) and this glow read as
  // made of the same material. outerColor itself was originally
  // colors.nightPanel (#161D30) exactly, matching the quick-access menu
  // buttons around this one — but [brightness] below fades the glow
  // toward black well before the canvas edge (see its own comment), so
  // the disc's actual visible tone always read darker than that nominal
  // value, closer to colors.night (#0D1220) than colors.nightPanel.
  // Nudged to #181D2F (measured against the quick-access buttons'
  // rendered nightPanel fill, not the raw constant) to compensate.
  vec3 midColor = vec3(0.592, 0.601, 0.633);
  vec3 outerColor = vec3(0.094, 0.114, 0.184);
  // Canvas is square (uResolution.x == uResolution.y), in the same
  // world units as [uv] — the radius the glow must fade to 0 within.
  float maxRadius = uResolution.x * 0.5 / uScale;

  vec3 total = supernovaGlow(uv, midColor, outerColor, maxRadius, uCharge);

  // The canvas is much bigger than the glow itself (see
  // `_MenuStarButton._glowCanvasSize`'s own doc comment) specifically so
  // the glow can fade to nothing well before the canvas edge — but with
  // alpha hardcoded to 1.0 here, "fade to nothing" only ever actually
  // happened via `BlendMode.plus` in the caller: additive blending makes
  // adding near-black a no-op, so the fully-opaque-but-near-black edge
  // quietly disappeared into whatever was behind it. That's true on
  // mobile, but confirmed live on the web build (screenshot from the
  // user): additive blending isn't reliably applied there, so this
  // canvas painted as a real, visible dark square sitting right over the
  // sky behind it instead of fading away.
  //
  // Alpha now fades on the exact same radial taper `brightness` itself
  // already uses inside `supernovaGlow` (recomputed here since that
  // taper is local to that function) — same curve, so this doesn't
  // double up on the falloff already baked into `total`, it just also
  // makes the *canvas itself* properly transparent past the glow's own
  // reach. That's correct under ordinary alpha compositing regardless of
  // blend mode, which a blend-mode trick alone was never a reliable way
  // to guarantee everywhere.
  float dist = length(uv);
  float alpha = 1.0 - smoothstep(maxRadius * 0.18, maxRadius, dist);

  fragColor = vec4(total, alpha);
}
