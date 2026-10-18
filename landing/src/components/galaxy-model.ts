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
export const journeyStage = (step: number) => step < 1 ? -1 + .2 * ease(step) : step < 1.9 ? -.8 + .8 * ease((step - 1) / .9) : step < 2.3 ? 0 : step < 3 ? (step - 2.3) / .7 : Math.min(3, step - 2);
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
  const center = offset(area, .18, i / 6 * Math.PI * 2);
  const { right, up } = basis(center);
  const shape = areaIndex===2&&i===0 ? {points:house,edges} : presets[areaShapes[areaIndex][i]];
  const points = shape.points.map(([x, y]) => norm(add(center, add(mul(right, (x - .5) * .1), mul(up, (.5 - y) * .1)))));
  return { area: areaIndex, index: i, center, points, edges: shape.edges, completed:i===0||i===2, shape:areaShapes[areaIndex][i] };
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
