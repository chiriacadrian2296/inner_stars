import type { SiteLang } from './types';

// Privacy policy and terms of use, one set per site language. Keep the three
// versions in step: they describe the same app and the same data.
// If the app starts collecting something new (crash reports, analytics, new
// kinds of media), update the privacy text before the build ships.

export const LEGAL_UPDATED = '2026-10-22';
export const CONTROLLER = 'Mihai Adrian Chiriac';
export const CONTACT = 'privacy@innerstars.app';

export interface Section { h: string; p?: string[]; ul?: string[] }
export interface Doc { title: string; description: string; intro: string; sections: Section[] }
export interface LegalCopy {
  lang: SiteLang;
  htmlLocale: string;
  updatedLabel: string;
  dateText: string;
  back: string;
  privacyLink: string;
  termsLink: string;
  privacy: Doc;
  terms: Doc;
}

const it: LegalCopy = {
  lang: 'it',
  htmlLocale: 'it',
  updatedLabel: 'Ultimo aggiornamento',
  dateText: '22 ottobre 2026',
  back: 'Torna alla home',
  privacyLink: 'Privacy',
  termsLink: 'Termini',
  privacy: {
    title: 'Informativa sulla privacy',
    description: 'Quali dati raccoglie Inner Stars, dove sono conservati, per quanto tempo e come puoi cancellarli.',
    intro: `Questa informativa spiega come Inner Stars (l’app per Android e per il web, e il sito innerstars.app) tratta i tuoi dati personali. Il titolare del trattamento è ${CONTROLLER}, raggiungibile a ${CONTACT}.`,
    sections: [
      {
        h: 'In breve',
        ul: [
          'L’app nasce per funzionare sul tuo dispositivo: i contenuti che crei restano lì finché non accedi con Google.',
          'Se accedi, i tuoi contenuti vengono copiati nel tuo spazio privato nel cloud, così li ritrovi su tutti i tuoi dispositivi.',
          'Non c’è pubblicità, non vendiamo né cediamo i tuoi dati e non li usiamo per profilarti.',
          'Puoi cancellare i dati dal dispositivo e, se hai un account, l’account con tutti i dati nel cloud, direttamente dalle Impostazioni.',
        ],
      },
      {
        h: 'Quali dati trattiamo',
        p: ['Dipende da come usi l’app.'],
        ul: [
          'Account: se accedi con Google, riceviamo il nome, l’indirizzo email, la foto del profilo e un identificativo del tuo account Google. Non riceviamo la tua password.',
          'Contenuti: aree, progetti, vittorie, obiettivi, abitudini e relativi segni di completamento, riflessioni, visioni, desiderio, elementi della moodboard (immagini e citazioni) e le tue impostazioni.',
          'File: la foto principale delle vittorie, una nota vocale per vittoria (massimo 60 secondi) e le foto della moodboard. Sono dati che scegli tu di aggiungere e possono contenere informazioni personali o sensibili, a seconda di ciò che scrivi, registri o fotografi.',
          'Blocco dell’app: se attivi un PIN, ne conserviamo solo un’impronta cifrata (hash), non il PIN in chiaro; l’impronta si sincronizza fra i tuoi dispositivi. L’impronta digitale, il volto o il PIN del sistema sono gestiti dal tuo dispositivo e non arrivano mai a noi.',
          'Promemoria: sono programmati sul dispositivo e non passano da nostri server.',
          'Dati tecnici: il sito e la web app sono distribuiti tramite Cloudflare, che può registrare per brevi periodi dati di rete come l’indirizzo IP e il tipo di browser per erogare il servizio e proteggerlo da abusi. Google (Firebase) tratta dati tecnici analoghi quando accedi o sincronizzi.',
        ],
      },
      {
        h: 'Perché li trattiamo e su quale base',
        ul: [
          'Per darti l’app, il tuo account e la sincronizzazione fra dispositivi: è l’esecuzione del servizio che chiedi (art. 6.1.b GDPR).',
          'Per tenere il servizio sicuro e funzionante e prevenire abusi: legittimo interesse (art. 6.1.f GDPR).',
          'Se in futuro aggiungessimo trattamenti che richiedono il tuo consenso, te lo chiederemo prima e potrai ritirarlo.',
        ],
      },
      {
        h: 'Dove sono conservati i dati',
        p: [
          'Sul tuo dispositivo, nella memoria dell’app (nel browser, nello spazio del sito). Se accedi, anche su Google Firebase: i documenti su Cloud Firestore in Europa (regione eur3) e i file su Cloud Storage in Europa (multi-regione UE).',
          'Google e Cloudflare sono nostri fornitori (responsabili del trattamento) e possono, per il funzionamento del servizio, trattare alcuni dati anche fuori dallo Spazio economico europeo, con le garanzie previste dal GDPR (ad esempio le clausole contrattuali standard o il Data Privacy Framework).',
        ],
      },
      {
        h: 'Per quanto tempo',
        p: [
          'Finché li tieni nell’app. Se elimini un contenuto, viene tolto dal tuo spazio. Se elimini l’account, cancelliamo l’utente e tutti i dati e i file nel cloud; qualche copia tecnica dei fornitori può restare per un breve periodo prima di sparire.',
          'I dati sul tuo dispositivo restano finché non scegli “Elimina dati su questo dispositivo” o non disinstalli l’app.',
        ],
      },
      {
        h: 'Con chi li condividiamo',
        p: [
          'Solo con i fornitori tecnici indicati sopra (Google/Firebase e Cloudflare). Non c’è pubblicità e non vendiamo dati.',
          'Quando usi “Condividi”, l’app crea un’immagine e la passa al foglio di condivisione del tuo sistema: sei tu a scegliere dove inviarla. Nel testo allegato mettiamo solo il link innerstars.app. L’immagine è nelle mani di chi la riceve e noi non ne teniamo una copia.',
        ],
      },
      {
        h: 'I tuoi diritti',
        p: [
          'Puoi chiederci accesso, rettifica, cancellazione, limitazione, portabilità e opposizione al trattamento, scrivendo a ' + CONTACT + '. Cancellazione dei dati e dell’account sono già disponibili da sole nelle Impostazioni.',
          'Se pensi che i tuoi dati non siano trattati correttamente puoi presentare un reclamo all’autorità per la protezione dei dati del tuo paese; in Italia è il Garante per la protezione dei dati personali (garanteprivacy.it).',
        ],
      },
      {
        h: 'Minori',
        p: ['Inner Stars non è pensata per bambini sotto i 14 anni. Se sei un genitore e pensi che tuo figlio abbia creato un account, scrivici e lo cancelliamo.'],
      },
      {
        h: 'Modifiche',
        p: ['Se questa informativa cambia in modo importante, aggiorneremo la data qui sopra e, quando serve, ti avviseremo nell’app.'],
      },
    ],
  },
  terms: {
    title: 'Termini di utilizzo',
    description: 'Le regole d’uso di Inner Stars: cosa puoi fare, cosa è tuo e cosa non garantiamo.',
    intro: `Questi termini regolano l’uso di Inner Stars (app per Android e web, e sito innerstars.app), offerta da ${CONTROLLER}. Usando l’app dichiari di averli letti e di accettarli.`,
    sections: [
      {
        h: 'Il servizio',
        p: ['Inner Stars è uno strumento personale per organizzare e raccontare i tuoi sforzi come un cielo di stelle. È gratuito. Puoi usarla sul dispositivo senza account; accedendo con Google puoi sincronizzare i contenuti fra dispositivi.'],
      },
      {
        h: 'Il tuo account',
        p: ['L’accesso avviene con il tuo account Google. Sei responsabile di ciò che succede con il tuo account e con il tuo dispositivo, compreso il PIN dell’app. Puoi uscire o cancellare l’account quando vuoi dalle Impostazioni.'],
      },
      {
        h: 'I tuoi contenuti',
        p: [
          'I contenuti che crei restano tuoi. Ci concedi soltanto il permesso tecnico di conservarli, copiarli e mostrarteli per far funzionare l’app e la sincronizzazione.',
          'Aggiungi solo contenuti che hai il diritto di usare (foto, voci, citazioni). I tuoi contenuti sono privati: non sono visibili ad altri utenti.',
        ],
      },
      {
        h: 'Uso corretto',
        ul: [
          'Non usare l’app per attività illecite o per violare diritti di altri.',
          'Non tentare di accedere ai dati di altri utenti, di aggirare le protezioni o di sovraccaricare il servizio.',
          'Non copiare, vendere o rivendere l’app o il suo codice: il codice sorgente e i contenuti dell’app sono protetti e ne sono riservati tutti i diritti.',
        ],
      },
      {
        h: 'Non è un consiglio professionale',
        p: ['Inner Stars non fornisce consulenza medica, psicologica, finanziaria o legale. Le aree, le riflessioni e le statistiche sono spunti personali. Se stai attraversando un momento difficile, rivolgiti a una persona o a un servizio competente.'],
      },
      {
        h: 'Disponibilità e modifiche',
        p: [
          'Facciamo il possibile perché il servizio funzioni, ma può essere interrotto, modificato o cambiare in funzione di aggiornamenti, manutenzione o guasti dei fornitori. Può succedere che si perdano dati: tieni da parte ciò che per te è importante.',
          'Possiamo aggiornare questi termini; la data in alto indica l’ultima versione. Se continui a usare l’app dopo un cambiamento importante, lo accetti.',
        ],
      },
      {
        h: 'Garanzie e responsabilità',
        p: [
          'L’app è offerta “così com’è”, senza garanzie ulteriori rispetto a quelle che la legge non permette di escludere. Nei limiti consentiti dalla legge, non rispondiamo di danni indiretti o della perdita di dati.',
          'Nulla di quanto qui scritto limita i diritti inderogabili che la legge del tuo paese ti riconosce come consumatore, né la responsabilità che non può essere esclusa per legge.',
        ],
      },
      {
        h: 'Legge applicabile e contatti',
        p: ['Si applica la legge italiana, ferme restando le norme di tutela del consumatore del tuo paese di residenza. Per domande o segnalazioni scrivi a ' + CONTACT + '. Il trattamento dei dati personali è descritto nell’informativa sulla privacy.'],
      },
    ],
  },
};

