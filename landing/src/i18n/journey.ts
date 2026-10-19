import type { SiteLang } from './types';

export interface JourneyCopy {
  lang: SiteLang;
  title: string;
  description: string;
  nav: { journey: string; app: string; try: string; language: string; skip: string };
  eyebrow: string;
  hero: { before: string; accent: string; after: string; text: string; scroll: string };
  day: { before: string; accent: string; after: string; text: string };
  star: { before: string; accent: string; text: string };
  distant: { before: string; accent: string; text: string; examples: string[]; caption: string };
  reveal: { before: string; accent: string; text: string; caption: string };
  product: { eyebrow: string; title: string; text: string; items: { title: string; text: string; caption: string }[] };
  faq: { title: string; items: { q: string; a: string }[] };
  closing: { eyebrow: string; title: string; text: string; apk: string; web: string; platforms: string };
  footer: string;
  ui: { prev: string; mainNav: string; try: string; discover: string; overline: { day: string; star: string; distant: string; reveal: string; whole: string }; wholeTitle: string; wholeText: string; wholeLink: string; next: { day: string; star: string; distant: string; reveal: string; whole: string } };
}

export const journeyIt: JourneyCopy = {
  lang: 'it',
  title: 'Inner Stars — C’è un cielo, dentro di te.',
  description: 'Dai un posto agli sforzi che hai compiuto. Inner Stars trasforma vittorie, progetti e abitudini in un cielo da tornare a guardare.',
  nav: { journey: 'Il viaggio', app: 'L’app', try: 'Provala', language: 'Lingua', skip: 'Vai al contenuto' },
  eyebrow: 'UN VIAGGIO DI POCHI PASSI',
  hero: { before: 'Anche il buio', accent: 'ha le sue stelle.', after: '', text: 'Nei giorni pesanti si vede solo ciò che pesa. Il resto c’è ancora, solo più lontano.', scroll: 'SCORRI' },
  day: { before: 'Un giorno o periodo buio', accent: 'non deve rappresentare tutta la tua storia.', after: '', text: 'Ogni sforzo fatto resta, anche quando oggi non riesci a vederlo.' },
  star: { before: 'Tutto ricomincia', accent: 'da una stella.', text: 'Un piccolo o grande sforzo: che sia nel passato (vittoria), nel presente (abitudine) o nel futuro (obiettivo).' },
  distant: { before: 'Le stelle', accent: 'formano una costellazione.', text: 'I tuoi sforzi nel tempo prendono forma diventando un progetto, una direzione.', examples: ['Hai affrontato quella conversazione.', 'Hai ricominciato dopo una pausa.', 'Hai chiesto una mano.'], caption: 'PICCOLI SFORZI. STORIE POSSIBILI.' },
  reveal: { before: 'Le costellazioni', accent: 'orbitano intorno a una supernova.', text: 'Corpo, mente, lavoro, relazioni: ognuna delle 8 aree della tua vita è una supernova nella galassia.', caption: 'OGNI LUCE, QUALCOSA CHE HAI ATTRAVERSATO.' },
  product: {
    eyebrow: 'QUESTO È INNER STARS', title: 'Un posto per tutto questo.', text: 'Un’app per custodire ciò che hai affrontato, dare forma ai tuoi progetti e tornare a vedere il tuo percorso.', items: [
      { title: 'Dai valore a ciò che ti è costato.', text: 'Una conversazione difficile. Un primo tentativo. Una vittoria che conosci solo tu. Registra il tuo sforzo: conta quanto è stato grande per te.', caption: 'Una vittoria, nel lettore attuale dell’app.' },
      { title: 'Dai una forma a dove vuoi andare.', text: 'I tuoi progetti diventano costellazioni. Le vittorie le illuminano, gli obiettivi indicano i prossimi passi e le abitudini trovano il proprio ritmo.', caption: 'Una costellazione da costruire, una stella alla volta.' },
      { title: 'Torna a guardare la strada fatta.', text: 'Ci saranno ancora giornate difficili. Quando vorrai, potrai rileggere un ricordo, ritrovare un passo e guardare il cielo che stai costruendo.', caption: 'Vittorie, obiettivi e abitudini nel browser Sky.' },
    ]
  },
  faq: {
    title: 'Prima di partire.', items: [
      { q: 'Che cosa posso fare con Inner Stars?', a: 'Puoi registrare vittorie, organizzare progetti e obiettivi e seguire le tue abitudini. In Galaxy il percorso prende la forma di stelle e costellazioni; in Sky puoi cercare e rileggere le tue attività.' },
      { q: 'Devo aver fatto qualcosa di straordinario?', a: 'Basta qualcosa che abbia richiesto uno sforzo per te. L’intensità che scegli racconta quanto ti è costato, anche quando dall’esterno può sembrare un gesto piccolo.' },
      { q: 'Dove posso usarla?', a: 'Su Android, scaricando l’APK, oppure dal browser. Una versione per iOS è in arrivo. L’app è disponibile in italiano, inglese e rumeno.' },
      { q: 'Il cielo che vedo qui è il mio?', a: 'È un’anteprima di Galaxy con dati di esempio. Nell’app costruirai il tuo cielo con i tuoi progetti e le tue attività.' },
    ]
  },
  closing: { eyebrow: 'IL PROSSIMO PASSO È TUO', title: '[[Accendi]] la tua prima [[stella.]]', text: 'Basta una cosa che hai affrontato, anche piccola. Il resto del cielo si costruisce un passo alla volta.', apk: 'Scarica per Android', web: 'Provala nel browser', platforms: 'Android · Web · iOS in arrivo' },
  footer: 'Ogni sforzo ha il suo posto.',
  ui: { prev: 'Sezione precedente', mainNav: 'Navigazione principale', try: 'Prova Inner Stars', discover: 'Scopri l’app', overline: { day: 'QUANDO È DIFFICILE VEDERE', star: 'ATTIVITÀ · STELLA', distant: 'PROGETTO · COSTELLAZIONE', reveal: 'AREA · SUPERNOVA', whole: 'IL TUO CIELO INTERO' }, wholeTitle: '[[Sei molto di più]] del buio in cui ti puoi ritrovare a volte.', wholeText: 'Otto aree, tanti progetti, ancora più sforzi: un cielo intero che cresce insieme a te e che ti ricorda della luce che hai portato nella tua vita.', wholeLink: 'Dai un posto al tuo percorso', next: { day: 'AVVICINATI', star: 'UNA STELLA, POI UNA COSTELLAZIONE', distant: 'ALLARGA LO SGUARDO', reveal: 'GUARDA IL CIELO INTERO', whole: 'SCOPRI L’APP' } },
};

