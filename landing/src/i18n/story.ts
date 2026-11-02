import type { SiteLang } from './types';

// Editorial evidence, inspected on staging at 6f9fa87 (30 October 2026).
// Personal origin, prioritisation and division of work: author's account, 1 Nov 2026.
// These references document product changes, not human authorship of the code.
export const storyEvidence = {
  prototype: ['4495e10', '317d113', '1632a32'], // 26–27 Aug: storage, creation, rereading.
  universe: ['8199cb3', '6435249', 'bf3576f', 'd521eeb'], // Areas, sphere, search, rebrand.
  experience: ['cee1f58', '330223f', '45ec146', '3af8549'], // Activities, reflection, Nightlight, cycles.
  release: ['64b1f6f', '85935e7', '98c3a61', '0cea60b', 'f4df453'],
  iteration: ['fb9b6d6', '9f111d7', '8001f03'], // 24–29 Oct, integrated into staging.
  scope: 'docs/release-plan.md', // Local-first; limited media; web reminders deferred.
  media: 'docs/media-sync.md', // Persistent queue; delayed file arrival; browser audio.
  currentImages: '82d7bbf', // Demo captures and renderer clips committed 18 Oct.
  historicalImages: '64b1f6f', // Existing Nightlight captures committed 4 Oct.
} as const;

interface StoryCopy {
  title: string;
  description: string;
  eyebrow: string;
  hero: [string, string];
  intro: string;
  byline: string;
  readStory: string;
  myRole: string;
  myWork: string;
  aiRole: string;
  aiWork: string;
  sections: [string, string, string];
  timelineTitle: string;
  timelineIntro: string;
  timeline: { date: string; iso: string; title: string; text: string }[];
  chapterLabels: [string, string, string];
  chapters: { label: string; title: string; need: string; change: string; outcome: string }[];
  readerAlt: string;
  skyAlt: string;
  constellationAlt: string;
  demoCaption: string;
  galaxyCaption: string;
  clipTitle: string;
  play: string;
  stop: string;
  metaphor: [string, string, string];
  nightlightCaption: string;
  nightlightAlt: string;
  experienceCaption: string;
  experienceSteps: [string, string, string];
  delivery: [string, string, string];
  deliveryNote: string;
  scopeTitle: string;
  scopeText: string;
  methodTitle: string;
  methodIntro: string;
  method: { title: string; text: string; owner: string }[];
  loop: string;
  pareto: string;
  paretoNote: string;
  closingTitle: string;
  closingText: string;
  takeaways: { title: string; text: string }[];
  tryApp: string;
  backHome: string;
  notesTitle: string;
  notes: string;
  status: string;
}