const en: LegalCopy = {
  lang: 'en',
  htmlLocale: 'en',
  updatedLabel: 'Last updated',
  dateText: 'October 22, 2026',
  back: 'Back to home',
  privacyLink: 'Privacy',
  termsLink: 'Terms',
  privacy: {
    title: 'Privacy Policy',
    description: 'What data Inner Stars collects, where it is stored, for how long, and how you can delete it.',
    intro: `This policy explains how Inner Stars (the Android and web app, and the innerstars.app website) handles your personal data. The data controller is ${CONTROLLER}, reachable at ${CONTACT}.`,
    sections: [
      {
        h: 'In short',
        ul: [
          'The app is built to work on your device: what you create stays there until you sign in with Google.',
          'If you sign in, your content is copied to your own private space in the cloud so you can find it on all your devices.',
          'There are no ads, we do not sell or hand over your data, and we do not use it to profile you.',
          'You can delete the data on your device and, if you have an account, the account and all its cloud data, straight from Settings.',
        ],
      },
      {
        h: 'What data we process',
        p: ['It depends on how you use the app.'],
        ul: [
          'Account: if you sign in with Google, we receive your name, email address, profile picture and a Google account identifier. We never receive your password.',
          'Content: areas, projects, victories, goals, habits and their completions, reflections, visions, wish, moodboard items (images and quotes) and your settings.',
          'Files: the main photo of each victory, one voice note per victory (up to 60 seconds) and moodboard photos. You choose to add them, and depending on what you write, record or photograph they can contain personal or sensitive information.',
          'App lock: if you turn on a PIN, we only keep a salted hash of it, never the PIN itself; the hash syncs across your devices. Fingerprint, face or the system PIN are handled by your device and never reach us.',
          'Reminders: they are scheduled on your device and do not go through our servers.',
          'Technical data: the website and the web app are delivered through Cloudflare, which may log network data such as the IP address and browser type for short periods to deliver the service and protect it from abuse. Google (Firebase) processes similar technical data when you sign in or sync.',
        ],
      },
      {
        h: 'Why we process it, and on what basis',
        ul: [
          'To give you the app, your account and syncing between devices: performing the service you ask for (Art. 6(1)(b) GDPR).',
          'To keep the service secure and working and to prevent abuse: legitimate interest (Art. 6(1)(f) GDPR).',
          'If we ever add processing that needs your consent, we will ask first and you will be able to withdraw it.',
        ],
      },
      {
        h: 'Where the data is stored',
        p: [
          'On your device, in the app’s storage (in the browser, the site’s storage). If you sign in, also on Google Firebase: documents on Cloud Firestore in Europe (region eur3) and files on Cloud Storage in Europe (EU multi-region).',
          'Google and Cloudflare are our service providers (processors) and, to run the service, may process some data outside the European Economic Area, with the safeguards the GDPR requires (for example standard contractual clauses or the Data Privacy Framework).',
        ],
      },
      {
        h: 'How long we keep it',
        p: [
          'For as long as you keep it in the app. If you delete an item, it is removed from your space. If you delete your account, we delete the user and all cloud data and files; some technical copies at our providers may remain for a short time before they disappear.',
          'Data on your device stays until you choose “Delete data on this device” or uninstall the app.',
        ],
      },
      {
        h: 'Who we share it with',
        p: [
          'Only with the technical providers named above (Google/Firebase and Cloudflare). There are no ads and we do not sell data.',
          'When you use “Share”, the app creates an image and hands it to your system’s share sheet: you choose where it goes. The accompanying text only contains the innerstars.app link. The image is in the hands of whoever receives it, and we keep no copy.',
        ],
      },
      {
        h: 'Your rights',
        p: [
          'You can ask us for access, correction, deletion, restriction, portability and objection by writing to ' + CONTACT + '. Deleting your data and your account is already available on its own in Settings.',
          'If you believe your data is not handled properly you can lodge a complaint with the data protection authority of your country; in Italy, that is the Garante per la protezione dei dati personali (garanteprivacy.it).',
        ],
      },
      {
        h: 'Children',
        p: ['Inner Stars is not meant for children under 14. If you are a parent and think your child has created an account, write to us and we will delete it.'],
      },
      {
        h: 'Changes',
        p: ['If this policy changes in a significant way, we will update the date above and, when needed, let you know in the app.'],
      },
    ],
  },
  terms: {
    title: 'Terms of Use',
    description: 'The rules for using Inner Stars: what you can do, what is yours and what we do not guarantee.',
    intro: `These terms govern the use of Inner Stars (Android and web app, and the innerstars.app website), offered by ${CONTROLLER}. By using the app you confirm that you have read and accept them.`,
    sections: [
      {
        h: 'The service',
        p: ['Inner Stars is a personal tool to organize and tell the story of your efforts as a sky of stars. It is free. You can use it on your device without an account; by signing in with Google you can sync your content between devices.'],
      },
      {
        h: 'Your account',
        p: ['You sign in with your Google account. You are responsible for what happens with your account and your device, including the app PIN. You can sign out or delete the account whenever you want from Settings.'],
      },
      {
        h: 'Your content',
        p: [
          'The content you create stays yours. You only give us the technical permission to store it, copy it and show it back to you so the app and syncing work.',
          'Only add content you have the right to use (photos, voices, quotes). Your content is private: other users cannot see it.',
        ],
      },
      {
        h: 'Fair use',
        ul: [
          'Do not use the app for unlawful activity or to violate other people’s rights.',
          'Do not try to access other users’ data, bypass protections or overload the service.',
          'Do not copy, sell or resell the app or its code: the source code and the app’s content are protected and all rights are reserved.',
        ],
      },
      {
        h: 'Not professional advice',
        p: ['Inner Stars does not provide medical, psychological, financial or legal advice. Areas, reflections and statistics are personal prompts. If you are going through a hard time, please reach out to a qualified person or service.'],
      },
      {
        h: 'Availability and changes',
        p: [
          'We do our best to keep the service running, but it can be interrupted, changed or affected by updates, maintenance or provider outages. Data can be lost: keep a copy of what matters to you.',
          'We may update these terms; the date at the top shows the latest version. If you keep using the app after a significant change, you accept it.',
        ],
      },
      {
        h: 'Warranty and liability',
        p: [
          'The app is offered “as is”, with no warranties beyond those the law does not allow us to exclude. To the extent permitted by law, we are not liable for indirect damages or for loss of data.',
          'Nothing here limits the mandatory rights you have as a consumer under the law of your country, or any liability that cannot be excluded by law.',
        ],
      },
      {
        h: 'Governing law and contact',
        p: ['Italian law applies, without prejudice to the consumer protection rules of your country of residence. For questions or reports write to ' + CONTACT + '. How personal data is handled is described in the Privacy Policy.'],
      },
    ],
  },
};

