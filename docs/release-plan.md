# Piano di rilascio – Inner Stars

Documento di lavoro: si procede per step, in ordine, spuntando le voci. Aggiornare questo file
quando una decisione cambia.

**Stato al 19 ottobre 2026:** completata la pulizia del codice di A5 e verificate le release
web e Android. Restano la prova manuale sul telefono e il worktree di profiling da sistemare.
A2 è completato: UUID, metadati, tombstone e contenuti d’area.
A3 (Riflessioni) è implementato e verificato con test mirati. A4 è implementato, con
verifica di release e prova di condivisione reale ancora da completare.
Le verifiche automatiche di A4 sono concluse (19 ottobre, ripresa dopo la pausa); resta
solo la prova manuale della condivisione. Nessun nuovo deploy: il telefono conserva la
build in prova.
Le verifiche sul codice e sulle build sono distinte dalle prove manuali sul telefono: una voce
si spunta solo quando tutte le verifiche indicate sono concluse.

Terminologia: vedi `docs/terminology.md` (Galaxy, Sky, attività, ecc.).

**Legenda**
- `[x]` fatto · `[ ]` da fare · `[~]` fatto a metà
- ⭐ **da rivedere con te**: prima di toccare il codice vanno chiesti i dettagli. Non partire senza
  averne parlato.

**Struttura**: prima tutte le modifiche all'app (parte A), poi l'infrastruttura e il resto, cioè
Firebase, hosting, privacy e store (parte B), infine la rifinitura (parte C).

## Da rivedere con te (indice delle ⭐)

1. Blocco app e promemoria anche sul web: cosa è possibile e cosa vuoi esattamente (A6).
2. Cosa mostrare nel pannello Account di Settings prima del login, e come cancellare i dati
   locali in release finché non c'è il login (A6).
3. Onboarding: va fatto come si deve, da discutere (A7).
4. Tutorial: cosa resta nell'app prima di rivederli (parte C).

## 0. Decisioni prese

- Dominio `innerstars.app` (landing) e `my.innerstars.app` (web app), comprati su Cloudflare;
  hosting su Cloudflare Pages.
- Application id Android/iOS: `app.innerstars` (già applicato, `namespace` e `MainActivity` inclusi).
- Backend: Firebase Auth (Google) + Firestore, piano Spark, regione `eur3`. Custodia dei dati
  accettata, con privacy policy e cancellazione account.
- L'app resta **local-first**: SharedPreferences è il database principale, Firestore è la copia
  remota sincronizzata.
- **Modo di lavorare (deciso il 20 ottobre):** `main` è la produzione e pubblica da sola; si
  lavora su rami di funzione nati da `main` (il nome lo sceglie Claude o lo dice l’autore) e li
  si riunisce a `main` interi quando sono finiti. **Niente ramo `dev` e niente ambiente di
  collaudo per ora** (nessun utente vero). Controlli automatici (`checks.yml`) su ogni ramo e
  prima di ogni deploy; Flutter fissato a 3.47.1. Dettagli e regole per i dati in
  `docs/workflow.md`; l’ambiente di collaudo con un secondo progetto Firebase si riprende
  quando entra la prima persona che non è l’autore.
- **Accesso obbligatorio (deciso il 19 ottobre sera):** nessuno entra nella Galaxy senza un
  account Google. Davanti a tutto c’è una pagina di login (A6). La prima volta serve internet;
  dopo, l’app si apre anche offline perché i dati stanno sul dispositivo.
- ID **UUID v4** (primo blocco di A2 completato); migrazione automatica dei dati locali
  all'avvio. Nessun utente reale, quindi nessuna cautela particolare di migrazione.
- Media sincronizzati nella v1: foto principale di ogni vittoria, **un audio per vittoria (max 60 s)**,
  moodboard con **foto e citazioni** (niente video, limite rigido di elementi per area, anche in locale).
  Il resto dopo la v1.
- Strumenti di sviluppo (lab, dati di esempio, reset) **solo nelle build di sviluppo**.
  **Eccezione temporanea del 19 ottobre:** il solo pulsante per caricare i dati di esempio
  resta visibile anche in release, per le prove dell'autore. Da disattivare prima dell'uscita
  ufficiale (A5); lab e reset restano di sviluppo.
- Comete: la frequenza attuale (`kCometPeriodScale = 0.45`) è quella definitiva.
- Sound Lab: resta nelle build di sviluppo; idea futura: pacchetti di suoni a pagamento.
- Backup dei dati locali / export JSON: non serve per ora, l'app la usa solo l'autore.
- Moodboard: massimo **12 elementi per area**, rigido anche in locale.
- Condivisione: ogni "Condividi" apre la pagina di personalizzazione già presente nel Share Lab;
  il tipo di contenuto non è più un parametro ma è automatico in base a ciò da cui si condivide.
- Frame rate: **Free**. Limitatore e sonde dei frame eliminati dal codice.
- Prima uscita: **Android e web** (con landing page e web app). iOS in futuro, senza data.
- Build pubblica: nessun file dei lab dentro.
- Riflessioni: l'elenco sta nella sezione Riflessioni di ogni area (quindi già raggruppato per
  area); aprendone una si vede a tutta pagina con condividi, modifica, elimina; l'eliminazione è
  definitiva (nessun archivio).
- Impostazioni sincronizzate: tutte, **tranne** qualità della Galaxy e volume audio, che restano
  per dispositivo.
- Segnalazione degli errori: sì, con Firebase Crashlytics (vedi B4 per il web).
- Blocco app (PIN) e promemoria giornaliero vanno aggiunti anche sul web.

---

# PARTE A – Modifiche all'app (in ordine)

## A1. Già fatto

- [x] `kDevTools` (`lib/debug/dev_tools.dart`): dietro di esso la sezione Lab del menu, il pulsante
      Moon lab, "Seed sample data", "Reset all data", i pulsanti Sound Lab (Settings e Quick
      Settings), le sonde dei frame e la riga "FPS Limit".
      Eccezione temporanea successiva: solo "Seed sample data" riabilitato in release per
      le prove dell'autore, da rimuovere prima dell'uscita ufficiale (A5).
