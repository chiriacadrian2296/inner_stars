import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';

// Two deployments: Cloudflare Pages (CF_PAGES is set there) serves the landing
// at the root of innerstars.app; the GitHub Pages workflow keeps the repo
// subpath until it is retired.
const onCloudflare = Boolean(process.env.CF_PAGES);

export default defineConfig({
  site: onCloudflare ? "https://innerstars.app" : "https://chiriacadrian2296.github.io",
  ...(onCloudflare ? {} : { base: "/inner_stars" }),
  trailingSlash: 'always',
  devToolbar: { enabled: false },
  integrations: [
    react(),
    sitemap({
      filter: (page) => !new URL(page).pathname.split('/').includes('classic'),
      i18n: { defaultLocale: 'it', locales: { it: 'it-IT', en: 'en-US', ro: 'ro-RO' } },
    }),
  ],
});
