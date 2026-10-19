import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import test from 'node:test';

const dist = fileURLToPath(new URL('../dist/', import.meta.url));
const html = path => readFileSync(resolve(dist, path, 'index.html'), 'utf8');
const origin = 'https://chiriacadrian2296.github.io/inner_stars/';
// Public pages: the three home languages, plus the unlisted classic pair.
const homes = [['', 'it'], ['en', 'en'], ['ro', 'ro']];
const routes = [...homes, ['classic', 'it'], ['classic/en', 'en']];
const publicRoutes = homes;
const classicPair = ['classic', 'classic/en'];

test('every home has its own canonical and reciprocal language links', () => {
  for (const [path, lang] of homes) {
    const page = html(path);
    const url = `${origin}${path ? `${path}/` : ''}`;
    assert.ok(page.includes(`<html lang="${lang}">`), path);
    assert.ok(page.includes(`<link rel="canonical" href="${url}">`), path);
    assert.ok(page.includes(`<meta property="og:url" content="${url}">`), path);
    for (const [alt, locale] of homes) assert.ok(page.includes(`hreflang="${locale}" href="${origin}${alt ? `${alt}/` : ''}"`), path);
  }
  for (const [i, path] of classicPair.entries()) {
    const page = html(path);
    assert.ok(page.includes(`<html lang="${['it', 'en'][i]}">`), path);
    assert.ok(!page.includes('hreflang="ro"'), path);
  }
});

test('classic pages stay accessible but are not advertised or indexed', () => {
  const sitemap = readFileSync(resolve(dist, 'sitemap-0.xml'), 'utf8');
  assert.ok(!sitemap.includes('/classic/'));
  for (const path of ['classic', 'classic/en']) {
    assert.ok(html(path).includes('<meta name="robots" content="noindex, follow">'));
    assert.ok(html(path).includes('class="hero"'));
    assert.ok(html(path).includes('class="gallery"'));
    assert.ok(html(path).includes('href="/inner_stars/classic/"'));
    assert.ok(html(path).includes('href="/inner_stars/classic/en/"'));
  }
  for (const [path] of publicRoutes) {
    assert.ok(!html(path).includes('noindex'));
    assert.ok(!html(path).includes('/classic/'));
    assert.ok(sitemap.includes(`${origin}${path ? `${path}/` : ''}</loc>`));
  }
});

test('the journey and download links are present before JavaScript runs', () => {
  for (const [path] of homes) {
    const page = html(path);
    for (const id of ['hero-title', 'day-title', 'star-title', 'distant-title', 'reveal-title', 'universe-title', 'closing-title']) {
      assert.ok(page.includes(`id="${id}"`), `${path}: ${id}`);
    }
    assert.ok(page.includes('class="galaxy-fallback"'));
    assert.ok(!page.includes('<textarea'));
    assert.ok(!page.includes('class="hero-actions"'));
    assert.ok(!page.includes('memory-form'));
    assert.ok(page.includes('https://github.com/chiriacadrian2296/inner_stars/releases/latest/download/inner-stars.apk'));
    assert.ok(page.includes('https://my.innerstars.app/'));
    assert.ok(!page.includes('id="product-title"') && !page.includes('id="faq-title"') && !page.includes('FAQPage'), path);
  }
});

test('the discover pages are hidden for now: only the home pages are built', () => {
  for (const path of ['scopri', 'scopri/livelli', 'en/explore', 'en/explore/levels']) assert.ok(!existsSync(resolve(dist, path, 'index.html')), path);
  for (const [path] of homes) {
    const page = html(path);
    assert.ok(!page.includes('class="discover-menu"') && !page.includes('/scopri/') && !page.includes('/explore/'), path);
    assert.ok(page.includes('hreflang="ro"'), path);
  }
});

test('Romanian home keeps the journey and download links', () => {
  const page = html('ro');
  assert.ok(page.includes('Există un cer în tine'));
  assert.ok(page.includes('Totul reîncepe'));
  assert.ok(page.includes('Descarcă pentru Android'));
});

test('every local asset, page link and fragment resolves under the deployment base', () => {
  for (const [path] of routes) {
    const page = html(path);
    for (const [, attr, value] of page.matchAll(/\b(href|src)="([^"]+)"/g)) {
      if (value.startsWith('#')) {
        assert.ok(page.includes(`id="${value.slice(1)}"`), `${path}: ${value}`);
      } else if (value.startsWith('/')) {
        assert.ok(value.startsWith('/inner_stars/'), value);
        const url = new URL(value,origin);
        const file = decodeURIComponent(url.pathname.slice('/inner_stars/'.length));
        assert.ok(existsSync(resolve(dist, file, file.endsWith('/') ? 'index.html' : '')), `${path} ${attr}: ${value}`);
        if(url.hash)assert.ok(html(file).includes(`id="${url.hash.slice(1)}"`),`${path}: ${value}`);
      }
    }
  }
});

test('the paused Galaxy / Sky experiment is not mounted on any public page',()=>{
  for(const [path] of publicRoutes){
    const page=html(path);
    assert.ok(!page.includes('class="comparison"'),path);
    assert.ok(!page.includes('component-export="GalaxyExplorer"'),path);
  }
});
