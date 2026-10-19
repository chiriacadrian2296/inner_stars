import presets from './galaxy-presets.json';
export type Vec = [number, number, number];
export const add = (a: Vec, b: Vec): Vec => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
export const mul = (v: Vec, n: number): Vec => [v[0] * n, v[1] * n, v[2] * n];
export const dot = (a: Vec, b: Vec) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
export const cross = (a: Vec, b: Vec): Vec => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
export const norm = (v: Vec): Vec => mul(v, 1 / Math.max(.00001, Math.hypot(...v)));
export const mix = (a: Vec, b: Vec, t: number) => {
  if (dot(a, b) < -.999) {
    const axis = norm(cross(a, Math.abs(a[1]) < .9 ? [0, 1, 0] : [1, 0, 0]));
    return norm(add(mul(a, Math.cos(Math.PI * t)), mul(axis, Math.sin(Math.PI * t))));
  }
  return norm(add(mul(a, 1 - t), mul(b, t)));
};
export const clamp = (n: number) => Math.max(0, Math.min(1, n));
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
// Start away from the lights, approach one single star (held while its chapter
// reads), then widen through constellation, supernova and the whole sky.
// Reduced motion keeps the full sky throughout the narrative.
// Like every other chapter, the star's approach follows the scroll one-to-one: dark at step 1, the single star in place at step 2, held a moment while it is read.
export const journeyStage = (step: number) => step < 1 ? -1 + .2 * ease(step) : step < 2 ? -.8 + .8 * (step - 1) : step < 2.3 ? 0 : step < 3 ? (step - 2.3) / .7 : Math.min(3, step - 2);
export function basis(forward: Vec) {
  const azimuth = Math.atan2(forward[2], forward[0]);
  const right: Vec = [-Math.sin(azimuth), 0, Math.cos(azimuth)];
  return { forward, right, up: cross(right, forward) };
}
// Galaxy's Fibonacci area positions, .18-radian project rings and inverse
// stereographic projection, from constellation_field.dart.
export const areas: Vec[] = Array.from({ length: 8 }, (_, i) => {
  const y = 1 - i / 7 * 2, r = Math.sqrt(Math.max(0, 1 - y * y)), theta = Math.PI * (3 - Math.sqrt(5)) * i;
  return [Math.cos(theta) * r, y, Math.sin(theta) * r];
});
// constellation_field.dart: keep artwork anchored; move only its light/label.
export const supernovaOffsets = [0, .034, .0225, 0, .0095, 0, 0, .045];
export function artworkAxes(center: Vec) {
  const axisA = norm(cross(Math.abs(center[1]) < .99 ? [0, 1, 0] : [1, 0, 0], center));
  return { axisA, axisB: cross(center, axisA) };
}
export const supernovaDirections = areas.map((center, i) => norm(add(center, mul(artworkAxes(center).axisB, supernovaOffsets[i]))));
export function offset(center: Vec, radius: number, angle: number): Vec {
  const { right, up } = basis(center);
  const axis = add(mul(right, Math.cos(angle)), mul(up, Math.sin(angle)));
  return norm(add(mul(center, Math.cos(radius)), mul(axis, Math.sin(radius))));
}
export const house = [[.15, .42], [.5, .15], [.85, .42], [.85, .85], [.6, .85], [.6, .62], [.4, .62], [.4, .85], [.15, .85]];
export const edges = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 0], [0, 2]];
// The demo's hand-drawn house and the app's original normalized library grids.
const areaShapes = [
  ['mountain','bicycle','dumbbell','heartbeat','runner','tree'],
  ['leaf','yoga_pose','sun','rain_cloud','lotus','open_book'],
  ['house','laptop','graduation_cap','rocket','gear','lightbulb'],
  ['rising_chart','coins','bank','scales','diamond','wallet'],
  ['guitar','camera','sailboat','paintbrush','tent','potted_plant'],
  ['heart','two_people','handshake','speech_bubble','gift','family'],
  ['candle','lotus','temple','crescent_moon','compass','star'],
  ['heart','gift','tree','handshake','sun','two_people'],
] as const;
export const projectsPerArea=6;
export const projects = areas.flatMap((area, areaIndex) => Array.from({ length: projectsPerArea }, (_, i) => {
  const center = offset(supernovaDirections[areaIndex], .18, i / 6 * Math.PI * 2);
  const { right, up } = basis(center);
  const shape = areaIndex===2&&i===0 ? {points:house,edges} : presets[areaShapes[areaIndex][i]];
  const points = shape.points.map(([x, y]) => norm(add(center, add(mul(right, (x - .5) * .1), mul(up, (.5 - y) * .1)))));
  return { area: areaIndex, index: i, center, points, unit: shape.points as number[][], edges: shape.edges, completed:i===0||i===2, shape:areaShapes[areaIndex][i] };
}));
export const mainProject = projects[2*projectsPerArea];
export const starDirection = mainProject.points[0];
export const areaNames = { it: ['Fisica', 'Psicologica', 'Professionale', 'Finanziaria', 'Personale', 'Sociale', 'Spirituale', 'Filantropica'], ro: ['Fizică', 'Psihologică', 'Profesională', 'Financiară', 'Personală', 'Socială', 'Spirituală', 'Filantropică'], en: ['Physical', 'Psychological', 'Professional', 'Financial', 'Personal', 'Social', 'Spiritual', 'Philanthropic'] };
// The app's actual fly-to zoom percentages: 95% star, 75% project, 35% area.
const zoomFromPercent = (percent: number) => .3 * Math.pow(7.5357 / .3, percent / 100);
const starZoom = zoomFromPercent(95), projectZoom = zoomFromPercent(75), areaZoom = zoomFromPercent(35);
export function cameraAt(stage: number, area = 2) {
  const p = projects[area * projectsPerArea];
  if (stage<0) { const t=ease(stage+1); return {direction:mix(offset(p.center,.72,2.1),p.points[0],t),zoom:3.2*(1-t)+starZoom*t}; }
  if (stage < 1) return { direction: mix(p.points[0], p.center, ease(stage)), zoom: Math.exp(Math.log(starZoom) * (1 - ease(stage)) + Math.log(projectZoom) * ease(stage)) };
  if (stage < 2) return { direction: mix(p.center, areas[area], ease(stage - 1)), zoom: projectZoom * (1 - ease(stage - 1)) + areaZoom * ease(stage - 1) };
  return { direction: areas[area], zoom: areaZoom * (1 - ease(stage - 2)) + .3 * ease(stage - 2) };
}
export function projectPoint(v: Vec, camera: ReturnType<typeof basis>, zoom: number, w: number, h: number, offsetX: number, offsetY: number) {
  const z = dot(v, camera.forward);
  if (z < -.5) return null;
  const scale = 2 / (1 + z);
  return { x: w * .5 + dot(v, camera.right) * scale * zoom * h + offsetX, y: h * .5 - dot(v, camera.up) * scale * zoom * h + offsetY, scale };
}
// ---- Whole-sky view as a flat map -------------------------------------------
// In the last chapter the eight areas leave the sphere: Professional stays at the
// centre and the other seven sit evenly on a ring around it, with every
// constellation upright. Positions are planned on the plane seen by a camera that
// looks at the central area (inverse stereographic projection), so the usual
// projection, shaders and draw code render them without tilt.
export const flatCentre = 2;
export const flatRing = .8;
const flatCam = basis(areas[flatCentre]);
const planeScale = (sx: number, sy: number) => (4 + sx * sx + sy * sy) / 4;
function unprojectPlane(sx: number, sy: number): Vec {
  const r2 = sx * sx + sy * sy, z = (4 - r2) / (4 + r2), k = 4 / (4 + r2);
  return norm(add(add(mul(flatCam.forward, z), mul(flatCam.right, sx * k)), mul(flatCam.up, sy * k)));
}
const ringAngles = (() => {
  const others = areas.map((v, i) => ({ i, angle: Math.atan2(dot(v, flatCam.up), dot(v, flatCam.right)) })).filter(o => o.i !== flatCentre).sort((a, b) => a.angle - b.angle);
  const angles: number[] = [];
  others.forEach((o, k) => { angles[o.i] = others[0].angle + k * 2 * Math.PI / others.length; });
  return angles;
})();
const flatArea = areas.map((_, i) => {
  const x = i === flatCentre ? 0 : flatRing * Math.cos(ringAngles[i]), y = i === flatCentre ? 0 : flatRing * Math.sin(ringAngles[i]);
  return { x, y, f: planeScale(x, y) };
});
export const areasFlat = flatArea.map(a => unprojectPlane(a.x, a.y));
// The light sits below the artwork's centre by the app's per-area offset (artwork upright).
export const lightsFlat = flatArea.map((a, i) => unprojectPlane(a.x, a.y - supernovaOffsets[i] * a.f));
export const projectsFlat = projects.map(pr => {
  const a = flatArea[pr.area], angle = pr.index / projectsPerArea * Math.PI * 2;
  const lightY = a.y - supernovaOffsets[pr.area] * a.f, cx = a.x + .18 * a.f * Math.cos(angle), cy = lightY + .18 * a.f * Math.sin(angle); // the ring is centred on the supernova light
  const f = planeScale(cx, cy);
  return { center: unprojectPlane(cx, cy), points: pr.unit.map(([x, y]) => unprojectPlane(cx + (x - .5) * .1 * f, cy + (.5 - y) * .1 * f)) };
});
const baseLayout = { flat: 0, artCentres: areas, lights: supernovaDirections, shaderPositions: supernovaDirections, shaderOffsets: supernovaOffsets.map(() => 0), projects: projects.map(p => ({ center: p.center, points: p.points })) };
export type SkyLayout = typeof baseLayout;
// t = 0 is the app's sphere, t = 1 the flat map; in between each point glides.
export function layoutAt(t: number): SkyLayout {
  if (t <= 0) return baseLayout;
  return {
    flat: t,
    artCentres: areas.map((v, i) => mix(v, areasFlat[i], t)),
    lights: supernovaDirections.map((v, i) => mix(v, lightsFlat[i], t)),
    shaderPositions: supernovaDirections.map((v, i) => mix(v, lightsFlat[i], t)),
    shaderOffsets: supernovaOffsets.map(() => 0),
    projects: projects.map((pr, k) => ({ center: mix(pr.center, projectsFlat[k].center, t), points: pr.points.map((v, j) => mix(v, projectsFlat[k].points[j], t)) })),
  };
}
// Zoom that fits the flat map: the ring plus its constellations (about 1.07 plane
// units out from the centre) must stay clear of the screen edge and, on wide
// screens, of the chapter text.
export function flatMapUnitPx(width: number, height: number) {
  const reach = flatRing + .27;
  if (width < 600) return Math.min((width / 2 - 12) / reach, .2 * height);
  const textRight = width * .07 + Math.min(600, width * .86 * .52);
  return Math.min((width * .25 - 12) / reach, (width * .75 - textRight - 30) / reach, .46 * height / reach);
}
export function wholeSkyBoost(stage: number, width: number, height: number) {
  const target = flatMapUnitPx(width, height) / height / .3;
  return 1 + (target - 1) * ease(stage - 2);
}
export const skyZoom = (stage: number, area: number, width: number, height: number) => cameraAt(stage, area).zoom * wholeSkyBoost(stage, width, height);