- [x] Pannelli segnaposto di Settings (Customization, Passkey, Social) parcheggiati
      (`_kShowPlaceholderSections = false`).
- [x] Intensità tolta dalle riflessioni (`fromJson` tollera i dati vecchi).
- [x] Stella cadente spenta (`_kShowShootingStar = false`); il codice resta (TRB).
- [x] Gestione obiettivi e abitudini fuori dalle statistiche: il pulsante "Gestisci obiettivi e
      abitudini" sta accanto ad "Aggiungi" in Vedi area, Vedi costellazione, nei tooltip di Galaxy
      e nel menu (sezione Attività). La pagina è `lib/screens/today_habits_screen.dart`.
- [x] Dettagli di "Crea vittoria": accanto alla foto principale una sola nota vocale (max 1 minuto)
      e tre link con icona (canzone, posizione, sito; `StarMedia.linkKind`). Niente più foto
      secondarie né video da aggiungere; i dati vecchi restano leggibili nel lettore.
- [x] Statistiche: riga centrata se non c'è luce; scroll fino al pannello fissato al cambio di livello.
- [x] Application id `app.innerstars`.

## A2. Dati pronti per la sincronizzazione

Nessuna dipendenza esterna; si può fare subito, nessuna domanda aperta.

- [x] UUID v4 (`uuid`) per Star, Project, Habit, HabitCompletion, HabitCycle, StarsShape;
      riferimenti incrociati a stringa in repository, navigazione, filtri, statistiche e grafica.
- [x] Migrazione una tantum degli id esistenti (`lib/data/uuid_migration.dart`),
      idempotente, con versione schema e ripresa dopo scritture interrotte.
- [x] `updatedAt` non nullo, aggiornato nel punto unico di scrittura soltanto sui record
      cambiati, con timestamp monotoni.
- [x] Flag `deleted` (tombstone) per tutte le entità, conservato anche nei reset;
      le query UI lo filtrano. L’archiviazione (`dead`) resta distinta.
- [x] Visioni per area e desiderio globale esistente: `{value, updatedAt, deleted}`.
- [x] Moodboard: record UUID per elemento con area, posizione, `updatedAt` e `deleted`.
      Massimo 12 elementi attivi per area in UI e repository; vietati nuovi video.
      I video preesistenti restano leggibili. Elementi oltre il limite conservati come
      tombstone, senza cancellare i file nella migrazione.
- [x] Test di migrazione UUID, collegamenti, idempotenza e ripresa dopo errori di scrittura.
- [x] Test di migrazione metadati/contenuti, tombstone, limiti e rollback delle scritture.

### Registro di A2

- 19 ottobre 2026: primo intervento su ID e riferimenti incrociati. UUID v4 per le sei
  entità; la migrazione `lib/data/uuid_migration.dart` parte all'avvio prima dei repository,
  conserva i collegamenti e usa schema versione 1 e un journal persistito per riprendere
  senza cambiare UUID dopo un'interruzione. I dati non validi fermano la migrazione prima
  delle scritture. **30 test dedicati superati**, inclusi errori di scrittura simulati
  su ogni collezione, journal e versione schema, riferimenti orfani, creazione rapida di
  UUID nelle sei entità e annullamento dell'ultimo check-in.
- Tolte le dipendenze dalla natura numerica degli ID: date dei check-in in `createdAt`,
  esclusione esplicita dei dati tutorial e seed grafico deterministico da UUID. Restano
  interi le posizioni nelle forme, i numeri delle vittorie e gli indici del layout.
- La posizione dei pulsar viene ricalcolata con il seed UUID al primo avvio migrato e resta
  deterministica in seguito; i posti delle stelle nella forma (`slotSequence`) non cambiano.
- Verifiche: `flutter analyze --no-pub` senza problemi; suite completa con **485 test
  superati e 3 esclusi** (vista elenco di Sky nascosta). Build web release riuscita;
  la source map include la migrazione ed esclude ancora tutti i lab. Anche la build APK
  release ARM64 è riuscita (`flutter build apk --release --target-platform android-arm64
  --no-pub`, circa 66 MB). La migrazione si esegue al primo avvio della nuova build installata.
- 19 ottobre 2026, installazione sul telefono: ripetuti analyze e suite completa
  (485 test superati, 3 esclusi); costruito l'APK release completo e installato via USB
  sul dispositivo `c2abd67f`. Avviata `app.innerstars/.MainActivity`, confermata in primo
  piano e senza errori di avvio nel log controllato. La build non è debuggabile.
  Sul telefono era presente solo `com.example.inner_stars`: **scelta esplicita dell'autore**,
  installare la nuova app **senza trasferire i dati**. La vecchia installazione e i suoi
  contenuti restano intatti; nessun dato personale è stato copiato sul PC. Le prove manuali
  dei flussi elencati in A5 restano da fare.
- 19 ottobre 2026, secondo intervento completato: schema 2 per metadati e schema 3
  per visioni, desiderio e moodboard. Journal persistiti e versione scritta per ultima;
  ripresa dopo interruzioni senza cambiare le identità. Timestamp centralizzati,
  rollback della cache su errori, tombstone conservati nei salvataggi successivi e reset.
  **293 test mirati superati**, analisi senza problemi e build web release riuscita.
  Verificati anche il limite moodboard e l’assenza della scelta video nella UI.
  Nessun nuovo deploy: sul telefono resta la build che l’autore sta provando.

## A3. Nuova funzione: Riflessioni

Oggi: domande preimpostate per area, ne scegli una e rispondi. Obiettivo: riflessioni libere.
Ordine: dopo A2, così la nuova entità nasce già pronta alla sync.

- Una **riflessione** nasce da una domanda preimpostata **oppure da zero**, con un titolo/tema
  scritto dall'utente, e un testo di sviluppo sotto. È **sempre legata a un'area**, come oggi.
  Il testo è **unico** (modificabile, senza storico).
