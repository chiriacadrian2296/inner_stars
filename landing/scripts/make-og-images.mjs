// Builds the social preview images (1200x630) shown when a link to the site
// is pasted in a chat. One per language: public/og-image.png (it),
// og-image-en.png, og-image-ro.png. Run: node scripts/make-og-images.mjs
import sharp from 'sharp';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const mark = readFileSync(resolve(root, 'public/logo-mark.svg'), 'utf8')
  .replace(/<svg[^>]*>/, '')
  .replace('</svg>', '');

const W = 1200;
const H = 630;
const GOLD = '#F2B84B';

const lines = {
  it: ['C’è un cielo,', 'dentro di te.'],
  en: ['There’s a sky', 'within you.'],
  ro: ['Există un cer', 'în tine.'],
};
const files = { it: 'og-image.png', en: 'og-image-en.png', ro: 'og-image-ro.png' };

// Small deterministic generator, so the picture is the same on every run.
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

function dust() {
  let out = '';
  for (let i = 0; i < 150; i++) {
    const x = rnd() * W;
    const y = rnd() * H;
    const r = 0.5 + rnd() * 1.4;
    const o = 0.15 + rnd() * 0.5;
    out += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(2)}" fill="#cfd8ff" opacity="${o.toFixed(2)}"/>`;
  }
  return out;
}

// Constellation on the right: points wired by edges, a glowing gold star on each.
const pts = [
  [760, 470], [850, 365], [960, 330], [1060, 235], [1000, 130], [900, 175], [880, 270],
];
const edges = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 1], [2, 6]];

function star(x, y, s) {
  const k = s * 0.22;
  return `<path d="M${x} ${y - s} Q${x + k} ${y - k} ${x + s} ${y} Q${x + k} ${y + k} ${x} ${y + s} Q${x - k} ${y + k} ${x - s} ${y} Q${x - k} ${y - k} ${x} ${y - s}Z" fill="${GOLD}"/>`;
}

function constellation() {
  const e = edges
    .map(([a, b]) => `<line x1="${pts[a][0]}" y1="${pts[a][1]}" x2="${pts[b][0]}" y2="${pts[b][1]}" stroke="${GOLD}" stroke-opacity="0.55" stroke-width="2"/>`)
    .join('');
  const glow = pts.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="46" fill="url(#glow)"/>`).join('');
  const sizes = [20, 26, 22, 30, 22, 24, 20];
  const stars = pts.map(([x, y], i) => star(x, y, sizes[i])).join('');
  return e + glow + stars;
}

function svg(lang) {
  const [a, b] = lines[lang];
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <radialGradient id="bg" cx="78%" cy="35%" r="85%">
      <stop offset="0" stop-color="#1c2a55"/><stop offset="0.55" stop-color="#101a36"/><stop offset="1" stop-color="#0a101e"/>
    </radialGradient>
    <radialGradient id="glow"><stop offset="0" stop-color="${GOLD}" stop-opacity="0.38"/><stop offset="1" stop-color="${GOLD}" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  ${dust()}
  ${constellation()}
  <g transform="translate(80 70) scale(0.0975)"><svg viewBox="282 186 463 660" width="463" height="660" x="0" y="0" overflow="visible">${mark}</svg></g>
  <text x="150" y="105" font-family="Georgia, 'Times New Roman', serif" font-size="34" fill="#f3efe4">Inner Stars</text>
  <text x="80" y="330" font-family="Georgia, 'Times New Roman', serif" font-size="92" fill="#f3efe4">${a}</text>
  <text x="80" y="438" font-family="Georgia, 'Times New Roman', serif" font-size="92" font-style="italic" fill="${GOLD}">${b}</text>
  <text x="80" y="548" font-family="Arial, Helvetica, sans-serif" font-size="30" fill="#9fb0d6" letter-spacing="1">innerstars.app</text>
</svg>`;
}

for (const lang of Object.keys(lines)) {
  await sharp(Buffer.from(svg(lang))).png({ compressionLevel: 9 }).toFile(resolve(root, 'public', files[lang]));
  console.log('wrote', files[lang]);
}
