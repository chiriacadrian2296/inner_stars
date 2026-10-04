import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';

// No custom domain yet: the landing lives at the root of the repo's GitHub
// Pages site and the Flutter web app under /app/ (see deploy-web.yml). With a
// domain, change `site`, drop `base`, and add a CNAME.
export default defineConfig({
  site: 'https://chiriacadrian2296.github.io',
  base: '/inner_stars',
  trailingSlash: 'always',
  integrations: [
    react(),
    sitemap({
      i18n: { defaultLocale: 'it', locales: { it: 'it-IT', en: 'en-US' } },
    }),
  ],
});