- Le domande preimpostate diventano **suggerimenti** per iniziare una riflessione.
- Entità sincronizzabile: `id` UUID, `title`, `body`, area (obbligatoria), origine (suggerita o
  libera), `createdAt`, `updatedAt`, `deleted`.
- Migrare le risposte esistenti alla nuova entità.
- **Condivisione come card, già nella v1**, come per le altre cose condivisibili (composer in
  `lib/screens/share_preview_screen.dart`, `lib/widgets/share_arrangement.dart`, `shareable_*_card.dart`).
  Di default la card mostra titolo/domanda, area e **testo**. Nella pagina di personalizzazione
  (A4) l'utente può accorciare il testo o nasconderlo. Se il testo è lungo, gestire il troncamento
  o la scelta di un estratto.
- **Achievement: dopo la v1**, progettati per tutta l'app; con riflessioni libere il criterio cambia
  (es. "N riflessioni in un'area").
- **Decisioni su elenco e "Vedi riflessione":**
  - L'elenco sta nella **sezione Riflessioni di ogni area** (`AreaReflectionsScreen`), quindi è già
    raggruppato per area; non c'è un elenco globale nel menu.
  - "Vedi riflessione" a tutta pagina, sul modello di "Vedi stella", con i pulsanti in basso:
    **condividi, modifica, elimina**. **Niente Fly**: le riflessioni non hanno ancora un
    corrispettivo nella Galaxy (vedi le nebulose, dopo la v1).
  - **Elimina** è definitivo, senza archivio (in sync diventa un tombstone, vedi A2).
  - Ordine nell'elenco di un'area: dalla più recente (confermato).
- [x] Costruire: modello, elenco per area con "nuova riflessione" (libera o da suggerimento),
      "Vedi riflessione", migrazione delle risposte esistenti, condivisione come card.

### Registro di A3

- 19 ottobre 2026: nuova entità `Reflection` con UUID, titolo, testo, area, origine,
  date e tombstone. Elenco per area dalla più recente, creazione libera o da suggerimento,
  dettaglio a tutta pagina con condividi/modifica/elimina, nessun Fly né archivio.
  Conferma per scartare modifiche, campi obbligatori e gestione degli errori di salvataggio.
- Schema locale 4: le risposte precedenti diventano riflessioni con il titolo della domanda
  nella lingua corrente. Testo, date, dati aggiuntivi e tombstone vengono conservati;
  journal e ripresa dopo errori mantengono gli UUID stabili. Seed di esempio aggiornato.
- Analisi pulita e **104 test mirati superati**: migrazioni, repository, flussi UI,
  card con testi lunghi, sezioni d’area, seed e statistiche collegate.
  Verifica manuale e nuove build su dispositivo ancora da fare insieme ad A4.

## A4. Pagina di personalizzazione della scheda da condividere

