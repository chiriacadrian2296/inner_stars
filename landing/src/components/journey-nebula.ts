import galaxySource from '../../../shaders/nebula_particles.glsl?raw';
import supernovaSource from '../../../shaders/sky_supernova.frag?raw';
import flareSource from '../../../shaders/constellation_flare.frag?raw';

// The actual Galaxy sources; only Flutter's coordinate entry point and GLSL
// version change. Clouds, dust, star depths, comets and supernovas stay shared.
const browserSource = (source: string) => `#version 300 es
#define STAR_CACHE 0
${source.replace(/^#version .*$/gm, '').replace(/^#include .*$/gm, '').replace(/uniform vec2 uResolution;/g, '').replace('precision highp float;', `precision highp float;
uniform vec2 uResolution;
uniform vec2 uViewOffset;
vec4 FlutterFragCoord() { return vec4(gl_FragCoord.x-uViewOffset.x, uResolution.y-gl_FragCoord.y-uViewOffset.y, 0.0, 1.0); }`)}`;
export const fragmentSource = browserSource(galaxySource);
// The landing flattens the whole-sky chapter into an even map, so the eight
// supernova positions come from a uniform array (the app derives them from its
// fixed Fibonacci lattice, which is what the array holds until the map forms) and,
// with uFlat > 0, each glow turns to the screen's own axes instead of the
// sphere's tilted ones. Everything else in the shader is untouched.
const patchOnce = (source: string, from: string, to: string) => {
  if (!source.includes(from)) throw new Error(`Supernova shader changed: ${from.slice(0, 40)}`);
  return source.replace(from, () => to);
};
const flatSupernova = [
  (s: string) => patchOnce(s, 'vec3 supernovaDirection(float index) {', 'uniform vec3 uSupernovas[8];\nuniform float uFlat;\nuniform float uHalo;\nvec3 supernovaDirectionLattice(float index) {'),
  (s: string) => patchOnce(s, '  float glow = exp(-dist * 3.0) * 0.9;', '  float glow = exp(-dist * 3.0) * 0.9 * uHalo;'),
  (s: string) => patchOnce(s, 'vec3 adjustedSupernovaDirection(int index) {', [
    'vec3 supernovaDirection(float index) { return uSupernovas[int(index + 0.5)]; }',
    '',
    'vec3 flatScreenDir(vec2 s) {',
    '  float r2 = dot(s, s);',
    '  float d = 4.0 + r2;',
    '  return normalize(uRight * (4.0 * s.x / d) + uUp * (4.0 * s.y / d) + uForward * ((4.0 - r2) / d));',
    '}',
    '',
    'vec3 adjustedSupernovaDirection(int index) {',
  ].join('\n')),
  (s: string) => patchOnce(s, '  vec3 axisB = cross(center, axisA);\n  vec2 uv =', [
    '  vec3 axisB = cross(center, axisA);',
    '  if (uFlat > 0.0) {',
    '    vec2 s = vec2(dot(center, uRight), dot(center, uUp)) * 2.0 / (1.0 + dot(center, uForward));',
    '    vec3 here = flatScreenDir(s);',
    '    vec3 screenRight = normalize(flatScreenDir(s + vec2(0.01, 0.0)) - here);',
    '    // Turn the glow by the (smallest, the glow is four-fold symmetric) angle that squares it with the screen;',
    '    // rotating rather than blending axes keeps it stable all the way through.',
    '    float turn = atan(dot(screenRight, axisB), dot(screenRight, axisA));',
    '    turn = mod(turn + 0.7853982, 1.5707963) - 0.7853982;',
    '    float angle = turn * uFlat;',
    '    vec3 turnedA = axisA * cos(angle) + axisB * sin(angle);',
    '    axisB = axisB * cos(angle) - axisA * sin(angle);',
    '    axisA = turnedA;',
    '  }',
    '  vec2 uv =',
  ].join('\n')),
].reduce((source, patch) => patch(source), supernovaSource.replace(/\r\n/g, '\n'));
export const supernovaFragmentSource = browserSource(flatSupernova);
export const flareFragmentSource = browserSource(flareSource);
export const vertexSource = `#version 300 es
in vec2 aPosition;
void main() { gl_Position = vec4(aPosition, 0.0, 1.0); }`;
