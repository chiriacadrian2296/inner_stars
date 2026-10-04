export type Lang = 'it' | 'en';

export interface Copy {
  lang: Lang;
  title: string;
  description: string;
  heroTitle: string;
  heroLead: string;
  ctaApk: string;
  ctaWeb: string;
  metaphor: { eyebrow: string; title: string; intro: string; levels: { name: string; text: string }[] };
  kinds: { title: string; intro: string; items: { name: string; meaning: string; color: string }[] };
  how: { title: string; intro: string; steps: { title: string; text: string }[] };
  heroAlt: string;
  chapters: { id: string; title: string; text: string; shots: { name: string; caption: string }[] }[];
  calmShots: { name: string; caption: string }[];
  features: { title: string; intro: string; soon: string; items: { title: string; text: string; soon?: boolean }[] };
  calm: { eyebrow: string; title: string; paragraphs: string[]; steps: string[] };
  faq: { title: string; items: { q: string; a: string }[] };
  areas: { title: string; intro: string; names: string[] };
  closing: { title: string; text: string };
  footer: { tagline: string; github: string };
}

export const AREA_KEYS = [
  'physical', 'psychological', 'professional', 'financial',
  'personal', 'social', 'spiritual', 'philanthropic',
] as const;