- [~] Ogni volta che si condivide qualcosa (vittoria, obiettivo, stella accesa, pulsar,
      costellazione, contenuto d'area, riflessione) si apre **la pagina che oggi è nel Share Lab**
      (`lib/screens/share_composer_screen.dart` e relativi part; il lab è ora un wrapper di sviluppo). Il tipo di contenuto non è più
      un parametro che si sceglie: è automatico in base a ciò da cui si preme "Condividi".
- [~] Sostituisce l'attuale flusso di anteprima (`share_preview_screen.dart`); il Share Lab come
      strumento di sviluppo resta dietro `kDevTools`.
- [x] Di default la card di una riflessione mostra titolo/domanda, area e testo (vedi A3).

### Registro di A4 e punto di ripresa

- 19 ottobre 2026: estratti pagina, controlli e layout del Share Lab in un composer comune.
  `showSharePreview` apre il nuovo composer per tutti i chiamanti esistenti. Il tipo viene
  ricavato dalla card selezionata, senza selettore pubblico. `ShareContent` conserva una
  fotografia dei dati reali: nessuna scrittura sui repository quando si personalizza la card.
- Il lab conserva soltanto il wrapper con dati dimostrativi dietro `kDevTools`; i vecchi
  `share_lab_page.dart` e `share_lab_layouts.dart` sono diventati i part `share_composer_*`.
  Il vecchio widget `SharePreviewScreen` resta per compatibilità, ma il flusso pubblico
  passa dal nuovo composer.
- Titoli, descrizioni, metadati, intensità, foto e forma della costellazione provengono
  dal contenuto scelto. Le composizioni che richiedono statistiche non disponibili
  non vengono proposte. Controlli localizzati IT/EN/RO. Estratto delle riflessioni
  modificabile e testo nascondibile nella sola immagine condivisa.
- Analisi senza problemi. Test mirati del lab, delle riflessioni e della migrazione
  superati. Aggiunti test del punto d’ingresso pubblico, estratto senza modificare
  l’originale e composizioni con testi lunghi su telefono, landscape e desktop.
  I **4 test del composer pubblico sono superati**; corretto lo spazio minimo dei
  pannelli in landscape. Nessun errore di compilazione o test mirato rimasto aperto.
- 19 ottobre 2026, verifiche di ripresa concluse: audit del codice di condivisione
  (`share_composer_page.dart`): precaricamento di foto locali, remote e moodboard con
  errore esplicito, cattura PNG a pixel ratio 3 con immagine liberata a fine operazione,
  `SharePlus` con file PNG e testo, snackbar localizzato in caso di errore. `flutter analyze
  --no-pub` senza problemi; build web release e APK release ARM64 riuscite (APK circa 70 MB);
  nessun sorgente dei nove lab/sandbox né nella source map web né nello snapshot AOT Android.
  Nessun deploy. Su richiesta dell’autore l’APK è stato installato via USB sul telefono
  `c2abd67f` (aggiornamento senza perdita di dati) e avviato con force-stop + start.
- **Resta per chiudere A4:** prova manuale sul telefono della condivisione reale (foglio di
  condivisione, foto locale, riflessione con testo lungo) e, sul web, la stessa prova.
  Poi spuntare le due voci `[~]` sopra.

## A5. Pulizia residua

- [ ] **Prima della release ufficiale:** impostare `_kShowSampleDataForTesting = false` in
      `lib/screens/settings_screen.dart`. Il pulsante dei dati di esempio è stato ripristinato
      temporaneamente in Settings su richiesta dell'autore per provare la release sul telefono;
      non abilita reset né lab. Per questa piccola modifica non si ripete l'intera suite di test,
      come richiesto; si verificano analisi, compilazione e installazione.

- [x] Frame rate: scelto **Free**. Limitatore, sonde e riga "FPS Limit" eliminati dal codice.
- [ ] Ripulire il worktree di scratch `baseline` del vecchio profiling: ricontrollato il
      19 ottobre, è su un commit vecchio (`41c8a4b`) con circa 520 righe di esperimenti su
      shader della Galaxy, stella cadente e sonda dei frame, più un test. Conservato intatto:
      **decisione dell’autore** se salvarlo come patch o scartarlo.
- [x] Sound Lab: verificati in Settings i controlli pubblici della musica di sottofondo:
      riproduzione/pausa e volume, persistiti tramite `AudioService`. La scelta dei singoli
      suoni e i controlli per categoria restano nel Sound Lab di sviluppo.
- [x] Testi pubblici scritti a mano: localizzati in IT/EN/RO i quattro pulsanti di Vedi
      costellazione ("Nuova stella", "Condividi", "Modifica", "Elimina"), il gesto "Scorri",
      i tooltip per cambiare composizione nella condivisione e le azioni delle card di Sky.
      Audit dei testi delle schermate e dei widget pubblici eseguito; i testi dei lab restano
      di sviluppo. Ricontrollare i nuovi flussi quando si implementano A3 e A4.
- [x] Build pubblica senza lab: release web e APK Android ARM64 verificate senza `DEV_TOOLS`;
      nessun sorgente dei lab nella source map web o nello snapshot AOT Android.
      Corretto il mantenimento involontario dei lab nel compilato:
      ora anche i callback dei due menu della Galaxy sono condizionati a `kDevTools`.
      Rimossi dal bundle tutti gli asset della luna e `royal_symbols_preview`; i tre corpi SVG
      usati dal Moon lab sono ora costanti Dart eliminabili insieme al lab
      (`lib/debug/moon_body_svg.dart`). I file SVG originali restano nel repository.
      Nessun asset di queste due famiglie nel bundle web o nell'APK Android.
- [ ] Provare sul telefono quanto fatto in A1 non ancora visto: dock con "Gestisci", tooltip
      Galaxy, blocco nota vocale e link con una vera registrazione, statistiche vuote e scroll.

### Registro di A5

- 19 ottobre 2026, prove sul telefono: ripristinato temporaneamente il solo pulsante
  **"Genera dati di esempio"** in Settings → Strumenti di debug, anche nelle build release.
  `flutter analyze --no-pub` senza problemi; APK release ARM64 ricostruito, aggiornato via USB
  sul telefono e avviato. Suite di test non ripetuta, su richiesta esplicita per questa piccola
  modifica. La rimozione del pulsante prima dell'uscita ufficiale resta una voce aperta di A5.
- 19 ottobre 2026: `flutter analyze --no-pub` senza problemi. Suite mirata conclusiva:
  **44 test superati, 3 già esclusi** perché la vista elenco di Sky è nascosta. Coperti Moon,
  sandbox, condivisione, card di Sky, azioni e layout di Vedi costellazione, preferenze audio.
  Aggiornata l'aspettativa del test del gesto alla dicitura localizzata.
- Release web: `flutter build web --release --source-maps --no-pub` riuscita; controllati
  `build/web/main.dart.js.map` e gli asset. Nessun sorgente di lab, Moon o sandbox incluso.
  Le source map servono alla verifica locale; non è stato effettuato un deploy.
- Release Android: `flutter build apk --release --target-platform android-arm64 --analyze-size
  --code-size-directory=build/release-audit --no-pub` riuscita (APK circa 66 MB).
  Controllati `build/release-audit/snapshot.arm64-v8a.json` e il contenuto dell'APK:
  nessun sorgente dei lab e nessun asset di Moon o `royal_symbols_preview`.
  APK costruito per la verifica locale, non installato sul telefono né pubblicato.
- Avvisi della toolchain da tenere presenti: il build web segnala il font opzionale
  CupertinoIcons assente; la build Android segnala l'uso del vecchio plugin Kotlin in
  `flutter_timezone`. Non sono stati aggiornati pacchetti durante A5.

## A6. Account e sync nell'app (dipende da B1–B3)

- [ ] Impostazioni: si sincronizzano tutte **tranne la qualità della Galaxy e il volume audio**
      (restano per dispositivo).
- [ ] ⭐ **Blocco app e promemoria sul web**: vuoi portarli anche sul web. Da parlarne prima di
      costruire: il PIN è semplice; l'impronta sul web richiederebbe un metodo diverso (passkey o
      WebAuthn); il promemoria giornaliero nel browser richiede il permesso per le notifiche e un
      servizio di notifiche push (Firebase Cloud Messaging), che funziona solo se il browser lo
      permette. Da decidere anche se PIN e orario del promemoria si sincronizzano tra i dispositivi.
- [x] **Pagina di login obbligatoria (19 ottobre sera, su richiesta dell’autore):** su
      browser e su Android, prima di tutto (`lib/screens/login_screen.dart`,
      `lib/auth/auth_gate.dart`). Stile della landing (stesso sfondo con velo blu e stelle
      ferme, titolo grande con la seconda riga in oro — “Anche il buio / ha le sue stelle.” —,
      testo azzurro-grigio, marchio in alto a sinistra, lingue IT / EN / RO in alto a destra,
      pulsante oro a pillola su Android; sul web il pulsante lo disegna Google, nero a pillola,
      e non si può cambiare). Sequenza: splash → login (se non c’è un account) → blocco con
      PIN, solo al riavvio con l’account già presente (dopo un login appena fatto non si
      chiede) → Galaxy. Uscendo si torna al login chiudendo tutte le pagine aperte. Se Firebase
      non parte (web offline) ma c’era un accesso, l’app si apre comunque; altrimenti il login
      mostra “Riprova”. Verificata nel browser in locale (porta 5000, già origine autorizzata)
      senza premere il pulsante; 12 test nuovi (`login_gate_test.dart`), suite **629 superati,
      3 esclusi**, analisi pulita, build web e APK debug riuscite. **Da provare a mano:** accesso
      reale su Android e web, con PIN attivo e senza. **Aperto:** l’onboarding dopo il primo
      accesso (A7); la musica di sottofondo parte già sulla pagina di login.
