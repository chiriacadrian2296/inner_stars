# Inner Stars landing

Astro serves the Italian journey at `/inner_stars/`, English at
`/inner_stars/en/` and Romanian at `/inner_stars/ro/`. The overview and guide pages
(`scopri/`, `en/explore/`) are hidden for now by `showDiscoverPages` in
`src/features.ts`; only the home pages are built. The Flutter app remains under `/inner_stars/app/`.

The previous landing is preserved at `/inner_stars/classic/` and
`/inner_stars/classic/en/`. Both pages use `noindex`, are excluded from the
sitemap and are not linked from the journey. This is discoverability control,
not access control: anyone with the address can open them.

## Local preview and checks

```sh
npm ci
npm run dev -- --host 127.0.0.1
npm run typecheck
npm run build
npm test
```

Tests inspect the generated `dist` directory, so build before running them.
`npm run preview -- --host 127.0.0.1` serves the production build locally.
Neither command publishes the site.

## Galaxy, current screenshots and branding

`journey-nebula.ts` imports the actual `nebula_particles.glsl`,
`sky_supernova.frag` and `constellation_flare.frag` sources into WebGL2. Only the Flutter coordinate entry
point and GLSL version are adapted; the app's shader files are not changed.
`galaxy-model.ts` shares the app's spherical area placement, project rings,
projection and 95/75/35 percent camera zoom levels. The home journey opens in
an empty, dim patch of sky, flies toward the remembered light, then widens from
its project and area to the whole sky. The interactive
Galaxy/Sky comparison is currently hidden sitewide by `src/features.ts`, without
mounting its canvas. It uses the same two projects and activities as the captures;
the narrative sky has additional illustrative constellations. Artwork follows
the app's local tangent rotation; each light and its label share the original
per-area artwork offsets. Lit, unlit and nascent stars use the production flare
shader, including intensity satellites. Lines and the Dijkstra energy wave are
composited behind those stars. Only completed shapes carry a wave, matching the
app. Six projects per area use varied original presets (`sync_landing_shapes.mjs`).
Bounded shader passes limit GPU work.
The persistent navigation uses a white wordmark and gold mark; the download section is
a compact, quiet ending without another Galaxy scene.

Rendering stops when hidden; reduced motion and unavailable WebGL2 use a static
scene. Without hydration the narrative and SVG sky remain available. There is
no personal-memory form, storage or outbound submission.

The public feature pages live under `scopri/` in Italian and `en/explore/` in
English. They cover levels, navigation and customization, with reciprocal
language links. Only home pages emit FAQ structured data.

Regenerate current production UI screenshots, with isolated mocked data:

```sh
flutter test tool/capture_landing_test.dart
```

Run the command from the repository root. Material icons and the real fonts
are loaded; legacy screenshots stay in `shots/` for the classic landing only.
After refreshing captures, stop Astro and remove `node_modules/.astro/assets`
before restarting it to discard its optimized-image cache.

Brand assets derive from the existing `assets/icon/Logo.svg` S mark:

```sh
node tool/generate_brand_assets.mjs
dart run flutter_launcher_icons
```

The entire S mark is gold, with a white “Inner Stars” wordmark. The original
vector path remains intact.

The navigation guide includes three locally hosted animated WebP clips (manual
play/stop, still posters without JavaScript, no automatic movement). They are
deterministic captures of the real Flutter Galaxy renderers with example data,
not recordings of a personal session or of the landing's WebGL approximation.
Regenerate from the repository root:

```sh
flutter test tool/capture_galaxy_clips_test.dart --no-pub
python tool/encode_galaxy_clips.py
node tool/sync_landing_shapes.mjs
```

The encoder needs Pillow; temporary PNG frames stay in ignored `landing/.capture/`.

These root-level commands update landing SVG/PNG icons, social artwork, launcher
source images, Android/iOS icons and Flutter web icons. The original vector is
preserved. App icons become visible after rebuilding and installing the app.

## Visual regression checklist

- Italian and English, desktop, narrow portrait and landscape; no horizontal
  overflow or clipped controls.
- Scroll through the reveal in both directions; use navigation and skip links
  with a keyboard.
- If the comparison experiment is enabled, switch all four perspectives and all eight areas; Sky's image and the
  accessible status must follow the selected perspective. Visit all feature
  pages and their corresponding language links. Try both library shapes.
- With scripts blocked, narrative, screenshots, FAQs and download links remain
  available. With JavaScript disabled in browser settings, the `noscript`
  explanation also appears.
- Simulate unavailable WebGL2 and reduced motion: sky stays static, while the
  perspective controls still work. Suspend the tab and return without jumps.
- Check classic routes, their reciprocal language links and `noindex` metadata.