export const storyCopy: Record<SiteLang, StoryCopy> = {
  it: {
    title: 'Inner Stars — Dall’idea al prodotto, con l’AI',
    description: 'Come ho trasformato un bisogno personale in Inner Stars: idee, priorità, confronto con l’AI e iterazioni nell’app. Un progetto di Adrian Chiriac.',
    eyebrow: 'La storia del progetto',
    hero: ['Da un bisogno personale.', 'A un universo.'],
    intro: 'Quando le cose si fanno difficili, a volte perdo di vista ciò che ho già affrontato. Ho immaginato un’app che custodisse quelle vittorie e me le restituisse come stelle: qualcosa da tornare a guardare per ritrovare il coraggio di andare avanti.',
    byline: 'Adrian Chiriac · Progetto personale · Agosto–ottobre 2026',
    readStory: 'Segui il percorso',
    myRole: 'Il mio contributo',
    myWork: 'Idea, priorità, esperienza e valutazione nell’app.',
    aiRole: 'Il contributo dell’AI',
    aiWork: 'Implementazione del codice e verifiche tecniche.',
    sections: ['Il percorso', 'Le scelte', 'Il metodo'],
    timelineTitle: 'Una stella alla volta.',
    timelineIntro: 'Sono partito da qualcosa di piccolo. Il progetto è cresciuto attraverso fasi che si intrecciano, cambi di priorità e molti ritorni sulle cose già fatte.',
    timeline: [
      { date: '26–28 agosto', iso: '2026-08-26', title: 'Il primo nucleo', text: 'Registrare una vittoria, conservarla sul dispositivo e poterla rileggere.' },
      { date: 'Fine agosto–settembre', iso: '2026-08-31', title: 'Un universo esplorabile', text: 'Aree, progetti e costellazioni. Galaxy prende forma; ricerca e filtri evolvono in Sky.' },
      { date: 'Settembre–14 ottobre', iso: '2026-09-12', title: 'Un’esperienza più ampia', text: 'Obiettivi, abitudini, riflessioni e Nightlight. Le abitudini acquistano cicli e momenti di bilancio.' },
      { date: '4–22 ottobre', iso: '2026-10-04', title: 'Oltre il prototipo', text: 'Landing, distribuzione web, account, sincronizzazione e media fra dispositivi.' },
      { date: '24–30 ottobre', iso: '2026-10-24', title: 'Il lavoro continua', text: 'Editor, statistiche e percorso Nightlight vengono ripresi nella preparazione della versione successiva.' },
    ],
    chapterLabels: ['Esigenza', 'Cambiamento', 'Risultato'],
    chapters: [
      {
        label: 'Dare forma all’idea', title: 'Un ricordo può diventare una stella.',
        need: 'Volevo che le vittorie tornassero a essere visibili nei momenti in cui faccio fatica a ricordarle. La metafora delle stelle mi ha dato una direzione per l’identità dell’app.',
        change: 'Il diario iniziale è diventato un universo navigabile: attività come stelle, progetti come costellazioni, aree della vita come supernove. Accanto alla Galaxy si è sviluppato Sky, per cercare e gestire i contenuti.',
        outcome: 'Lo stesso percorso si può esplorare visivamente oppure ritrovare attraverso ricerca e filtri. L’identità dell’app prende forma anche nel modo in cui la si usa.',
      },
      {
        label: 'Sviluppare l’esperienza', title: 'Dare continuità a un’intuizione.',
        need: 'Partendo dalle vittorie, ho esplorato come dare spazio anche ai progetti, alle cose ancora da affrontare e ai piccoli passi ripetuti nel tempo.',
        change: 'Sono arrivati obiettivi, abitudini, riflessioni e statistiche. Nightlight ha aggiunto un percorso di respirazione e rilettura delle vittorie. Le abitudini si sono evolute in cicli con un momento di riflessione finale.',
        outcome: 'Il progetto permette di registrare ciò che è successo, accompagnare attività nel tempo e tornare sui propri ricordi. Nelle iterazioni successive, Nightlight diventa anche una visita guidata alle vittorie nella Galaxy.',
      },
      {
        label: 'Arrivare online', title: 'Il prodotto oltre la sua schermata.',
        need: 'Per rendere l’app accessibile online, il lavoro doveva comprendere anche accesso, dati e passaggio fra dispositivi.',
        change: 'Con l’AI abbiamo affrontato landing, hosting, account Google, sincronizzazione e media. L’implementazione e le verifiche tecniche sono state svolte dall’AI; io ho continuato a valutare l’esperienza nell’app e a indicare le correzioni.',
        outcome: 'Il progetto ha acquisito una landing e una distribuzione web, con un’architettura che conserva i dati sul dispositivo e li sincronizza con il cloud. Sono entrati nel lavoro anche problemi concreti, come foto e registrazioni audio che dovevano arrivare sull’altro dispositivo.',
      },
    ],
    readerAlt: 'Una vittoria dimostrativa nel lettore di Inner Stars: Ho fatto il primo passo.',
    skyAlt: 'Sky mostra attività dimostrative organizzate in schede, con ricerca e filtri.',
    constellationAlt: 'Un progetto dimostrativo prende la forma di una costellazione.',
    demoCaption: 'Schermate dell’app con dati dimostrativi · Catture del 18 ottobre 2026.',
    galaxyCaption: 'Galaxy in movimento, registrata con i renderer dell’app e dati dimostrativi · 18 ottobre 2026.',
    clipTitle: 'Da un’area alla sua costellazione',
    play: 'Riproduci il movimento', stop: 'Ferma il movimento',
    metaphor: ['Una vittoria', 'Un progetto', 'Un’area della vita'],
    nightlightCaption: 'Nightlight in una versione precedente · Schermata presente nel progetto dal 4 ottobre 2026, con interfaccia in inglese.',
    nightlightAlt: 'Versione precedente di Nightlight, con un cielo stellato e la scelta iniziale del percorso.',
    experienceCaption: 'Dalla registrazione alla rilettura: tre momenti che collegano le diverse parti dell’esperienza.',
    experienceSteps: ['Registrare un passo', 'Dargli un posto', 'Tornare a guardarlo'],
    delivery: ['Dispositivo', 'Sincronizzazione', 'Altro dispositivo'],
    deliveryNote: 'Schema del funzionamento: dati locali, copia nel cloud e aggiornamenti fra dispositivi. Implementazione tecnica affidata all’AI.',
    scopeTitle: 'Scegliere anche cosa rimandare.',
    scopeText: 'Il piano della prima versione limita i media sincronizzati a foto, una nota vocale per vittoria e immagini della moodboard. Video nuovi e promemoria web restano fuori da quel perimetro. Il percorso comprende anche queste scelte di priorità.',
    methodTitle: 'Io davo la direzione. Poi aprivo l’app.',
    methodIntro: 'A volte chiedevo direttamente di realizzare un’idea. Altre volte chiedevo un parere e confrontavamo le opzioni. Dopo l’implementazione, andavo nell’app a vedere come funzionava l’esperienza e cosa c’era da correggere.',
    method: [
      { title: 'Un’idea', text: 'Partivo da un bisogno o da qualcosa da migliorare.', owner: 'Io' },
      { title: 'Un confronto', text: 'Proponevo una direzione o valutavamo insieme le opzioni.', owner: 'Io + AI' },
      { title: 'La realizzazione', text: 'L’AI scriveva il codice e svolgeva le verifiche tecniche.', owner: 'AI' },
      { title: 'La prova nell’app', text: 'Guardavo il risultato e provavo schermate e flussi.', owner: 'Io' },
      { title: 'Le correzioni', text: 'Indicavo cosa cambiare e riprendevamo il lavoro.', owner: 'Io + AI' },
    ],
    loop: 'E da lì, un altro giro.',
    pareto: 'Qual è il cambiamento più importante che posso fare adesso?',
    paretoNote: 'Il principio di Pareto come criterio personale di priorità: cercare l’intervento con più impatto sul prodotto. Una domanda per orientarmi durante lo sviluppo.',
    closingTitle: 'Un prodotto da mostrare. Un modo di lavorare da portare avanti.',
    closingText: 'Con Inner Stars ho fatto esperienza di cosa significhi dare continuità a un’idea: scegliere una direzione, lavorare con l’AI, vedere il risultato e tornarci sopra. È questo il modo di costruire che voglio continuare a sviluppare in un team.',
    takeaways: [
      { title: 'Iniziativa', text: 'Trasformare un problema personale in un progetto concreto.' },
      { title: 'Direzione', text: 'Dare priorità e mantenere riconoscibile l’esperienza mentre cresce.' },
      { title: 'Iterazione', text: 'Valutare nell’app, formulare correzioni e imparare dal risultato.' },
    ],
    tryApp: 'Prova Inner Stars', backHome: 'Torna alla landing',
    notesTitle: 'Le fonti e il punto del percorso',
    notes: 'Racconto ricostruito dalla cronologia del progetto e dai suoi documenti, dal 26 agosto al 30 ottobre 2026, insieme alla mia testimonianza sul modo di lavorare. Le date indicano tappe documentate, non fasi separate. Le schermate hanno la propria data e mostrano contenuti dimostrativi; la cattura storica di Nightlight è indicata a parte.',
    status: 'Il progetto continua a evolvere. Le novità del 24–30 ottobre qui raccontate appartengono alla preparazione della versione successiva e possono non essere ancora disponibili nell’app online.',
  },
  en: {
    title: 'Inner Stars — From idea to product, with AI',
    description: 'How I turned a personal need into Inner Stars: ideas, priorities, collaboration with AI and iteration inside the app. A project by Adrian Chiriac.',
    eyebrow: 'The project story',
    hero: ['From a personal need.', 'To a whole universe.'],
    intro: 'When things get difficult, I sometimes lose sight of what I have already overcome. I imagined an app that could hold on to those victories and show them back to me as stars: something to return to when I need the courage to keep going.',
    byline: 'Adrian Chiriac · Personal project · August–October 2026',
    readStory: 'Follow the journey',
    myRole: 'My contribution', myWork: 'The idea, priorities, experience and evaluation inside the app.',
    aiRole: 'AI’s contribution', aiWork: 'Code implementation and technical checks.',
    sections: ['The journey', 'The decisions', 'The method'],
    timelineTitle: 'One star at a time.',
    timelineIntro: 'I started small. The project grew through overlapping phases, shifting priorities and many returns to things we had already built.',
    timeline: [
      { date: '26–28 August', iso: '2026-08-26', title: 'The first core', text: 'Record a victory, keep it on the device and return to read it.' },
      { date: 'Late August–September', iso: '2026-08-31', title: 'An explorable universe', text: 'Areas, projects and constellations. Galaxy takes shape; search and filters develop into Sky.' },
      { date: 'September–14 October', iso: '2026-09-12', title: 'A broader experience', text: 'Goals, habits, reflections and Nightlight. Habits gain cycles and a moment to reflect.' },
      { date: '4–22 October', iso: '2026-10-04', title: 'Beyond the prototype', text: 'A landing page, web distribution, accounts, synchronisation and media across devices.' },
      { date: '24–30 October', iso: '2026-10-24', title: 'The work continues', text: 'The editor, statistics and Nightlight journey are revisited in preparation for the next version.' },
    ],
    chapterLabels: ['Need', 'Change', 'Outcome'],
    chapters: [
      {
        label: 'Giving the idea a shape', title: 'A memory can become a star.',
        need: 'I wanted victories to become visible again when I struggle to remember them. The metaphor of stars gave me a direction for the app’s identity.',
        change: 'The initial journal became a navigable universe: activities as stars, projects as constellations, life areas as supernovas. Alongside Galaxy, Sky developed as a way to search and manage content.',
        outcome: 'The same journey can be explored visually or found through search and filters. The app’s identity also takes shape in the way it is used.',
      },
      {
        label: 'Developing the experience', title: 'Following an idea further.',
        need: 'Starting with victories, I explored how to make room for projects, things still to face and small steps repeated over time.',
        change: 'Goals, habits, reflections and statistics followed. Nightlight added a breathing and victory-rereading journey. Habits evolved into cycles with a reflection at the end.',
        outcome: 'The project lets people record what happened, follow activities over time and return to their memories. In later iterations, Nightlight also becomes a guided visit to victories in Galaxy.',
      },
      {
        label: 'Reaching the web', title: 'The product beyond its screen.',
        need: 'Making the app accessible online meant working on sign-in, data and the move between devices too.',
        change: 'With AI, we worked through the landing page, hosting, Google accounts, synchronisation and media. AI handled implementation and technical checks; I continued evaluating the experience inside the app and directing corrections.',
        outcome: 'The project gained a landing page and web distribution, with an architecture that keeps data on the device and synchronises it with the cloud. The work also included practical problems, such as getting photos and voice recordings to reach another device.',
      },
    ],
    readerAlt: 'A demonstration victory in the Inner Stars reader: I took the first step.',
    skyAlt: 'Sky displays demonstration activities as cards, with search and filters.',
    constellationAlt: 'A demonstration project takes the shape of a constellation.',
    demoCaption: 'App screens with demonstration data · Captured on 18 October 2026.',
    galaxyCaption: 'Galaxy in motion, captured with the app’s renderers and demonstration data · 18 October 2026.',
    clipTitle: 'From a life area to its constellation', play: 'Play the movement', stop: 'Stop the movement',
    metaphor: ['A victory', 'A project', 'A life area'],
    nightlightCaption: 'An earlier version of Nightlight · Screenshot present in the project since 4 October 2026, with an English interface.',
    nightlightAlt: 'An earlier version of Nightlight, showing a star field and the initial choice of journey.',
    experienceCaption: 'From recording to rereading: three moments that connect the different parts of the experience.',
    experienceSteps: ['Record a step', 'Give it a place', 'Return to it'],
    delivery: ['Device', 'Synchronisation', 'Another device'],
    deliveryNote: 'A diagram of the system: local data, a cloud copy and updates across devices. Technical implementation delegated to AI.',
    scopeTitle: 'Choosing what to leave for later.',
    scopeText: 'The first-version plan limits synchronised media to photos, one voice note per victory and moodboard images. New videos and web reminders sit outside that scope. These priority decisions are part of the journey too.',
    methodTitle: 'I set the direction. Then I opened the app.',
    methodIntro: 'Sometimes I asked for an idea to be built directly. Other times I asked for an opinion and we compared options. After implementation, I opened the app to see how the experience worked and what needed correcting.',
    method: [
      { title: 'An idea', text: 'I started with a need or something to improve.', owner: 'Me' },
      { title: 'A conversation', text: 'I proposed a direction or we explored options together.', owner: 'Me + AI' },
      { title: 'Implementation', text: 'AI wrote the code and ran technical checks.', owner: 'AI' },
      { title: 'Trying the app', text: 'I looked at the result and tried screens and flows.', owner: 'Me' },
      { title: 'Corrections', text: 'I described what to change and we returned to the work.', owner: 'Me + AI' },
    ],
    loop: 'And from there, another round.',
    pareto: 'What is the most important change I can make right now?',
    paretoNote: 'The Pareto principle as a personal way of setting priorities: looking for the intervention with the greatest impact on the product. A question to guide me through development.',
    closingTitle: 'A product to show. A way of working to keep developing.',
    closingText: 'Inner Stars gave me experience in following an idea through: choosing a direction, working with AI, seeing the result and revisiting it. This is the way of building I want to keep developing within a team.',
    takeaways: [
      { title: 'Initiative', text: 'Turning a personal problem into a concrete project.' },
      { title: 'Direction', text: 'Setting priorities and keeping the experience recognisable as it grows.' },
      { title: 'Iteration', text: 'Evaluating inside the app, describing corrections and learning from the result.' },
    ],
    tryApp: 'Try Inner Stars', backHome: 'Back to the landing page',
    notesTitle: 'Sources and where the project stands',
    notes: 'This account draws on the project’s history and documentation, from 26 August to 30 October 2026, alongside my account of how I worked. Dates mark documented milestones, not separate phases. Screens have their own dates and show demonstration content; the historical Nightlight capture is identified separately.',
    status: 'The project is still evolving. The developments from 24–30 October described here belong to preparation for the next version and may not yet be available in the online app.',
  },
  ro: {
    title: 'Inner Stars — De la idee la produs, cu AI',
    description: 'Cum am transformat o nevoie personală în Inner Stars: idei, priorități, colaborare cu AI și iterații în aplicație. Un proiect de Adrian Chiriac.',
    eyebrow: 'Povestea proiectului',
    hero: ['De la o nevoie personală.', 'La un univers întreg.'],
    intro: 'Când lucrurile devin dificile, uneori pierd din vedere ceea ce am depășit deja. Mi-am imaginat o aplicație care să păstreze acele victorii și să mi le arate din nou ca stele: un loc la care să mă întorc când am nevoie de curaj pentru a merge mai departe.',
    byline: 'Adrian Chiriac · Proiect personal · August–octombrie 2026',
    readStory: 'Urmărește parcursul',
    myRole: 'Contribuția mea',
    myWork: 'Ideea, prioritățile, experiența și evaluarea în aplicație.',
    aiRole: 'Contribuția AI',
    aiWork: 'Implementarea codului și verificările tehnice.',
    sections: ['Parcursul', 'Deciziile', 'Metoda'],
    timelineTitle: 'Câte o stea pe rând.',
    timelineIntro: 'Am pornit de la ceva mic. Proiectul a crescut prin etape care se suprapun, priorități în schimbare și multe reveniri asupra lucrurilor deja construite.',
    timeline: [
      { date: '26–28 august', iso: '2026-08-26', title: 'Primul nucleu', text: 'Să înregistrez o victorie, să o păstrez pe dispozitiv și să o pot reciti.' },
      { date: 'Sfârșit de august–septembrie', iso: '2026-08-31', title: 'Un univers de explorat', text: 'Zone, proiecte și constelații. Galaxy prinde formă, iar căutarea și filtrele evoluează în Sky.' },
      { date: 'Septembrie–14 octombrie', iso: '2026-09-12', title: 'O experiență mai amplă', text: 'Obiective, obiceiuri, reflecții și Nightlight. Obiceiurile capătă cicluri și un moment de bilanț.' },
      { date: '4–22 octombrie', iso: '2026-10-04', title: 'Dincolo de prototip', text: 'Landing page, distribuție web, conturi, sincronizare și fișiere media între dispozitive.' },
      { date: '24–30 octombrie', iso: '2026-10-24', title: 'Munca continuă', text: 'Editorul, statisticile și parcursul Nightlight sunt reluate în pregătirea versiunii următoare.' },
    ],
    chapterLabels: ['Nevoie', 'Schimbare', 'Rezultat'],
    chapters: [
      {
        label: 'Să dau formă ideii', title: 'O amintire poate deveni o stea.',
        need: 'Voiam ca victoriile să redevină vizibile în momentele în care îmi este greu să mi le amintesc. Metafora stelelor mi-a oferit o direcție pentru identitatea aplicației.',
        change: 'Jurnalul inițial a devenit un univers navigabil: activități ca stele, proiecte ca constelații, zone ale vieții ca supernove. Alături de Galaxy s-a dezvoltat Sky, pentru căutarea și gestionarea conținutului.',
        outcome: 'Același parcurs poate fi explorat vizual sau regăsit prin căutare și filtre. Identitatea aplicației prinde formă și prin felul în care este folosită.',
      },
      {
        label: 'Să dezvolt experiența', title: 'Să duc o intuiție mai departe.',
        need: 'Pornind de la victorii, am explorat cum să fac loc proiectelor, lucrurilor care încă trebuie înfruntate și pașilor mici repetați în timp.',
        change: 'Au urmat obiective, obiceiuri, reflecții și statistici. Nightlight a adăugat un parcurs de respirație și recitire a victoriilor. Obiceiurile au evoluat în cicluri, cu un moment de reflecție la final.',
        outcome: 'Proiectul permite înregistrarea lucrurilor întâmplate, urmărirea activităților în timp și revenirea la propriile amintiri. În iterațiile următoare, Nightlight devine și o vizită ghidată la victoriile din Galaxy.',
      },
      {
        label: 'Să ajung online', title: 'Produsul dincolo de ecran.',
        need: 'Pentru ca aplicația să fie accesibilă online, munca trebuia să includă și autentificarea, datele și trecerea de la un dispozitiv la altul.',
        change: 'Împreună cu AI am abordat landing page-ul, găzduirea, conturile Google, sincronizarea și fișierele media. AI s-a ocupat de implementare și verificările tehnice; eu am continuat să evaluez experiența în aplicație și să indic corecțiile.',
        outcome: 'Proiectul a dobândit un landing page și distribuție web, cu o arhitectură care păstrează datele pe dispozitiv și le sincronizează cu cloudul. Munca a inclus și probleme concrete, precum transferul fotografiilor și înregistrărilor audio pe un alt dispozitiv.',
      },
    ],
    readerAlt: 'O victorie demonstrativă în cititorul Inner Stars: Am făcut primul pas.',
    skyAlt: 'Sky afișează activități demonstrative organizate în carduri, cu funcții de căutare și filtrare.',
    constellationAlt: 'Un proiect demonstrativ ia forma unei constelații.',
    demoCaption: 'Ecrane ale aplicației cu date demonstrative și interfață în engleză · Capturi din 18 octombrie 2026.',
    galaxyCaption: 'Galaxy în mișcare, înregistrată cu sistemele de randare ale aplicației și date demonstrative · 18 octombrie 2026.',
    clipTitle: 'De la o zonă a vieții la constelația ei',
    play: 'Pornește mișcarea', stop: 'Oprește mișcarea',
    metaphor: ['O victorie', 'Un proiect', 'O zonă a vieții'],
    nightlightCaption: 'O versiune anterioară a Nightlight · Captură prezentă în proiect din 4 octombrie 2026, cu interfață în engleză.',
    nightlightAlt: 'O versiune anterioară a Nightlight, cu un cer înstelat și alegerea inițială a parcursului.',
    experienceCaption: 'De la înregistrare la recitire: trei momente care leagă diferitele părți ale experienței.',
    experienceSteps: ['Înregistrează un pas', 'Dă-i un loc', 'Întoarce-te la el'],
    delivery: ['Dispozitiv', 'Sincronizare', 'Alt dispozitiv'],
    deliveryNote: 'Schema funcționării: date locale, o copie în cloud și actualizări între dispozitive. Implementarea tehnică a fost încredințată AI.',
    scopeTitle: 'Să aleg și ce rămâne pentru mai târziu.',
    scopeText: 'Planul primei versiuni limitează fișierele media sincronizate la fotografii, o notă vocală pentru fiecare victorie și imaginile din moodboard. Videoclipurile noi și mementourile web rămân în afara acestui perimetru. Și aceste alegeri de prioritate fac parte din parcurs.',
    methodTitle: 'Eu dădeam direcția. Apoi deschideam aplicația.',
    methodIntro: 'Uneori ceream direct realizarea unei idei. Alteori ceream o părere și comparam opțiunile. După implementare, deschideam aplicația ca să văd cum funcționa experiența și ce trebuia corectat.',
    method: [
      { title: 'O idee', text: 'Porneam de la o nevoie sau de la ceva de îmbunătățit.', owner: 'Eu' },
      { title: 'O discuție', text: 'Propuneam o direcție sau exploram împreună opțiunile.', owner: 'Eu + AI' },
      { title: 'Implementarea', text: 'AI scria codul și efectua verificările tehnice.', owner: 'AI' },
      { title: 'Proba în aplicație', text: 'Priveam rezultatul și încercam ecranele și fluxurile.', owner: 'Eu' },
      { title: 'Corecțiile', text: 'Descriam ce trebuia schimbat și reluam munca.', owner: 'Eu + AI' },
    ],
    loop: 'Și de acolo, încă o iterație.',
    pareto: 'Care este cea mai importantă schimbare pe care o pot face acum?',
    paretoNote: 'Principiul Pareto ca mod personal de stabilire a priorităților: să caut intervenția cu cel mai mare impact asupra produsului. O întrebare care m-a orientat pe parcursul dezvoltării.',
    closingTitle: 'Un produs de arătat. Un mod de lucru de dus mai departe.',
    closingText: 'Cu Inner Stars am învățat ce înseamnă să duc o idee mai departe: să aleg o direcție, să lucrez cu AI, să văd rezultatul și să revin asupra lui. Acesta este modul de a construi pe care vreau să îl dezvolt în continuare într-o echipă.',
    takeaways: [
      { title: 'Inițiativă', text: 'Să transform o problemă personală într-un proiect concret.' },
      { title: 'Direcție', text: 'Să stabilesc priorități și să păstrez experiența recognoscibilă pe măsură ce crește.' },
      { title: 'Iterație', text: 'Să evaluez în aplicație, să formulez corecții și să învăț din rezultat.' },
    ],
    tryApp: 'Încearcă Inner Stars', backHome: 'Înapoi la landing page',
    notesTitle: 'Sursele și stadiul proiectului',
    notes: 'Această poveste este reconstruită din istoricul și documentația proiectului, din 26 august până în 30 octombrie 2026, împreună cu relatarea mea despre modul de lucru. Datele marchează etape documentate, nu faze separate. Capturile au propriile date și prezintă conținut demonstrativ; captura istorică Nightlight este identificată separat.',
    status: 'Proiectul continuă să evolueze. Noutățile din 24–30 octombrie descrise aici aparțin pregătirii versiunii următoare și este posibil să nu fie încă disponibile în aplicația online.',
  },
};