- [x] **Versione vecchia dalla cache del browser (scoperto il 19 ottobre sera):** l’autore, dal
      telefono, è entrato in Galaxy senza login dopo splash e richiesta dell’APK. Causa:
      Cloudflare serviva `main.dart.js` con `Cache-Control: max-age=14400` (4 ore), quindi il
      browser riusava la copia precedente al login. Il sito pubblicato era corretto (verificato
      con un browser pulito). Correzione: `web/_headers` (`Cache-Control: no-cache` per tutto,
      che il browser traduce in una richiesta con ETag e, se nulla è cambiato, una risposta 304).
      Il service worker di Flutter è già quello che si autodisinstalla, non c’entra. Chi ha già
      la copia vecchia deve ricaricare senza cache o cancellare i dati del sito, una volta sola.
      **Seconda causa, trovata subito dopo:** sul dominio `my.innerstars.app` Cloudflare
      sovrascriveva comunque le intestazioni con l’impostazione di zona “Browser Cache TTL: 4
      ore” (sul dominio tecnico `pages.dev` la correzione funzionava già). Con il permesso
      dell’autore, impostata la zona `innerstars.app` su **“Respect Existing Headers”**; verificato
      con `curl`: ora `main.dart.js`, `flutter_bootstrap.js` e `index.html` rispondono
      `Cache-Control: no-cache`. Si può rimettere a 4 ore dalla stessa pagina (Caching →
      Configuration), ma tornerebbe il problema.
- [x] **Web: “Exit the App?” non sempre sul telefono (segnalato dall’autore il 19 ottobre
      sera; risolto: l’autore ha confermato che ora funziona sul telefono):** sul PC il tasto Indietro del browser chiede sempre conferma, su Chrome Android non
      sempre. Il meccanismo (`lib/utils/web_back_guard_web.dart`) aggiunge voci alla cronologia
      al primo tocco; se quel tocco arrivava quando la cronologia non era sulla voce di Flutter,
      il codice rinunciava per tutta la sessione. Ora aspetta il tocco successivo. **Non
      verificato sul telefono**: da riprovare dopo l’aggiornamento e, se persiste, descrivere
      quando non chiede (subito all’apertura? dopo aver usato l’app? gesto o pulsante?).
- [~] Pannello Account in Settings. **Decisioni dell’autore (19 ottobre):** prima del login solo
      il pulsante “Accedi con Google” e una frase (i dati restano sul dispositivo, accedendo si
      sincronizzano); al primo sync con dati sia locali sia cloud si **uniscono
      automaticamente** (record più recente, nessuna scelta richiesta); all’uscita (logout) i
      dati **restano sul telefono**; cancellazione in **due voci distinte**: “Elimina dati su
      questo dispositivo” (sempre) e, da loggati, “Elimina account e dati cloud” (richiesta
      degli store), entrambe con conferma rossa.
      **Fatto:** `lib/widgets/account_panel.dart` sotto il profilo in Settings, con
      `AuthScope`/`AuthService` creati in `main.dart` (inerti finché Settings non lo mostra);
      stato non connesso (frase + pulsante Google; sul web il pulsante renderizzato da Google
      `google_sign_in_web`), connesso (nome, email, “Esci” grigio e nota) e “non disponibile”;
      testi IT/EN/RO; 6 test (`account_panel_test.dart`); suite **590 test superati, 3 esclusi**,
      analisi pulita, build web release riuscita. **Da provare a mano:** accesso reale su
      Android e sul web (`my.innerstars.app`).
      **Resta:** le due voci di cancellazione. Vanno fatte insieme a `SyncService`, perché i
      `clear()` attuali scrivono tombstone che una sync propagherebbe al cloud: “su questo
      dispositivo” dovrà rimuovere i dati senza tombstone (e quindi tornare con la sync),
      mentre “account e dati cloud” cancella Firestore e l’utente (con ri-autenticazione).
      Finché non ci sono, in release non esiste modo di cancellare i dati (Reset resta in sviluppo).
- [ ] UI in Settings (Quick Settings restano nascoste): Accedi con Google, account, "Sincronizza
      ora", ultimo sync, Disconnetti, **Elimina account e dati**. Dialog del primo sync quando
      locale e cloud hanno entrambi dati (Cancel grigio).

## A7. Onboarding

- [ ] ⭐ **Punto aperto**: da pensarci meglio, se ne riparla più avanti. Un onboarding fatto bene per chi apre l'app la prima volta. Da discutere prima di
      costruirlo: cosa deve capire in pochi secondi (stella, costellazione, area), se è una breve
      sequenza di schermate o guidata dentro il cielo, se si salta, se si può rivedere da Settings.
      Le vecchie `OnboardingScreen` e `MetaphorScreen` sono parcheggiate (`_kShowOnboarding`) e il
      loro testo può servire da punto di partenza. Si lega ai tutorial `hint_kit` (parte C).

---

# PARTE B – Infrastruttura, sync e store

Da fare dopo la parte A (tranne i passi tuoi di B1, che puoi anticipare quando vuoi).

## B1. Cose da fare tu (nell'ordine)