const ro: LegalCopy = {
  lang: 'ro',
  htmlLocale: 'ro',
  updatedLabel: 'Ultima actualizare',
  dateText: '22 octombrie 2026',
  back: 'Înapoi la pagina principală',
  privacyLink: 'Confidențialitate',
  termsLink: 'Termeni',
  privacy: {
    title: 'Politica de confidențialitate',
    description: 'Ce date colectează Inner Stars, unde sunt păstrate, cât timp și cum le poți șterge.',
    intro: `Această politică explică cum tratează Inner Stars (aplicația pentru Android și web și site-ul innerstars.app) datele tale personale. Operatorul de date este ${CONTROLLER}, care poate fi contactat la ${CONTACT}.`,
    sections: [
      {
        h: 'Pe scurt',
        ul: [
          'Aplicația este făcută să funcționeze pe dispozitivul tău: ce creezi rămâne acolo până când te autentifici cu Google.',
          'Dacă te autentifici, conținutul tău este copiat în spațiul tău privat din cloud, ca să-l regăsești pe toate dispozitivele.',
          'Nu există publicitate, nu vindem și nu cedăm datele tale și nu le folosim pentru a te profila.',
          'Poți șterge datele de pe dispozitiv și, dacă ai cont, contul cu toate datele din cloud, direct din Setări.',
        ],
      },
      {
        h: 'Ce date prelucrăm',
        p: ['Depinde de felul în care folosești aplicația.'],
        ul: [
          'Cont: dacă te autentifici cu Google, primim numele, adresa de e-mail, fotografia de profil și un identificator al contului Google. Nu primim niciodată parola ta.',
          'Conținut: arii, proiecte, victorii, obiective, obiceiuri și bifările lor, reflecții, viziuni, dorință, elemente din moodboard (imagini și citate) și setările tale.',
          'Fișiere: fotografia principală a victoriilor, o notă vocală pentru fiecare victorie (maximum 60 de secunde) și fotografiile din moodboard. Le adaugi tu și, în funcție de ce scrii, înregistrezi sau fotografiezi, pot conține informații personale sau sensibile.',
          'Blocarea aplicației: dacă activezi un PIN, păstrăm doar o amprentă criptată (hash) a lui, nu PIN-ul în clar; amprenta se sincronizează între dispozitivele tale. Amprenta digitală, fața sau PIN-ul sistemului sunt gestionate de dispozitiv și nu ajung niciodată la noi.',
          'Mementouri: sunt programate pe dispozitiv și nu trec prin serverele noastre.',
          'Date tehnice: site-ul și aplicația web sunt livrate prin Cloudflare, care poate înregistra pentru perioade scurte date de rețea, precum adresa IP și tipul de browser, pentru a livra serviciul și a-l proteja de abuzuri. Google (Firebase) prelucrează date tehnice similare când te autentifici sau sincronizezi.',
        ],
      },
      {
        h: 'De ce le prelucrăm și pe ce temei',
        ul: [
          'Pentru a-ți oferi aplicația, contul și sincronizarea între dispozitive: executarea serviciului pe care îl ceri (art. 6 alin. 1 lit. b GDPR).',
          'Pentru a menține serviciul sigur și funcțional și a preveni abuzurile: interes legitim (art. 6 alin. 1 lit. f GDPR).',
          'Dacă vom adăuga vreodată prelucrări care cer acordul tău, te vom întreba înainte și îl vei putea retrage.',
        ],
      },
      {
        h: 'Unde sunt păstrate datele',
        p: [
          'Pe dispozitivul tău, în spațiul de stocare al aplicației (în browser, în spațiul site-ului). Dacă te autentifici, și pe Google Firebase: documente în Cloud Firestore în Europa (regiunea eur3) și fișiere în Cloud Storage în Europa (multi-regiune UE).',
          'Google și Cloudflare sunt furnizorii noștri (persoane împuternicite) și, pentru funcționarea serviciului, pot prelucra unele date și în afara Spațiului Economic European, cu garanțiile cerute de GDPR (de exemplu clauze contractuale standard sau Data Privacy Framework).',
        ],
      },
      {
        h: 'Cât timp le păstrăm',
        p: [
          'Atât timp cât le ții în aplicație. Dacă ștergi un element, este scos din spațiul tău. Dacă ștergi contul, ștergem utilizatorul și toate datele și fișierele din cloud; unele copii tehnice la furnizorii noștri pot rămâne pentru scurt timp înainte să dispară.',
          'Datele de pe dispozitiv rămân până alegi „Șterge datele de pe acest dispozitiv” sau dezinstalezi aplicația.',
        ],
      },
      {
        h: 'Cu cine le împărtășim',
        p: [
          'Doar cu furnizorii tehnici menționați mai sus (Google/Firebase și Cloudflare). Nu există publicitate și nu vindem date.',
          'Când folosești „Distribuie”, aplicația creează o imagine și o trimite către meniul de partajare al sistemului: tu alegi unde ajunge. În text punem doar linkul innerstars.app. Imaginea ajunge la cine o primește, iar noi nu păstrăm nicio copie.',
        ],
      },
      {
        h: 'Drepturile tale',
        p: [
          'Ne poți cere acces, rectificare, ștergere, restricționare, portabilitate și opoziție scriind la ' + CONTACT + '. Ștergerea datelor și a contului este deja disponibilă direct în Setări.',
          'Dacă crezi că datele tale nu sunt tratate corect, poți depune o plângere la autoritatea pentru protecția datelor din țara ta; în România este ANSPDCP (dataprotection.ro), în Italia Garante per la protezione dei dati personali.',
        ],
      },
      {
        h: 'Minori',
        p: ['Inner Stars nu este destinată copiilor sub 14 ani. Dacă ești părinte și crezi că al tău copil a creat un cont, scrie-ne și îl ștergem.'],
      },
      {
        h: 'Modificări',
        p: ['Dacă politica se schimbă semnificativ, vom actualiza data de mai sus și, când e cazul, te vom anunța în aplicație.'],
      },
    ],
  },
  terms: {
    title: 'Termeni de utilizare',
    description: 'Regulile de folosire a Inner Stars: ce poți face, ce este al tău și ce nu garantăm.',
    intro: `Acești termeni reglementează utilizarea Inner Stars (aplicația pentru Android și web și site-ul innerstars.app), oferită de ${CONTROLLER}. Folosind aplicația, confirmi că i-ai citit și că îi accepți.`,
    sections: [
      {
        h: 'Serviciul',
        p: ['Inner Stars este un instrument personal pentru a-ți organiza și povesti eforturile ca pe un cer de stele. Este gratuită. O poți folosi pe dispozitiv fără cont; autentificându-te cu Google poți sincroniza conținutul între dispozitive.'],
      },
      {
        h: 'Contul tău',
        p: ['Te autentifici cu contul tău Google. Ești responsabil pentru ce se întâmplă cu contul și dispozitivul tău, inclusiv PIN-ul aplicației. Poți ieși din cont sau îl poți șterge oricând din Setări.'],
      },
      {
        h: 'Conținutul tău',
        p: [
          'Conținutul pe care îl creezi rămâne al tău. Ne dai doar permisiunea tehnică de a-l stoca, copia și afișa pentru ca aplicația și sincronizarea să funcționeze.',
          'Adaugă doar conținut pe care ai dreptul să îl folosești (fotografii, voci, citate). Conținutul tău este privat: ceilalți utilizatori nu îl pot vedea.',
        ],
      },
      {
        h: 'Utilizare corectă',
        ul: [
          'Nu folosi aplicația pentru activități ilegale sau pentru a încălca drepturile altora.',
          'Nu încerca să accesezi datele altor utilizatori, să ocolești protecțiile sau să supraîncarci serviciul.',
          'Nu copia, nu vinde și nu revinde aplicația sau codul ei: codul sursă și conținutul aplicației sunt protejate, iar toate drepturile sunt rezervate.',
        ],
      },
      {
        h: 'Nu este sfat profesional',
        p: ['Inner Stars nu oferă consultanță medicală, psihologică, financiară sau juridică. Ariile, reflecțiile și statisticile sunt repere personale. Dacă treci printr-o perioadă grea, adresează-te unei persoane sau unui serviciu competent.'],
      },
      {
        h: 'Disponibilitate și modificări',
        p: [
          'Facem tot posibilul ca serviciul să funcționeze, dar poate fi întrerupt, modificat sau afectat de actualizări, mentenanță ori defecțiuni ale furnizorilor. Se pot pierde date: păstrează o copie a ce contează pentru tine.',
          'Putem actualiza acești termeni; data de sus arată ultima versiune. Dacă continui să folosești aplicația după o schimbare importantă, o accepți.',
        ],
      },
      {
        h: 'Garanții și răspundere',
        p: [
          'Aplicația este oferită „așa cum este”, fără alte garanții decât cele pe care legea nu ne permite să le excludem. În limitele permise de lege, nu răspundem pentru daune indirecte sau pentru pierderea datelor.',
          'Nimic din acest text nu limitează drepturile imperative pe care legea țării tale ți le recunoaște ca consumator și nici răspunderea care nu poate fi exclusă prin lege.',
        ],
      },
      {
        h: 'Legea aplicabilă și contact',
        p: ['Se aplică legea italiană, fără a aduce atingere normelor de protecție a consumatorului din țara ta de reședință. Pentru întrebări sau sesizări scrie la ' + CONTACT + '. Prelucrarea datelor personale este descrisă în politica de confidențialitate.'],
      },
    ],
  },
};

export const legal: Record<SiteLang, LegalCopy> = { it, en, ro };

// Where each legal page lives, e.g. legalPath(base, 'en', 'privacy') -> /en/privacy/
export function legalPath(base: string, lang: SiteLang, kind: 'privacy' | 'terms') {
  return `${base}${lang === 'it' ? '' : `${lang}/`}${kind}/`;
}
