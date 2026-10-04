import type { Copy } from './types';

export const en: Copy = {
  lang: 'en',
  title: 'Inner Stars – The app for remembering the moments you got through',
  description:
    'Inner Stars is a personal growth app: turn every effort into a star and draw your constellations in a sky that is entirely yours.',
  heroTitle: 'Every effort is a star.',
  heroLead: 'Inner Stars is the app for recording the moments you got through and building, star by star, the sky of your life.',
  ctaApk: 'Download the Android APK',
  ctaWeb: 'Open the web app',
  metaphor: {
    eyebrow: 'The sky',
    title: 'Your whole life, in a single sky',
    intro: 'The app reads at three sizes, from largest to smallest.',
    levels: [
      { name: 'Supernova', text: 'A life area. There are eight, fixed, and each holds the vision of the reality you want there.' },
      { name: 'Constellation', text: 'A project. A shape you draw yourself, orbiting a supernova, gathering everything you do toward the same goal.' },
      { name: 'Star', text: 'One effort, past, present or future. Intensity measures what it really cost you, not how big the result looks.' },
    ],
  },
  kinds: {
    title: 'Five kinds of star',
    intro: 'Each star tells a different moment of your effort.',
    items: [
      { name: 'Nascent', meaning: 'A slot still free in your constellation.', color: '#f4f1e8' },
      { name: 'Lit', meaning: 'A victory: an effort you already made.', color: '#f2b84b' },
      { name: 'Unlit', meaning: 'A goal: an effort waiting for you.', color: '#3b4f86' },
      { name: 'Pulsar', meaning: 'A habit: gold on days kept, blue when the rhythm breaks.', color: '#f2b84b' },
      { name: 'Dead', meaning: 'A deleted star: it keeps its place and remembers what it was.', color: '#232c44' },
    ],
  },
  how: {
    title: 'How it works',
    intro: 'Three gestures, and your sky starts to take shape.',
    steps: [
      { title: 'Draw a constellation', text: 'Pick a project and give it a shape: every point is a slot waiting to be filled.' },
      { title: 'Light the stars', text: 'Record an effort and choose what it cost you. A past victory shines right away; a goal waits for its light.' },
      { title: 'Watch your sky grow', text: 'On hard days, reread the road behind you: every star is proof you already did it, and more than once.' },
    ],
  },
  heroAlt: 'A house-shaped constellation with its lit stars',
  chapters: [
    { id: 'draw', title: 'Draw your constellations', text: 'Pick a shape from the library or draw your own, point by point. Every point is a star waiting to be lit.', shots: [{ name: 'new-constellation', caption: 'The form to create a constellation' }, { name: 'shapes-library', caption: 'The library of ready-made shapes' }, { name: 'draw-shape', caption: 'The editor to draw your own shape' }] },
    { id: 'light', title: 'Light a star', text: 'A victory you already earned, a habit to keep or a goal waiting for you: three kinds of star, one form.', shots: [{ name: 'star-form-victory', caption: 'Recording a victory' }, { name: 'star-form-habit', caption: 'Creating a habit' }, { name: 'star-form-goal', caption: 'Setting a goal' }, { name: 'stars-list', caption: 'The list of your stars' }] },
    { id: 'sky', title: 'Your sky at a glance', text: 'From the eight areas down to single stars: search, filter and reread what you did.', shots: [{ name: 'sky', caption: 'The eight life areas' }, { name: 'constellations', caption: 'All your constellations' }, { name: 'constellation', caption: 'One constellation' }, { name: 'star-reader', caption: 'Reading a star' }] },
    { id: 'areas', title: 'A vision for every area', text: 'Write where you want to get, collect images that inspire you and answer guided questions to find clarity.', shots: [{ name: 'area-detail', caption: 'An area’s vision' }, { name: 'moodboard', caption: 'The moodboard' }, { name: 'reflections-open', caption: 'Reflection questions' }] },
    { id: 'stats', title: 'Your numbers', text: 'Habit consistency, days kept and progress over time.', shots: [{ name: 'stats', caption: 'Habit statistics' }] },
  ],
  calmShots: [{ name: 'nightlight', caption: 'Nightlight asks how you are' }, { name: 'nightlight-explained', caption: 'Why you breathe first' }, { name: 'nightlight-inhale', caption: 'Breathe in' }, { name: 'nightlight-exhale', caption: 'Breathe out' }, { name: 'admire-choose', caption: 'Choose the areas to reread' }],
  features: {
    title: 'Everything you need',
    intro: 'A few tools, built to hold your journey together.',
    soon: 'Coming soon',
    items: [
      { title: 'A vision for every area', text: 'Write the reality you want to build in each life area, in a simple, polished text editor.' },
      { title: 'Moodboard', text: 'Collect images that inspire you and keep them close to your visions.' },
      { title: 'Habits as pulsars', text: 'A star that pulses day by day: gold when you keep the rhythm, blue when it breaks. And it can be reignited.' },
      { title: 'Statistics', text: 'See your numbers: how many efforts, in which areas, at what intensity over time.' },
      { title: 'PIN and fingerprint lock', text: 'Protect the app with a PIN and, if you like, your fingerprint.' },
      { title: 'Share a constellation', text: 'Create an image of your constellation to share with whoever you choose.' },
      { title: 'Shooting stars', text: 'A wish to chase before it burns out: small timed challenges.', soon: true },
      { title: 'Friends', text: 'Shared constellations and wins celebrated together.', soon: true },
    ],
  },
  calm: {
    eyebrow: 'Nightlight',
    title: 'When the mind plays everything down, start with the breath',
    paragraphs: [
      'When you are agitated or low, the mind tends to protect itself by rationalizing: it finds logical-sounding reasons to play down every victory, even the truest ones.',
      'Not because they don’t count, but because in that state it is almost impossible to look at them with clear eyes.',
    ],
    steps: [
      'It asks how you are, before showing you the sky.',
      'If it isn’t a good moment, you breathe together: in, out, at a guided pace.',
      'Then you return to your sky with a calmer body, and your stars count again.',
    ],
  },
  faq: {
    title: 'Frequently asked questions',
    items: [
      { q: 'What is Inner Stars?', a: 'A personal growth app for recording the moments you got through. Every effort becomes a star, projects become constellations and life areas are supernovas: together they form your sky.' },
      { q: 'Where can I use it?', a: 'On Android by downloading the APK, or straight from your browser with the web app, iPhone included.' },
      { q: 'Which languages are supported?', a: 'Italian, English and Romanian.' },
      { q: 'What is a pulsar?', a: 'The star of a habit: it pulses day by day, gold on the days you keep it and blue when the rhythm breaks.' },
      { q: 'What does a star’s intensity from 1 to 5 mean?', a: 'It measures what that effort really cost you, not how big the result looks.' },
      { q: 'What happens if I delete a star?', a: 'It doesn’t vanish: it becomes a dead star, keeps its place and remembers what it was, so it can be reignited.' },
    ],
  },
  areas: {
    title: 'Eight life areas',
    intro: 'From body to generosity: every area has its own universe.',
    names: ['Physical', 'Psychological', 'Professional', 'Financial', 'Personal', 'Social', 'Spiritual', 'Philanthropic'],
  },
  closing: {
    title: 'Start looking at your sky',
    text: 'Download the app or try it right now in your browser.',
  },
  footer: { tagline: 'Inner Stars – an app for remembering the moments you got through.', github: 'Code on GitHub' },
};