1. [x] Comprare `innerstars.app` su Cloudflare Registrar (già registrato nelle decisioni).
2. Cloudflare Pages: due progetti, uno per la landing (`innerstars.app`, `www`) e uno per la web
   app (`my.innerstars.app`).
   - [x] **Landing** (19 ottobre, fatto con l’autore nel browser): progetto `innerstars-landing`
     collegato al repo `inner_stars` (accesso GitHub limitato a quel solo repo), branch `main`,
     root `landing`, build `npm run build`, output `dist`. `astro.config.mjs` usa la radice con
     `CF_PAGES` e il sottopercorso su GitHub Pages. Online su `innerstars-landing.pages.dev`.
     Collegati `innerstars.app` e `www.innerstars.app` (CNAME su Cloudflare DNS); il dominio
     principale risponde già con la landing, i certificati possono impiegare ancora un po’.
     I link “Prova” della landing puntano ora a `https://my.innerstars.app/`.
   - [x] **Web app** (19 ottobre): Cloudflare non ha Flutter nella build, quindi la compila
     GitHub Actions (`.github/workflows/deploy-app-cloudflare.yml`, `--base-href /`) e la carica
     con `wrangler` nel progetto Pages `innerstars-app`. Segreti del repo:
     `CLOUDFLARE_API_TOKEN` (token limitato a Pages: Edit, creato dall’autore) e
     `CLOUDFLARE_ACCOUNT_ID`. Prima esecuzione riuscita; `my.innerstars.app` collegato e
     servito (200, splash dell’app caricato). **Resta:** prova manuale dell’app completa su
     `my.innerstars.app`; vecchio workflow GitHub Pages (`deploy-web.yml`) ancora attivo
     da ritirare quando sarà sicuro (B2, Hosting).
3. Progetto Firebase: abilitare Authentication → Google; creare Firestore in produzione, regione `eur3`.
   - [x] **Fatto il 19 ottobre con l’autore nel browser.** Progetto `Inner Stars`
     (ID `inner-stars-5e6d6`, numero `331506513097`), piano **Spark**; Gemini e Google Analytics
     disattivati alla creazione (si possono attivare dopo). Authentication con **Google**
     abilitato (nome pubblico “Inner Stars”, email di supporto dell’autore). Firestore
     **(default)**, edizione Standard, **eur3**, modalità produzione (tutto negato finché non
     scrivo le regole in B2). Backup programmati non attivati: richiedono Blaze.
   - [x] **Dominio autorizzato `my.innerstars.app` — deciso il 19 ottobre: niente upgrade.** La
     console non lascia modificare la lista dei domini di Firebase senza l’upgrade a Identity
     Platform. L’upgrade è fattibile anche su Spark e senza carta, ma impone un limite nuovo di
     **3.000 utenti attivi al giorno** (senza limite solo su Blaze, che richiede una carta) e non
     è reversibile. L’autore ha deciso di non farlo: il login Google usa `google_sign_in`
     (Android e web) più `signInWithCredential`, senza il popup di Firebase, quindi la lista dei
     domini di Firebase non entra in gioco. Sul web l’origine `https://my.innerstars.app` va
     autorizzata come “Origine JavaScript autorizzata” del client OAuth web nella Google Cloud
     Console (gratis). **Da verificare alla prima prova reale sul web.** One Tap non serve.
4. Registrare le app in Firebase: Android (`app.innerstars` + SHA-1 debug e release) e Web
   (`my.innerstars.app` e `localhost` tra i domini autorizzati). iOS (`app.innerstars`) più avanti.
   - [x] Android `app.innerstars` registrata (ID app `1:331506513097:android:1b30e1073bb8f5b6694918`)
     con l’**SHA-1 debug** (`AA:FB:B5:03:…:83:A2`). **Manca l’SHA-1 di release**, perché la
     release è ancora firmata con la chiave debug (vedi B4, firma Android).
   - [x] Web registrata come “Inner Stars Web” (ID `1:331506513097:web:477a75d3fa3eb360694918`),
     senza Firebase Hosting (il sito sta su Cloudflare). Il dominio autorizzato resta aperto (3).
5. Passarmi i file di configurazione (`google-services.json`, `GoogleService-Info.plist`, config web).

## B2. Lavoro tecnico (in ordine)

- [~] Livello di sync astratto: fatti `lib/sync/merge.dart` (puro: ultima scrittura vince,
      a parità di orologio il tombstone vince, poi ordine canonico deterministico),
      `lib/sync/remote_store.dart` (`RemoteStore` + `InMemoryRemoteStore` con offline simulato)
      e `lib/sync/local_collection.dart` (`exportChangesSince`, `applyRemote` che conserva
      l’orologio remoto, `syncCollection`). 11 test superati (`test/sync`), analisi pulita.
      Collegati i sette repository a elenco (stelle, progetti, abitudini, check-in, cicli,
      forme, riflessioni) tramite il mixin `SyncableRepository` (`syncName`,
      `syncCollection`, `applyRemote` che notifica solo se qualcosa cambia; le forme ora sono
      un `ChangeNotifier`). Suite completa: **576 test superati, 3 esclusi**, analisi pulita.
      Aggiunte le collezioni a mappa: `LocalCollection.keyedMap` (visioni d’area, moodboard;
      i valori legacy stringa contano come i più vecchi) e `LocalCollection.single` (desiderio),
      con la stessa interfaccia `SyncCollection`; anche questi tre repository usano il mixin.
      Impostazioni: `lib/sync/settings_collection.dart`, un record per chiave `settings.*` /
      `audio-*`; i cambi sono rilevati confrontando col valore visto l’ultima volta e datati
      al momento del rilevamento (al più al prossimo sync), così i 43 setter non cambiano.
      Esclusi per dispositivo: qualità Galaxy, tutti i volumi, flag di migrazione. PIN e blocco
      app non sono inclusi (decisione aperta in A6). Suite completa: **584 test superati,
      3 esclusi**, analisi pulita.
      **Restano:** `SyncService` con Firebase (dipende da B1); chiamare il rilevamento delle
      impostazioni anche in pausa/chiusura; far ascoltare alla UI i repository dopo un
      `applyRemote` (visioni, desiderio e moodboard ora sono `ChangeNotifier` ma le
      schermate non li ascoltano ancora); riprendere le risposte vecchie alle domande se servono.
