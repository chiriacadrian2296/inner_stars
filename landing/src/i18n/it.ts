import type { Copy } from './types';

export const it: Copy = {
  lang: 'it',
  title: 'Inner Stars – L’app per ricordare i momenti che hai superato',
  description:
    'Inner Stars è un’app di crescita personale: trasforma ogni sforzo in una stella e disegna le tue costellazioni in un cielo che è solo tuo.',
  heroTitle: 'Ogni sforzo è una stella.',
  heroLead: 'Inner Stars è l’app per registrare i momenti che hai superato e costruire, stella dopo stella, il cielo della tua vita.',
  ctaApk: 'Scarica l’APK per Android',
  ctaWeb: 'Apri la web app',
  metaphor: {
    eyebrow: 'Il cielo',
    title: 'Tutta la tua vita, in un solo cielo',
    intro: 'L’app si legge a tre grandezze, dalla più grande alla più piccola.',
    levels: [
      { name: 'Supernova', text: 'Un’area di vita. Sono otto, fisse, e ognuna custodisce la visione della realtà che vuoi raggiungere.' },
      { name: 'Costellazione', text: 'Un progetto. Una forma che disegni tu, in orbita attorno a una supernova, e che raccoglie tutto ciò che fai per quello stesso obiettivo.' },
      { name: 'Stella', text: 'Un singolo sforzo, passato, presente o futuro. L’intensità misura quanto ti è costato davvero, non quanto sembra grande il risultato.' },
    ],
  },
  kinds: {
    title: 'Cinque tipi di stella',
    intro: 'Ogni stella racconta un tempo diverso del tuo impegno.',
    items: [
      { name: 'Nascente', meaning: 'Uno spazio ancora libero nella tua costellazione.', color: '#f4f1e8' },
      { name: 'Accesa', meaning: 'Una vittoria: uno sforzo che hai già compiuto.', color: '#f2b84b' },
      { name: 'Spenta', meaning: 'Un obiettivo: uno sforzo che ti aspetta.', color: '#3b4f86' },
      { name: 'Pulsar', meaning: 'Un’abitudine: dorata nei giorni mantenuti, blu quando il ritmo si spezza.', color: '#f2b84b' },
      { name: 'Morta', meaning: 'Una stella eliminata: resta al suo posto e ricorda ciò che era.', color: '#232c44' },
    ],
  },
  how: {
    title: 'Come funziona',
    intro: 'Tre gesti, e il tuo cielo comincia a prendere forma.',
    steps: [
      { title: 'Disegna una costellazione', text: 'Scegli un progetto e dagli una forma: ogni punto è uno spazio ancora vuoto, pronto a riempirsi.' },
      { title: 'Accendi le stelle', text: 'Registra uno sforzo e scegli quanto ti è costato. Una vittoria passata brilla subito; un obiettivo aspetta la sua luce.' },
      { title: 'Guarda il cielo crescere', text: 'Nei giorni difficili, rileggi la strada fatta: ogni stella è la prova che ce l’hai già fatta, e più di una volta.' },
    ],
  },
  heroAlt: 'Una costellazione a forma di casa con le sue stelle accese',
  chapters: [
    { id: 'draw', title: 'Disegna le tue costellazioni', text: 'Scegli una forma dalla libreria o disegnala tu, punto per punto. Ogni punto è una stella ancora da accendere.', shots: [{ name: 'new-constellation', caption: 'Il modulo per creare una costellazione' }, { name: 'shapes-library', caption: 'La libreria di forme pronte' }, { name: 'draw-shape', caption: 'L’editor per disegnare la tua forma' }] },
    { id: 'light', title: 'Accendi una stella', text: 'Una vittoria che hai già ottenuto, un’abitudine da mantenere o un obiettivo che ti aspetta: tre tipi di stella, un solo modulo.', shots: [{ name: 'star-form-victory', caption: 'Registrare una vittoria' }, { name: 'star-form-habit', caption: 'Creare un’abitudine' }, { name: 'star-form-goal', caption: 'Fissare un obiettivo' }, { name: 'stars-list', caption: 'L’elenco delle tue stelle' }] },
    { id: 'sky', title: 'Il tuo cielo, a colpo d’occhio', text: 'Dalle otto aree alle singole stelle: cerca, filtra e rileggi quello che hai fatto.', shots: [{ name: 'sky', caption: 'Le otto aree di vita' }, { name: 'constellations', caption: 'Tutte le costellazioni' }, { name: 'constellation', caption: 'Una costellazione' }, { name: 'star-reader', caption: 'Il lettore di una stella' }] },
    { id: 'areas', title: 'Una visione per ogni area', text: 'Scrivi dove vuoi arrivare, raccogli immagini che ti ispirano e rispondi a domande guidate per fare chiarezza.', shots: [{ name: 'area-detail', caption: 'La visione di un’area' }, { name: 'moodboard', caption: 'La moodboard' }, { name: 'reflections-open', caption: 'Le domande di riflessione' }] },
    { id: 'stats', title: 'I tuoi numeri', text: 'Costanza delle abitudini, giorni mantenuti e andamento nel tempo.', shots: [{ name: 'stats', caption: 'Le statistiche delle abitudini' }] },
  ],
  calmShots: [{ name: 'nightlight', caption: 'Nightlight chiede come stai' }, { name: 'nightlight-explained', caption: 'Perché si respira per prima cosa' }, { name: 'nightlight-inhale', caption: 'Inspira' }, { name: 'nightlight-exhale', caption: 'Espira' }, { name: 'admire-choose', caption: 'Scegli le aree da rileggere' }],
  features: {
    title: 'Tutto quello che ti serve',
    intro: 'Pochi strumenti, pensati per tenere insieme il tuo percorso.',
    soon: 'In arrivo',
    items: [
      { title: 'Una visione per ogni area', text: 'Scrivi la realtà che vuoi costruire in ogni area della vita, con un editor di testo semplice e curato.' },
      { title: 'Moodboard', text: 'Raccogli immagini che ti ispirano e tienile a portata di mano insieme alle tue visioni.' },
      { title: 'Abitudini come pulsar', text: 'Una stella che pulsa giorno dopo giorno: dorata quando mantieni il ritmo, blu quando si spezza. E si può riaccendere.' },
      { title: 'Statistiche', text: 'Guarda i tuoi numeri: quanti sforzi, in quali aree, con che intensità nel tempo.' },
      { title: 'Blocco con PIN e impronta', text: 'Proteggi l’app con un PIN e, se vuoi, con l’impronta digitale.' },
      { title: 'Condividi una costellazione', text: 'Crea un’immagine della tua costellazione da condividere con chi vuoi.' },
      { title: 'Stelle cadenti', text: 'Un desiderio da inseguire prima che si spenga: piccole sfide a tempo.', soon: true },
      { title: 'Amici', text: 'Costellazioni condivise e vittorie festeggiate insieme.', soon: true },
    ],
  },
  calm: {
    eyebrow: 'Nightlight',
    title: 'Quando la mente sminuisce tutto, si comincia dal respiro',
    paragraphs: [
      'Quando sei agitato o giù di morale, la mente tende a proteggersi razionalizzando: trova ragioni che sembrano logiche per sminuire ogni vittoria, anche la più vera.',
      'Non perché non contino, ma perché in quello stato è quasi impossibile guardarle con occhi limpidi.',
    ],
    steps: [
      'Ti chiede come stai, prima di mostrarti il cielo.',
      'Se non è un buon momento, respirate insieme: inspira, espira, a ritmo guidato.',
      'Dopo, rientri nel tuo cielo con il corpo più calmo, e le tue stelle tornano a contare.',
    ],
  },
  faq: {
    title: 'Domande frequenti',
    items: [
      { q: 'Cos’è Inner Stars?', a: 'Un’app di crescita personale per registrare i momenti che hai superato. Ogni sforzo diventa una stella, i progetti diventano costellazioni e le aree di vita sono supernove: tutto insieme forma il tuo cielo.' },
      { q: 'Dove posso usarla?', a: 'Su Android scaricando l’APK, oppure direttamente dal browser con la web app, anche da iPhone.' },
      { q: 'In che lingue è disponibile?', a: 'Italiano, inglese e rumeno.' },
      { q: 'Cos’è una pulsar?', a: 'È la stella di un’abitudine: pulsa giorno dopo giorno, dorata nei giorni in cui la mantieni e blu quando il ritmo si interrompe.' },
      { q: 'Cosa significa che l’intensità di una stella va da 1 a 5?', a: 'Misura quanto ti è costato davvero quello sforzo, non quanto sembra grande il risultato.' },
      { q: 'Cosa succede se elimino una stella?', a: 'Non sparisce: diventa una stella morta, resta al suo posto e ricorda ciò che era, così può riaccendersi.' },
    ],
  },
  areas: {
    title: 'Otto aree di vita',
    intro: 'Dal corpo alla generosità: ogni area ha il suo universo.',
    names: ['Fisica', 'Psicologica', 'Professionale', 'Finanziaria', 'Personale', 'Sociale', 'Spirituale', 'Filantropica'],
  },
  closing: {
    title: 'Comincia a guardare il tuo cielo',
    text: 'Scarica l’app o provala subito dal browser.',
  },
  footer: { tagline: 'Inner Stars – un’app per ricordare i momenti che hai superato.', github: 'Codice su GitHub' },
};
