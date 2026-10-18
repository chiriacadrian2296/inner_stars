import type { Lang, SiteLang } from './types';
export type Topic = 'levels' | 'navigation' | 'customization';
export const topicSlugs: Record<Lang, Record<Topic, string>> = {
  it: { levels: 'scopri/livelli/', navigation: 'scopri/navigazione/', customization: 'scopri/personalizzazione/' },
  en: { levels: 'en/explore/levels/', navigation: 'en/explore/navigation/', customization: 'en/explore/customization/' },
};
export const topicTitles = {
  it: { levels: 'Aree, progetti e attività', navigation: 'Navigare tra Galaxy e Sky', customization: 'Un cielo che ti somiglia' },
  en: { levels: 'Areas, projects and activities', navigation: 'Finding your way in Galaxy and Sky', customization: 'A sky that feels like you' },
};
export const overviewSlugs: Record<Lang, string> = { it: 'scopri/', en: 'en/explore/' };
export const homeSlugs: Record<SiteLang, string> = { it: '', en: 'en/', ro: 'ro/' };
export function pagePath(base: string, lang: SiteLang, topic?: Topic | 'overview') {
  const guide: Lang = lang === 'ro' ? 'en' : lang;
  return `${base}${topic === 'overview' ? overviewSlugs[guide] : topic ? topicSlugs[guide][topic] : homeSlugs[lang]}`;
}