- [~] **Collegamento Firebase — stato al 19 ottobre sera.** Fatto: pacchetti `firebase_core` 5,
      `firebase_auth` 7, `cloud_firestore` 7, `google_sign_in` 7.2; plugin Gradle
      `com.google.gms.google-services` 4.4.4; `android/app/google-services.json` **ricostruito
      a mano** dai valori della Cloud Console (il browser integrato non scarica file; contiene
      chiave Android, client OAuth Android con SHA-1 debug e client web); `lib/firebase_options.dart`
      (Android e web); `lib/auth/auth_service.dart` (`AuthService`: inizializza Firebase e
      Google Sign-In solo alla prima necessità, scambia l’ID token con `signInWithCredential`,
      `signInWithGoogle` per Android, eventi di Google per il web) **non ancora usato da nessuna
      schermata**, quindi l’app e la build in prova non cambiano. `firestore.rules`,
      `firebase.json` e `.firebaserc` nel repo; **regole pubblicate nella console** (solo
      `users/{uid}/**` e solo con `request.auth.uid == uid`; tutto il resto negato).
      Origine `https://my.innerstars.app` aggiunta al client OAuth web in Google Cloud
      (accettati i Termini di servizio di Google Cloud; prova gratuita da 300 $ **non** attivata).
      Verifiche: analisi pulita, 584 test superati (3 esclusi), `flutter build apk --debug`
      arm64 e `flutter build web --release` riusciti. Avviso nuovo della toolchain: `firebase_auth`
      e `firebase_core` applicano ancora il vecchio plugin Kotlin, come `flutter_timezone`.
      **Restano:** schermata Account (⭐ A6) che usi `AuthService` con il pulsante Google sul web;
      `SyncService` con listener Firestore e push debounced; test delle regole sull’emulatore
      (serve Java e `firebase-tools`); SHA-1 di release in Firebase quando esisterà il keystore;
      prova reale del login sul web e su Android; eventuale `google-services.json` scaricato dalla
      console al posto di quello ricostruito.
- [~] **`SyncService` — fatto il 19 ottobre sera, da provare con un accesso reale.**
      **Decisione dell’autore:** la sincronizzazione è solo automatica, **niente pulsante
      “Sincronizza ora”**; il pannello Account mostra soltanto “ultimo aggiornamento”
      (o “in corso”, o l’errore con nuovo tentativo).
      Come funziona (`lib/sync/sync_service.dart`, `firestore_remote_store.dart`): parte
      da sola dopo l’accesso, 5 s dopo una modifica locale, al ritorno in primo piano, alla
      messa in secondo piano e ogni 2 minuti. Un errore (offline, timeout di 30 s) non blocca
      l’app né tocca i dati locali: riprova con attesa crescente (30 s … 10 min). Documenti
      `users/{uid}/{collezione}/{id}` con il record intero come testo JSON nel campo `data`
      (Firestore rifiuta le liste annidate), più `id`, `updatedAt`, `deleted` e `_syncedAt`.
      Undici collezioni: stelle, progetti, abitudini, check-in, cicli, forme, riflessioni,
      visioni d’area, desiderio, moodboard e impostazioni (queste ricaricate nell’app).
      **Correzione di progetto emersa lungo la strada:** il punto di ripresa dello scarico ora
      segue l’orario del **server** (`_syncedAt`), non l’orologio dei record; l’invio segue
      l’orologio del dispositivo. Prima un dispositivo con l’orologio indietro avrebbe
      scritto modifiche che gli altri non avrebbero mai scaricato (test dedicato).
      Al riavvio l’app ricorda che c’era un accesso (`auth.wasSignedIn`) e riattiva Firebase
      da sola. Test: 35 in `test/sync` + 7 del pannello; suite **605 superati, 3 esclusi**,
      analisi pulita, build web release e APK debug arm64 riuscite.
      **Correzioni chieste dall’autore (19 ottobre sera, fatte):**
      - **Ogni account ha i suoi dati, mai mescolati.** Il dispositivo ricorda a quale account
        appartengono (`data.owner`). Il primo account che si connette adotta ciò che era stato
        fatto prima del login (unione automatica, come deciso); se poi entra un altro
        account, i dati dell’altro vengono **sostituiti** da quelli del nuovo (rimossi dal
        telefono, impostazioni sincronizzate comprese) e non salgono mai nel suo cloud; il
        cloud del primo account non viene toccato. Senza modo di svuotare, la sync si rifiuta
        di partire. Prima dell’uscita l’app fa un ultimo aggiornamento (15 s al massimo) perché
        nulla resti solo sul telefono. Dopo “Elimina account” i dati diventano adottabili dal
        prossimo account. Limite noto: ciò che si crea da disconnessi *dopo* l’uscita di un
        account e prima che entri un altro account diverso viene sostituito insieme al resto.
      - **Promemoria:** dopo che arriva da un altro dispositivo, viene ri-armato subito
        (o annullato) invece che al prossimo avvio.
      - **Impostazioni:** ogni cambio avvisa il servizio, che aggiorna dopo ~5 s; la data è
        quindi quella della modifica con scarto di pochi secondi.
      - **Aggiornamenti quasi in tempo reale:** oltre al giro ogni 2 minuti, l’app ascolta
        Firestore (un solo documento per collezione, quindi una lettura per modifica): quando
        un altro dispositivo scrive, questo scarica in ~2 s.
      **Note e rischi da tenere presenti:**
      - Media (foto, audio) non ancora sincronizzati: serve il blocco “Media” sotto.
      - Costo: con i limiti gratuiti Spark conta ogni documento letto; i punti di ripresa
        tengono le letture basse, ma da misurare con un uso reale.
      **Cancellazione (fatta il 19 ottobre sera):** sezione “Dati” di Settings sempre visibile
      (anche in release): “Elimina dati su questo dispositivo” (`lib/data/local_data_wipe.dart`:
      rimuove i record senza tombstone, più foto, registrazioni e file del moodboard; restano
      impostazioni, blocco app e marcatori di schema; per un account connesso i dati tornano al
      prossimo aggiornamento perché si azzerano i punti di ripresa) e, solo da loggati,
      “Elimina account e dati cloud” (cancella ogni collezione su Firestore, poi l’utente
      Firebase e l’accesso Google; prima controlla l’accesso recente e, su Android, chiede di
      nuovo l’account; sul web chiede di uscire, rientrare e riprovare). Sync in pausa durante
      entrambe. 610 test superati.
      **Prova reale del 19 ottobre sera (autore, web):** accesso con l’account Google personale
      riuscito su `my.innerstars.app`; creata una costellazione e una vittoria, aperta una finestra
      in incognito (secondo “dispositivo”) con lo stesso account e i dati sono arrivati.
      Visto in console: utente in Authentication e, sotto `users/{uid}`, le collezioni
      sincronizzate. **Restano da provare:** Android (la build installata è ancora quella
      senza login), secondo account Google sullo stesso browser (deve vedere solo i suoi dati),
      offline, cancellazione dati/account; test delle regole sull’emulatore; una schermata che
      spieghi un errore persistente.
      Struttura `users/{uid}/<collezione>/{uuid}`. `SyncService` con listener per collezione,
      push debounced, ripresa al `resumed`, stato e nessun crash offline.
      Regole di sicurezza: ognuno accede solo a `users/{uid}/**`, con test sull'emulatore.
      Attenzione ai limiti gratuiti: query con `updatedAt > ultimo visto`.