export const journeyEn: JourneyCopy = {
  lang: 'en',
  title: 'Inner Stars — There’s a sky within you.',
  description: 'Make room for the efforts you have made. Inner Stars turns victories, projects and habits into a sky you can return to.',
  nav: { journey: 'The journey', app: 'The app', try: 'Try it', language: 'Language', skip: 'Skip to content' },
  eyebrow: 'A JOURNEY OF A FEW STEPS',
  hero: { before: 'Even the dark', accent: 'has its stars.', after: '', text: 'On heavy days you only see what weighs on you. The rest is still there, just further away.', scroll: 'SCROLL' },
  day: { before: 'A dark day or period', accent: 'doesn’t have to be your whole story.', after: '', text: 'Every effort you made stays, even when you can’t see it today.' },
  star: { before: 'It all begins again', accent: 'with a star.', text: 'A small or big effort: in the past (a victory), in the present (a habit) or in the future (a goal).' },
  distant: { before: 'Stars', accent: 'form a constellation.', text: 'Your efforts over time take shape and become a project, a direction.', examples: ['You had that difficult conversation.', 'You started again after a break.', 'You asked for a hand.'], caption: 'SMALL EFFORTS. POSSIBLE STORIES.' },
  reveal: { before: 'Constellations', accent: 'orbit a supernova.', text: 'Body, mind, work, relationships: each of the 8 areas of your life is a supernova in the galaxy.', caption: 'EVERY LIGHT, SOMETHING YOU HAVE FACED.' },
  product: {
    eyebrow: 'THIS IS INNER STARS', title: 'A place for all of this.', text: 'An app to keep what you have faced, give shape to your projects and see your journey again.', items: [
      { title: 'Value what took effort.', text: 'A difficult conversation. A first attempt. A victory only you know about. Record your effort: what matters is how much it meant to you.', caption: 'A victory in the app’s current reader.' },
      { title: 'Give your next steps a shape.', text: 'Your projects become constellations. Victories light them up, goals mark the next steps, and habits find their own rhythm.', caption: 'A constellation to build, one star at a time.' },
      { title: 'Look back at how far you’ve come.', text: 'There will still be difficult days. Whenever you want, you can revisit a memory, rediscover a step and look at the sky you are building.', caption: 'Victories, goals and habits in the Sky browser.' },
    ]
  },
  faq: {
    title: 'Before you set off.', items: [
      { q: 'What can I do with Inner Stars?', a: 'Record victories, organise projects and goals, and follow your habits. In Galaxy, your journey takes the shape of stars and constellations. In Sky, you can search and revisit your activities.' },
      { q: 'Does it have to be something extraordinary?', a: 'Anything that took effort for you belongs here. The intensity you choose reflects what it cost you, even if it might look like a small thing from the outside.' },
      { q: 'Where can I use it?', a: 'On Android by downloading the APK, or in your browser. An iOS version is coming soon. The app is available in Italian, English and Romanian.' },
      { q: 'Is this sky mine?', a: 'This is a preview of Galaxy with example data. In the app, you will build your own sky with your projects and activities.' },
    ]
  },
  closing: { eyebrow: 'THE NEXT STEP IS YOURS', title: '[[Light]] your first [[star.]]', text: 'One thing you faced is enough, however small. The rest of the sky is built one step at a time.', apk: 'Download for Android', web: 'Try it in your browser', platforms: 'Android · Web · iOS coming soon' },
  footer: 'Every effort has its place.',
  ui: { prev: 'Previous section', mainNav: 'Main navigation', try: 'Try Inner Stars', discover: 'Discover the app', overline: { day: 'WHEN IT’S HARD TO SEE', star: 'ACTIVITY · STAR', distant: 'PROJECT · CONSTELLATION', reveal: 'AREA · SUPERNOVA', whole: 'YOUR WHOLE SKY' }, wholeTitle: '[[You are far more]] than the darkness you may find yourself in at times.', wholeText: 'Eight areas, many projects, even more efforts: a whole sky that grows with you and reminds you of the light you have brought into your life.', wholeLink: 'Give your journey a home', next: { day: 'COME CLOSER', star: 'FROM A STAR TO A CONSTELLATION', distant: 'WIDEN YOUR VIEW', reveal: 'SEE THE WHOLE SKY', whole: 'DISCOVER THE APP' } },
};

