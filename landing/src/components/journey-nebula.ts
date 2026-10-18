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
export const supernovaFragmentSource = browserSource(supernovaSource);
export const flareFragmentSource = browserSource(flareSource);
export const vertexSource = `#version 300 es
in vec2 aPosition;
void main() { gl_Position = vec4(aPosition, 0.0, 1.0); }`;
