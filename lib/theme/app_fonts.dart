/// The app's four typefaces, one per job — nothing else in the app should
/// name a font family string directly, so a family can be swapped here
/// without hunting every call site.
///
/// - [kFontBranding] (Gloock) — the app's own name, wherever it's shown as
///   a wordmark rather than as running text (onboarding, the sky drawer's
///   header). Never body copy — it's a display face, not a reading one.
/// - [kFontStarTitle] (Newsreader, upright and italic) — a star's own title
///   and vision text. Star titles use italic, the one piece of text
///   that's the user's own words about their own effort. The italic slant
///   is what marks it as *theirs* rather than the app's interface chrome.
/// - [kFontBody] (Instrument Sans) — everything else: labels, buttons,
///   descriptions, field text. Set as [ThemeData]'s own default in
///   `app_theme.dart`, so most widgets never need to name it at all.
/// - [kFontMono] (Fragment Mono) — dates, times, and standalone numbers
///   (stat values, counts) — anything meant to be scanned as data rather
///   than read as a sentence.
const String kFontBranding = 'Gloock';
const String kFontStarTitle = 'Newsreader';
const String kFontBody = 'Instrument Sans';
const String kFontMono = 'Fragment Mono';
