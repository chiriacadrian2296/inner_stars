// Reproducible social previews for the story, using the real demonstration screens.
// Run from landing/: node scripts/make-story-og-images.mjs
import sharp from 'sharp';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const logo = readFileSync(resolve(root, 'public/logo-mark.svg'));
const labels = {
  it: { label: 'LA STORIA DEL PROGETTO', lines: ['Da un bisogno.', 'A un universo.'], method: 'Dall’idea al prodotto, con l’AI' },
  en: { label: 'THE PROJECT STORY', lines: ['From a need.', 'To a universe.'], method: 'From idea to product, with AI' },
};

for (const [lang, c] of Object.entries(labels)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
    <defs><radialGradient id="sky"><stop stop-color="#273556"/><stop offset="1" stop-color="#0d1220"/></radialGradient></defs>
    <rect width="1200" height="630" fill="#0d1220"/><circle cx="1000" cy="330" r="440" fill="url(#sky)"/>
    <circle cx="950" cy="320" r="240" fill="none" stroke="#f2b84b" stroke-opacity=".16"/>
    <path d="m755 520 60-370 270-50 50 390-380 30" fill="none" stroke="#f2b84b" stroke-opacity=".5" stroke-dasharray="2 9"/>
    <text x="112" y="86" font-family="Georgia,serif" font-size="29" fill="#f4f1e8">Inner Stars</text>
    <text x="64" y="180" font-family="Arial,sans-serif" letter-spacing="3" font-size="13" fill="#f2b84b">${c.label}</text>
    <text x="60" y="290" font-family="Georgia,serif" font-size="74" fill="#f4f1e8">${c.lines[0]}</text>
    <text x="60" y="382" font-family="Georgia,serif" font-style="italic" font-size="74" fill="#f2b84b">${c.lines[1]}</text>
    <text x="64" y="458" font-family="Arial,sans-serif" font-size="23" fill="#b8c1d2">${c.method}</text>
    <path d="M64 514h550" stroke="#ffffff" stroke-opacity=".18"/>
    <text x="64" y="558" font-family="Arial,sans-serif" font-size="18" fill="#b8c1d2">Adrian Chiriac</text>
    <text x="430" y="558" font-family="Arial,sans-serif" font-size="16" fill="#b8c1d2">innerstars.app</text>
  </svg>`;
  const screen = await sharp(resolve(root, `src/assets/current/${lang}-reader.png`)).resize(222).png().toBuffer();
  const mask = Buffer.from('<svg width="222" height="481"><rect width="222" height="481" rx="18" fill="white"/></svg>');
  const rounded = await sharp(screen).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();
  const frame = await sharp({ create: { width: 234, height: 493, channels: 4, background: '#30384b' } })
    .composite([{ input: rounded, left: 6, top: 6 }]).png().toBuffer();
  const device = await sharp(frame).rotate(8, { background: '#00000000' }).png().toBuffer();
  const mark = await sharp(logo).resize({ width: 26, height: 38, fit: 'inside' }).png().toBuffer();
  await sharp(Buffer.from(svg)).composite([
    { input: mark, left: 66, top: 58 },
    { input: device, left: 804, top: 48 },
  ]).png({ compressionLevel: 9 }).toFile(resolve(root, `public/og-story-${lang}.png`));
  console.log(`wrote og-story-${lang}.png`);
}