export const journeyRo: JourneyCopy = {
  lang: 'ro',
  title: 'Inner Stars — Există un cer în tine.',
  description: 'Dă un loc eforturilor pe care le-ai făcut. Inner Stars transformă victoriile, proiectele și obiceiurile într-un cer la care te poți întoarce.',
  nav: { journey: 'Călătoria', app: 'Aplicația', try: 'Încearc-o', language: 'Limba', skip: 'Mergi la conținut' },
  eyebrow: 'O CĂLĂTORIE DIN CÂȚIVA PAȘI',
  hero: { before: 'Chiar și întunericul', accent: 'are stelele lui.', after: '', text: 'În zilele grele vezi doar ce te apasă. Restul e încă acolo, doar mai departe.', scroll: 'DERULEAZĂ' },
  day: { before: 'O zi sau o perioadă întunecată', accent: 'nu trebuie să fie toată povestea ta.', after: '', text: 'Fiecare efort făcut rămâne, chiar și când azi nu îl poți vedea.' },
  star: { before: 'Totul reîncepe', accent: 'de la o stea.', text: 'Un efort mic sau mare: în trecut (o victorie), în prezent (un obicei) sau în viitor (un obiectiv).' },
  distant: { before: 'Stelele', accent: 'formează o constelație.', text: 'Eforturile tale, în timp, prind formă și devin un proiect, o direcție.', examples: ['Ai purtat acea conversație.', 'Ai luat-o de la capăt după o pauză.', 'Ai cerut o mână de ajutor.'], caption: 'EFORTURI MICI. POVEȘTI POSIBILE.' },
  reveal: { before: 'Constelațiile', accent: 'orbitează în jurul unei supernove.', text: 'Corp, minte, muncă, relații: fiecare dintre cele 8 zone ale vieții tale este o supernovă în galaxie.', caption: 'FIECARE LUMINĂ, CEVA CE AI TRECUT.' },
  product: {
    eyebrow: 'ASTA ESTE INNER STARS', title: 'Un loc pentru toate acestea.', text: 'O aplicație în care păstrezi ce ai înfruntat, dai formă proiectelor tale și îți revezi drumul.', items: [
      { title: 'Dă valoare la ce te-a costat.', text: 'O conversație grea. O primă încercare. O victorie pe care o știi doar tu. Notează-ți efortul: contează cât de mare a fost pentru tine.', caption: 'O victorie, în cititorul actual al aplicației.' },
      { title: 'Dă formă locului în care vrei să ajungi.', text: 'Proiectele tale devin constelații. Victoriile le luminează, obiectivele arată următorii pași, iar obiceiurile își găsesc ritmul.', caption: 'O constelație de construit, o stea pe rând.' },
      { title: 'Privește din nou drumul parcurs.', text: 'Vor mai fi zile grele. Când vrei, poți reciti o amintire, regăsi un pas și privi cerul pe care îl construiești.', caption: 'Victorii, obiective și obiceiuri în browserul Sky.' },
    ]
  },
  faq: {
    title: 'Înainte să pornești.', items: [
      { q: 'Ce pot face cu Inner Stars?', a: 'Poți nota victorii, organiza proiecte și obiective și urmări obiceiurile. În Galaxy, drumul tău ia forma stelelor și constelațiilor; în Sky poți căuta și reciti activitățile.' },
      { q: 'Trebuie să fi făcut ceva extraordinar?', a: 'E de ajuns ceva care a cerut efort pentru tine. Intensitatea aleasă arată cât te-a costat, chiar dacă din exterior poate părea un gest mic.' },
      { q: 'Unde o pot folosi?', a: 'Pe Android, descărcând APK-ul, sau din browser. O versiune pentru iOS vine în curând. Aplicația este disponibilă în italiană, engleză și română.' },
      { q: 'Cerul pe care îl văd aici este al meu?', a: 'Este o previzualizare Galaxy cu date de exemplu. În aplicație îți vei construi propriul cer, cu proiectele și activitățile tale.' },
    ]
  },
  closing: { eyebrow: 'URMĂTORUL PAS ESTE AL TĂU', title: '[[Aprinde]] prima ta [[stea.]]', text: 'E de ajuns un lucru cu care te-ai confruntat, oricât de mic. Restul cerului se construiește pas cu pas.', apk: 'Descarcă pentru Android', web: 'Încearc-o în browser', platforms: 'Android · Web · iOS în curând' },
  footer: 'Fiecare efort are locul lui.',
  ui: { prev: 'Secțiunea anterioară', mainNav: 'Navigare principală', try: 'Încearcă Inner Stars', discover: 'Descoperă aplicația', overline: { day: 'CÂND E GREU SĂ VEZI', star: 'ACTIVITATE · STEA', distant: 'PROIECT · CONSTELAȚIE', reveal: 'ZONĂ · SUPERNOVĂ', whole: 'CERUL TĂU ÎNTREG' }, wholeTitle: '[[Ești mult mai mult]] decât întunericul în care te poți regăsi uneori.', wholeText: 'Opt zone, multe proiecte, și mai multe eforturi: un cer întreg care crește odată cu tine și care îți amintește de lumina pe care ai adus-o în viața ta.', wholeLink: 'Dă un loc drumului tău', next: { day: 'APROPIE-TE', star: 'DE LA O STEA LA O CONSTELAȚIE', distant: 'LARGEȘTE PRIVIREA', reveal: 'PRIVEȘTE CERUL ÎNTREG', whole: 'DESCOPERĂ APLICAȚIA' } },
};
