import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import test from 'node:test';

const dist = fileURLToPath(new URL('../dist/', import.meta.url));
const rootDeployment = Boolean(process.env.CF_PAGES);
const base = rootDeployment ? '/' : '/inner_stars/';
const origin = rootDeployment ? 'https://innerstars.app' : 'https://chiriacadrian2296.github.io';
const stories = [['storia', 'it'], ['en/story', 'en'], ['ro/poveste', 'ro']];
const html = path => readFileSync(resolve(dist, path, 'index.html'), 'utf8');

test('all three stories are independent, indexable pages with reciprocal metadata', () => {
  const sitemap = readFileSync(resolve(dist, 'sitemap-0.xml'), 'utf8');
  for (const [path, lang] of stories) {
    const page = html(path);
    const url = `${origin}${base}${path}/`;
    assert.ok(page.includes(`<html lang="${lang}">`));
    assert.ok(page.includes(`<link rel="canonical" href="${url}">`));
    assert.ok(page.includes(`<meta property="og:url" content="${url}">`));
    assert.ok(page.includes('<meta property="og:type" content="article">'));
    assert.ok(!page.includes('noindex'));
    assert.ok(!page.includes('SoftwareApplication') && !page.includes('FAQPage'));
    for (const [alternate, locale] of stories) {
      assert.ok(page.includes(`hreflang="${locale}" href="${origin}${base}${alternate}/"`));
      assert.ok(page.includes(`href="${base}${alternate}/" lang="${locale}"`));
    }
    assert.ok(sitemap.includes(`${url}</loc>`));
    const image = `${origin}${base}og-story-${lang}.png?v=1`;
    assert.ok(page.includes(`<meta property="og:image" content="${image}">`));
    assert.ok(page.includes(`<meta name="twitter:image" content="${image}">`));
    const png = readFileSync(resolve(dist, `og-story-${lang}.png`));
    assert.equal(png.readUInt32BE(16), 1200);
    assert.equal(png.readUInt32BE(20), 630);
  }
});

test('the header promotes the matching story without repeating it in the footer or download section', () => {
  for (const [path, story, label] of [
    ['', 'storia/', 'La storia del progetto'],
    ['en', 'en/story/', 'The project story'],
    ['ro', 'ro/poveste/', 'Povestea proiectului'],
  ]) {
    const home = html(path);
    const header = home.match(/<header\b[^>]*>[\s\S]*?<\/header>/)[0];
    const footer = home.match(/<footer\b[^>]*>[\s\S]*?<\/footer>/)[0];
    assert.ok(header.includes(`href="${base}${story}"`));
    assert.ok(header.includes(label));
    assert.ok(!footer.includes(`href="${base}${story}"`));
    assert.equal(home.split(`href="${base}${story}"`).length - 1, 1);
  }
  assert.ok(html('en').includes('>The Story</a>'));
  assert.ok(html('ro').includes(`href="${base}ro/poveste/" hreflang="ro"`));
});

test('the header Try action offers the home download choice in every language, including from the story', () => {
  for (const [path, target] of [['', '#download'], ['en', '#download'], ['ro', '#download'], ['storia', `${base}#download`], ['en/story', `${base}en/#download`], ['ro/poveste', `${base}ro/#download`]]) {
    const page = html(path);
    const header = page.match(/<header\b[^>]*>[\s\S]*?<\/header>/)[0];
    assert.ok(header.includes(`class="nav-try" href="${target}"`), path);
    assert.ok(!header.includes('href="https://my.innerstars.app/"'), path);
  }
  for (const path of ['', 'en', 'ro']) {
    const page = html(path);
    const downloads = page.match(/<div class="download-actions">[\s\S]*?<\/div>/)[0];
    assert.ok(downloads.includes('inner-stars.apk'));
    assert.ok(downloads.includes('href="https://my.innerstars.app/"'));
  }
});

test('the story, dated evidence and division of work are readable without JavaScript', () => {
  for (const [path] of stories) {
    const page = html(path);
    assert.equal((page.match(/<h1\b/g) || []).length, 1);
    for (const id of ['storia', 'story-title', 'percorso', 'timeline-title', 'scelte', 'chapter-one', 'chapter-two', 'chapter-three', 'metodo', 'method-title', 'story-closing-title']) {
      assert.ok(page.includes(`id="${id}"`), `${path}: ${id}`);
    }
    for (const date of ['2026-08-26', '2026-08-31', '2026-09-12', '2026-10-04', '2026-10-24']) {
      assert.ok(page.includes(`<time datetime="${date}">`));
    }
    assert.ok(page.includes('Adrian Chiriac'));
    assert.ok(page.includes('Nightlight') && page.includes('Galaxy') && page.includes('Sky'));
    assert.ok(page.includes('https://my.innerstars.app/'));
    assert.ok(!page.includes('<canvas') && !page.includes('<astro-island'));
  }
  assert.ok(html('storia').includes('Implementazione del codice e verifiche tecniche.'));
  assert.ok(html('en/story').includes('Code implementation and technical checks.'));
  assert.ok(html('ro/poveste').includes('Implementarea codului și verificările tehnice.'));
  assert.ok(html('storia').includes('preparazione della versione successiva'));
  assert.ok(html('en/story').includes('preparation for the next version'));
  assert.ok(html('ro/poveste').includes('pregătirea versiunii următoare'));
});

test('every home chapter after the opening offers a distinct return to the beginning', () => {
  for (const path of ['', 'en', 'ro']) {
    const page = html(path);
    assert.equal((page.match(/class="nav-top" href="#hero"/g) || []).length, 6, path);
    const hero = page.match(/<section class="chapter chapter-hero"[\s\S]*?<\/section>/)[0];
    assert.ok(!hero.includes('nav-top'), path);
  }
});

test('the narrow footer layout can pair the tagline with legal links below GitHub', () => {
  for (const path of ['', 'en', 'ro']) {
    const footer = html(path).match(/<footer class="journey-footer home-footer">[\s\S]*?<\/footer>/)[0];
    assert.ok(footer.includes('class="footer-copy"'));
    assert.ok(footer.includes('class="footer-github"'));
    assert.ok(footer.includes('class="legal-links"'));
  }
});

test('movement starts from a static poster and needs an explicit play action', () => {
  for (const [path] of stories) {
    const page = html(path);
    assert.ok(page.includes(`data-poster="${base}clips/fly-poster.webp"`));
    assert.ok(page.includes(`data-animation="${base}clips/fly.webp"`));
    assert.ok(page.includes(`src="${base}clips/fly-poster.webp"`));
    assert.ok(!page.includes(`src="${base}clips/fly.webp"`));
    assert.ok(page.includes('hidden aria-pressed="false"'));
    assert.ok(!page.includes('autoplay'));
  }
});

test('story assets, local destinations and section links resolve under either deployment base', () => {
  for (const [path] of stories) {
    const page = html(path);
    for (const [, value] of page.matchAll(/\b(?:href|src|data-poster|data-animation)="([^"]+)"/g)) {
      if (value.startsWith('#')) {
        assert.ok(page.includes(`id="${value.slice(1)}"`), `${path}: ${value}`);
      } else if (value.startsWith('/')) {
        assert.ok(value.startsWith(base), value);
        const parsed = new URL(value, origin);
        const local = decodeURIComponent(parsed.pathname.slice(base.length));
        readFileSync(resolve(dist, local, parsed.pathname.endsWith('/') ? 'index.html' : ''));
      }
    }
    for (const image of page.matchAll(/<img\b[^>]*>/g)) {
      assert.ok(/\balt="[^"]*"/.test(image[0]), image[0]);
    }
  }
});
