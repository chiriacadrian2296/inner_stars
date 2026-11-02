import type { SiteLang } from './types';

interface ExploreCopy {
  eyebrow: string;
  title: string;
  intro: string;
  next: string;
  items: { title: string; text: string; detail: string }[];
}

export const exploreCopy: Record<SiteLang, ExploreCopy> = {
  it: {
    eyebrow: 'Dentro Inner Stars', title: 'Ogni parte ha il suo posto.',
    intro: 'Apri una voce e scopri come può accompagnare il tuo percorso.', next: 'Prova Inner Stars',
    items: [
      { title: 'Galaxy · Guarda il tuo percorso', text: 'Le attività diventano stelle, i progetti costellazioni e le aree della vita supernove. Galaxy è il tuo universo da esplorare: un modo visivo per tornare a vedere ciò che hai costruito.', detail: 'Puoi avvicinarti a un’area, raggiungere un progetto e aprire una stella per rileggere il ricordo che custodisce.' },
      { title: 'Sky · Ritrova ciò che cerchi', text: 'Quando vuoi cercare qualcosa in modo diretto, Sky raccoglie aree, progetti e attività in un browser a tre livelli. È un altro accesso agli stessi contenuti che abitano Galaxy.', detail: 'Ricerca e filtri ti aiutano a ritrovare una vittoria, un obiettivo o un’abitudine e a gestire il tuo percorso attraverso le schede.' },
      { title: 'Nightlight · Torna alle tue vittorie', text: 'Uno spazio per fermarti, respirare e rileggere ciò che hai già affrontato. Nightlight accompagna il ritorno alle tue vittorie, una alla volta.', detail: 'Puoi dedicarti alla respirazione e poi tornare ai ricordi. Anche un piccolo passo può meritare di essere guardato di nuovo.' },
      { title: 'Attività · Vittorie, obiettivi e abitudini', text: 'Una vittoria conserva un passo compiuto. Un obiettivo dà spazio a qualcosa che vuoi affrontare. Un’abitudine segue un impegno che ritorna nel tempo.', detail: 'Organizza le attività nei progetti e nelle aree della tua vita: puoi dare un posto sia a ciò che hai già fatto sia a ciò a cui vuoi dedicarti.' },
      { title: 'Riflessioni · Dai spazio al significato', text: 'Le domande di riflessione ti invitano a soffermarti sulle diverse aree della tua vita e su ciò che desideri coltivare.', detail: 'Puoi tornare sulle tue risposte nel tempo. Il percorso comprende anche ciò che impari e il modo in cui cambiano le tue priorità.' },
      { title: 'Statistiche · Rileggi la continuità', text: 'Calendari e riepiloghi offrono una lettura delle attività nel tempo. Ti aiutano a osservare dove hai dedicato i tuoi sforzi e a ritrovare i passi compiuti.', detail: 'Dalla visione d’insieme puoi entrare nelle aree e nei progetti per guardare più da vicino il tuo percorso.' },
    ],
  },
  en: {
    eyebrow: 'Inside Inner Stars', title: 'A place for every part of your journey.',
    intro: 'Open a topic to discover how it can support your journey.', next: 'Try Inner Stars',
    items: [
      { title: 'Galaxy · See your journey', text: 'Activities become stars, projects become constellations and life areas become supernovas. Galaxy is your universe to explore: a visual way to see what you have built.', detail: 'Move closer to an area, reach a project and open a star to revisit the memory it holds.' },
      { title: 'Sky · Find what you need', text: 'For a direct search, Sky brings areas, projects and activities together in a three-level browser. It gives you another way into the same content that lives in Galaxy.', detail: 'Search and filters help you find a victory, goal or habit and manage your journey through cards.' },
      { title: 'Nightlight · Revisit your victories', text: 'A space to pause, breathe and reread what you have already faced. Nightlight guides you back to your victories, one at a time.', detail: 'Spend a moment breathing, then return to your memories. Even a small step can deserve another look.' },
      { title: 'Activities · Victories, goals and habits', text: 'A victory keeps a step you have taken. A goal gives space to something you want to face. A habit follows a commitment that returns over time.', detail: 'Organise activities into projects and life areas, giving a place both to what you have done and to what you want to work towards.' },
      { title: 'Reflections · Make room for meaning', text: 'Reflection questions invite you to pause over the different areas of your life and what you want to nurture.', detail: 'Return to your answers over time. Your journey also includes what you learn and how your priorities change.' },
      { title: 'Statistics · Look back over time', text: 'Calendars and summaries offer a view of your activities over time. They help you see where you have put your efforts and revisit the steps you have taken.', detail: 'Move from the overview into areas and projects to look more closely at your journey.' },
    ],
  },
  ro: {
    eyebrow: 'În Inner Stars', title: 'Fiecare parte își are locul.',
    intro: 'Deschide un subiect și descoperă cum te poate însoți pe parcurs.', next: 'Încearcă Inner Stars',
    items: [
      { title: 'Galaxy · Privește-ți parcursul', text: 'Activitățile devin stele, proiectele constelații, iar domeniile vieții supernove. Galaxy este universul tău de explorat: un mod vizual de a revedea ceea ce ai construit.', detail: 'Te poți apropia de un domeniu, poți ajunge la un proiect și poți deschide o stea pentru a reciti amintirea pe care o păstrează.' },
      { title: 'Sky · Regăsește ceea ce cauți', text: 'Pentru o căutare directă, Sky adună domeniile, proiectele și activitățile într-un browser pe trei niveluri. Este o altă cale către același conținut din Galaxy.', detail: 'Căutarea și filtrele te ajută să găsești o victorie, un obiectiv sau un obicei și să îți gestionezi parcursul prin fișe.' },
      { title: 'Nightlight · Revino la victoriile tale', text: 'Un spațiu pentru a te opri, a respira și a reciti ceea ce ai înfruntat deja. Nightlight te însoțește înapoi la victoriile tale, una câte una.', detail: 'Poți dedica un moment respirației, apoi te poți întoarce la amintiri. Chiar și un pas mic merită să fie privit din nou.' },
      { title: 'Activități · Victorii, obiective și obiceiuri', text: 'O victorie păstrează un pas făcut. Un obiectiv oferă spațiu unui lucru pe care vrei să îl înfrunți. Un obicei urmărește un angajament care revine în timp.', detail: 'Organizează activitățile în proiecte și domenii ale vieții: găsești un loc atât pentru ceea ce ai făcut, cât și pentru ceea ce vrei să construiești.' },
      { title: 'Reflecții · Fă loc semnificației', text: 'Întrebările de reflecție te invită să te oprești asupra diferitelor domenii ale vieții și asupra a ceea ce vrei să cultivi.', detail: 'Poți reveni la răspunsuri în timp. Parcursul cuprinde și ceea ce înveți și felul în care se schimbă prioritățile tale.' },
      { title: 'Statistici · Privește continuitatea', text: 'Calendarele și rezumatele oferă o perspectivă asupra activităților în timp. Te ajută să observi unde ai depus efort și să regăsești pașii făcuți.', detail: 'Din imaginea de ansamblu poți intra în domenii și proiecte pentru a-ți privi parcursul mai îndeaproape.' },
    ],
  },
};