- [ ] Media: foto principale + audio (60 s) + foto di moodboard su Cloud Storage, con
      compressione prima dell'upload, cache locale (scarica solo quando serve), coda con
      ritenti, rimozione dei file orfani. Richiede il piano Blaze con avviso di budget; verificare
      prima le quote gratuite per la regione scelta.
- [ ] Hosting: nuovo workflow per Cloudflare Pages; la web app alla radice di `my.innerstars.app`
      (senza `--base-href /inner_stars/app/`). Il workflow attuale è `.github/workflows/deploy-web.yml`.

## B3. Legale

- [ ] Pagine `/privacy` e `/terms` nella landing, in IT/EN/RO, scritte insieme.
- [ ] Cancellazione account che elimina anche i dati cloud (Firestore e Storage).
- [ ] **Cancellare i propri dati è un requisito, non un extra** (gli store lo richiedono): vedi A6.
- [ ] Consent screen Google: homepage `https://innerstars.app`, privacy `https://innerstars.app/privacy`,
      dominio autorizzato `innerstars.app`.

## B4. Store e pubblicazione

- [x] **Piattaforme della prima uscita**: Android e web (landing + web app). iOS in futuro. Costo: Play Store 25 € una tantum.
- [ ] **APK scaricabile dalla landing — decisione dell’autore (19 ottobre sera): non
      aggiornarlo ora.** Il pulsante della landing scarica `inner-stars.apk` dalla release
      GitHub `v0.1.0+2`, che è del **4 ottobre**: prima di login, sincronizzazione e cambio di
      application id, quindi vecchio. Verrà sostituito quando l’app sarà su Play Store,
      mettendo **direttamente il link di Play** nella landing (`Landing.astro`, `Journey.astro`
      e `SiteHeader.astro` puntano oggi all’APK GitHub; la richiesta di scaricare l’APK dal
      browser sul telefono si rivedrà allo stesso momento). Nota tecnica: un APK costruito
      fuori da questo PC non funzionerebbe con il login Google finché la firma di release non
      è registrata in Firebase (l’SHA-1 di release manca, vedi sotto), e le build di release
      contengono ancora il pulsante temporaneo dei dati di esempio (A5).
- [ ] **Firma Android per la release**: verificare che la chiave di firma (keystore) esista, sia
      salvata al sicuro e che l'impronta SHA-1 di release sia registrata in Firebase.
      Controllo del 19 ottobre: `android/app/build.gradle.kts` firma ancora la release
      con la configurazione debug; le build locali di A5 non sono pronte per lo store.
- [ ] **Requisiti degli store**: privacy policy online, scheda dei dati raccolti, classificazione per
      età, screenshot, icona e splash definitivi.
- [ ] **Segnalazione degli errori** con Firebase Crashlytics (deciso): Android coperto. Il plugin
      Crashlytics non supporta il web: per la web app valutare più avanti un altro strumento
      (es. Sentry) o rinunciare nella prima uscita.

---

# PARTE C – Rifinitura finale

- [ ] ⭐ Decidere cosa resta nell'app, poi rivedere tutti i tutorial `hint_kit` (dock, menu e
      statistiche sono cambiati).
- [ ] Aggiornare la TRB (rimuovere voci risolte, aggiungere quelle nuove).
- [ ] Controllo build release su telefono (shader costellazione: Impeller/Skia, vedi memoria).
- [ ] Controllo web: percorsi, cache, dominio.
- [ ] Scheda store e screenshot.

## Versione

- [ ] Numero di versione dell'app in `pubspec.yaml` (`version: nome+build`): oggi `0.1.0+2`. È solo
      un numero nel file, non dipende da GitHub né dagli store: finché l'app non è caricata su Play,
      si può impostare liberamente a **`1.0.0+1`** poco prima del primo caricamento. Da lì il
      numero di build (dopo il `+`) cresce a ogni caricamento. Il tag git `v0.1.0+2` resta com'è.

## Ordine consigliato

1. A5 (pulizia residua) e, in parallelo, i tuoi passi B1.
2. A2 (dati pronti alla sync).
3. A3 (Riflessioni) e A4 (personalizzazione della scheda).
4. B2 e A6 (sync, media, account).
5. B3 e B4 (legale e store), poi la parte C.

## Idee per dopo la v1

- **Nebulose**: le riflessioni diventeranno un nuovo tipo di elemento nel cielo della Galaxy (le
  nebulose), dal quale potranno nascere le stelle di oggi. Allora le riflessioni avranno anche il
  loro Fly. Da fare **dopo l'uscita della prima versione**.

- Pacchetti di suoni a pagamento come contenuti extra (Sound Lab nascosto per ora).
- Stella cadente con desideri a tempo e storico.
- Amici come galassie lontane.
- Video nella moodboard, altri allegati, cifratura opzionale, esportazione JSON manuale.
- Sistema di achievement per tutta l'app (riflessioni incluse).
