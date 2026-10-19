# Piano di rilascio – Inner Stars

Documento di lavoro: si procede per step, in ordine, spuntando le voci. Ogni sezione è
autonoma quanto possibile. Aggiornare questo file quando una decisione cambia.

Terminologia: vedi `docs/terminology.md` (Galaxy, Sky, attività, ecc.).

## 0. Decisioni prese

- Dominio `innerstars.app` (landing) e `my.innerstars.app` (web app), comprati su Cloudflare;
  hosting su Cloudflare Pages.
- Application id Android/iOS: `app.innerstars` (già applicato, `namespace` e `MainActivity` inclusi).
- Backend: Firebase Auth (Google) + Firestore, piano Spark, regione `eur3`. Custodia dei dati
  accettata, con privacy policy e cancellazione account.
- L'app resta **local-first**: SharedPreferences è il database principale, Firestore è la copia
  remota sincronizzata.
- ID migrati a **UUID**; nessun utente reale, quindi nessuna cautela particolare di migrazione.
- Media sincronizzati nella v1: foto principale di ogni vittoria, **un audio per vittoria (max 60 s)**,
  moodboard con **foto e citazioni** (niente video, limite rigido di elementi per area, anche in locale).
  Il resto dopo la v1.
- Strumenti di sviluppo (lab, dati di esempio, reset) **solo nelle build di sviluppo**.
- Comete: la frequenza attuale (`kCometPeriodScale = 0.45`) è quella definitiva.
- Tutorial: da rivedere **alla fine**, quando è deciso cosa resta nell'app.
- Sound Lab: resta per ora (serve per lavorare sull'audio), poi nascosto. Idea futura: pacchetti
  di suoni a pagamento come contenuti extra.

## 1. Pulizia per il rilascio

Obiettivo: nessuna traccia di strumenti interni nelle build pubbliche.

- [x] Introdurre un unico interruttore `kDevTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: kDebugMode)`,
      letto da una costante condivisa. Per default è acceso solo nelle build debug, come deciso;
      se vuoi vedere i lab in una build release (prova di velocità) basta `--dart-define=DEV_TOOLS=true`.
      Le build pubbliche non lo passano e restano pulite.
- [x] Dietro `kDevTools` (`lib/debug/dev_tools.dart`):
  - [x] sezione "Lab" del menu (`lib/widgets/sky_menu_drawer.dart`): Moon visual lab, Card back lab,
        Constellation lab, Share lab;
  - [x] pulsante Moon lab nel ventaglio del pulsante stella (`lib/screens/sky_screen.dart`);
  - [x] "Seed sample data" in Settings (`lib/screens/settings_screen.dart`);
  - [x] "Reset all data" in Settings (in produzione viene sostituito da "Elimina account e dati", vedi sez. 5);
  - [x] le voci già parcheggiate dietro `_kShowOtherLabEntries`.
- [~] Sonde TEMPORARY: ora dietro `kDevTools` (non rimosse, perché la scelta Free/40/30 è ancora in sospeso nella TRB). Rimuovere le sonde TEMPORARY di `lib/main.dart` (`startFrameTimingProbe()`,
      `installFrameRateLimiter()`; file in `lib/debug/`) e ripulire il worktree di scratch
      della sessione di profiling.
- [x] Settings: parcheggiati i tre pannelli segnaposto (`_kShowPlaceholderSections = false`) (Profile and Account, Customization,
      Passkey and Social) e il badge "COMING SOON". Il pannello Account torna con il login (sez. 5).
- [x] Sound Lab: resta nella versione debug (serve per lavorare sull'audio) ma **esce subito dalla
      release**: dietro `kDevTools` sia la voce nel menu sia il pulsante "open Sound Lab" in Settings
      (`settings_screen.dart` ~625) e in Quick Settings. Prima verificare che i controlli audio che
      servono all'utente (volume, musica di sottofondo) esistano anche fuori dal Sound Lab.
- [ ] Controllo localizzazione: nessuna stringa codificata a mano in italiano nelle schermate
      che restano visibili.
- [ ] Rimuovere o spostare i file dei lab fuori dalla build pubblica se pesano (valutare dopo).

## 2. Rimozioni dalla prima uscita

- [x] **Intensità nelle riflessioni.** Rimuoverla da `lib/models/reflection_answer.dart`,
      `lib/data/reflection_answer_repository.dart`, `lib/widgets/reflection_questions_section.dart`
      (slider e fulmini), `lib/debug/seed_data.dart`, `lib/debug/seed_area_content.dart` e dai test.
      `fromJson` resta tollerante verso i dati già salvati. Non toccare l'intensità di stelle,
      abitudini e cicli (è parte del cuore dell'app).
- [x] **Stella cadente** (`_kShowShootingStar = false`). Spegnere `_kShowShootingStar` e `_kShowShootingStarStudy` in
      `lib/screens/sky_screen.dart`. Il codice resta (TRB). Il desiderio non entra nella sync.
- [x] **Gestione obiettivi e abitudini fuori dalle statistiche.** La pagina esisteva già
      (`lib/screens/today_habits_screen.dart`). Il pulsante "Gestisci obiettivi e abitudini" è tolto
      da "La Tua Luce" e compare accanto ad "Aggiungi" nel dock di Vedi area, in quello di Vedi
      costellazione, nel cassetto dei tooltip di area e costellazione in Galaxy e nel menu
      (sezione Attività, sotto "Illumina il tuo cielo").
- [x] **Dettagli di "Crea vittoria".** Niente più foto secondarie né video da aggiungere. Accanto
      alla foto principale: in alto una sola nota vocale (max 1 minuto), poi tre link con icona
      fissa: canzone, posizione (Maps), sito (`StarMedia.linkKind`; i link senza tipo contano come
      sito). I dati già salvati (foto secondarie, video, più note vocali) restano leggibili nel
      lettore ma non si modificano più dal form. Codice: `StarMediaEditor(sideColumn: true)` in
      `lib/widgets/star_media_editor.dart`.
- [x] **Statistiche: tornare in alto al cambio di livello.** Quando si scende di livello nella
      pagina (area → costellazione → attività), o si sale verso aree e "tutto", la pagina deve
      scorrere fino all'inizio della prima sezione "Overview", cioè il punto in cui il pannello del
      percorso arriva in cima e resta fissato sopra il contenuto. Oggi lo scroll resta dov'era
      (`LightScreen._setScope` in `lib/screens/light_screen.dart`, `_session.scrollOffset`).
      Fatto: `_setScope` scorre fino al pannello fissato (`_titleKey`), con salto diretto se il movimento è ridotto.
- [ ] Già parcheggiati, restano fuori: amici, onboarding, schermata Metaphor, vista a lista del Sky.

## 3. Nuova funzione: Riflessioni

Oggi: 4 domande preimpostate per area, ne scegli una e rispondi. Obiettivo: riflessioni libere.

- Una **riflessione** nasce da una domanda preimpostata **oppure da zero**, con un titolo/tema
  scritto dall'utente, e un testo di sviluppo sotto. È **sempre legata a un'area**, come oggi.
  Il testo è **unico** (modificabile, senza storico).
- Elenco di tutte le riflessioni e una schermata **"Vedi riflessione"** per consultarle una a una,
  sul modello di "Vedi stella" (azioni raggruppate come in "Vedi": statistiche/modifica/archivia
  insieme, Fly ultima a destra).
- Le domande preimpostate diventano **suggerimenti** per iniziare una riflessione.
- Entità sincronizzabile: `id` UUID, `title`, `body`, area (obbligatoria), origine (suggerita o
  libera), `createdAt`, `updatedAt`, `deleted`.
- Migrare le risposte esistenti alla nuova entità.
- **Condivisione come card, già nella v1**, come per le altre cose condivisibili (composer in
  `lib/screens/share_preview_screen.dart`, `lib/widgets/share_arrangement.dart`, `shareable_*_card.dart`).
  Condividere è una scelta esplicita dell'utente e una riflessione senza testo perde di senso:
  di default la card mostra titolo/domanda, area e **testo**. Nella pagina di personalizzazione
  (sez. 3b) l'utente può accorciare il testo o nasconderlo. Se il testo è lungo, gestire il
  troncamento o la scelta di un estratto.
- **Achievement: dopo la v1**, progettati per tutta l'app (stelle, costellazioni, abitudini,
  riflessioni), non solo per le riflessioni. Con riflessioni libere il criterio cambia (es. "N
  riflessioni in un'area" al posto di "tutte le domande di un'area").

### 3b. Pagina di personalizzazione della scheda da condividere

- [ ] Una pagina unica per scegliere cosa mostrare e come, valida per tutte le card condivisibili
      (vittoria, obiettivo, stella accesa, pulsar, costellazione, contenuto d'area, riflessione).
- [ ] Da progettare insieme prima di implementare (cosa è personalizzabile per tipo di card;
      cosa include di default; anteprima).
- Ordine: dopo la sez. 4, così la nuova entità nasce già pronta alla sync.

## 4. Dati pronti per la sincronizzazione

Nessuna dipendenza esterna; si può fare subito.

- [ ] UUID v4 (`uuid`) per Star, Project, Habit, HabitCompletion, HabitCycle, StarsShape;
      riferimenti incrociati a stringa (~330 occorrenze in 34 file).
- [ ] Migrazione una tantum degli id esistenti (modello: `lib/data/legacy_constellation_migration.dart`),
      idempotente, con versione schema.
- [ ] `updatedAt` non nullo, aggiornato nel punto unico di scrittura
      (`lib/data/repository_write.dart` e gli `_saveAll`).
- [ ] Flag `deleted` (tombstone) al posto delle cancellazioni vere: progetti, completion, cicli,
      forme, risposte/riflessioni, visioni, moodboard e reset. Le UI filtrano `deleted`.
- [ ] Moodboard: un record per elemento con `{updatedAt, deleted}`, non più una lista JSON per area.
      Rimuovere la possibilità di aggiungere video; limite rigido di elementi per area (proposta: 12).
- [ ] Dati per area (visioni, desiderio): record `{value, updatedAt, deleted}` per chiave.
- [ ] Test di migrazione e tombstone.

## 5. Account, sync e hosting

### 5a. Cose da fare tu (nell'ordine)
1. Comprare `innerstars.app` su Cloudflare Registrar.
2. Cloudflare Pages: due progetti collegati a GitHub, uno per la landing (`innerstars.app`, `www`)
   e uno per la web app (`my.innerstars.app`).
3. Progetto Firebase: abilitare Authentication → Google; creare Firestore in produzione, regione `eur3`.
4. Registrare le app in Firebase: Android (`app.innerstars` + SHA-1 debug e release), iOS
   (`app.innerstars`), Web (`my.innerstars.app` e `localhost` tra i domini autorizzati).
5. Passarmi i file di configurazione (`google-services.json`, `GoogleService-Info.plist`, config web).

### 5b. Lavoro tecnico (in ordine)
- [ ] Livello di sync astratto (`RemoteStore` con versione finta per i test), `exportChangesSince`
      / `applyRemote` nei repository, `lib/sync/merge.dart` puro con test (conflitti, tombstone,
      idempotenza). Sottoinsieme delle impostazioni sincronizzate; non i flag per dispositivo
      (`app_lock.*`, `tour.*`, `audio-*`).
- [ ] Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`.
      Struttura `users/{uid}/<collezione>/{uuid}`. `SyncService` con listener per collezione,
      push debounced, ripresa al `resumed`, stato e nessun crash offline.
      Regole di sicurezza: ognuno accede solo a `users/{uid}/**`, con test sull'emulatore.
      Attenzione ai limiti gratuiti: query con `updatedAt > ultimo visto`.
- [ ] Media: foto principale + audio (60 s) + foto di moodboard su Cloud Storage, con
      compressione prima dell'upload, cache locale (scarica solo quando serve), coda con
      ritenti, rimozione dei file orfani. Richiede il piano Blaze con avviso di budget; verificare
      prima le quote gratuite per la regione scelta.
- [ ] UI in Settings (Quick Settings restano nascoste): Accedi con Google, account, "Sincronizza
      ora", ultimo sync, Disconnetti, **Elimina account e dati**. Dialog del primo sync quando
      locale e cloud hanno entrambi dati (Cancel grigio).
- [ ] Hosting: nuovo workflow per Cloudflare Pages; la web app alla radice di `my.innerstars.app`
      (senza `--base-href /inner_stars/app/`). Il workflow attuale è `.github/workflows/deploy-web.yml`.

## 6. Legale

- [ ] Pagine `/privacy` e `/terms` nella landing, in IT/EN/RO, scritte insieme.
- [ ] Cancellazione account che elimina anche i dati cloud (Firestore e Storage).
- [ ] **Cancellare i propri dati è un requisito, non un extra**: "Reset all data" è ora solo in
      sviluppo, quindi in release serve "Elimina account e dati" (e, finché non c'è il login, un
      modo per cancellare i dati locali). Gli store lo richiedono.
- [ ] Consent screen Google: homepage `https://innerstars.app`, privacy `https://innerstars.app/privacy`,
      dominio autorizzato `innerstars.app`.

## 7. Rifinitura finale

- [ ] **Decidere le piattaforme della prima uscita** (web, Android, iOS). Costi: Play Store 25 € una
      tantum, App Store 99 $/anno.
- [ ] **Firma Android per la release**: verificare che la chiave di firma (keystore) esista, sia
      salvata al sicuro e che l'impronta SHA-1 di release sia registrata in Firebase.
- [ ] **Requisiti degli store**: privacy policy online, scheda dei dati raccolti, classificazione per
      età, screenshot, icona e splash definitivi.
- [ ] **Segnalazione degli errori** (crash reporting) per sapere cosa si rompe sui telefoni degli altri.
- [ ] Provare sul telefono le modifiche non ancora viste (dock con "Gestisci", tooltip Galaxy, blocco
      nota vocale e link con una vera registrazione, statistiche vuote) e fare i commit.
- [ ] Testi scritti a mano in italiano nei dock di Vedi costellazione ("Nuova stella", "Condividi",
      "Modifica", "Elimina") da portare nelle stringhe localizzate.
- [ ] Scegliere Free/40/30 per il limite di frame rate e togliere le sonde TEMPORARY.

- [ ] Rivedere tutti i tutorial `hint_kit` una volta deciso cosa resta nell'app.
- [ ] Aggiornare la TRB (rimuovere voci risolte, aggiungere quelle nuove).
- [ ] Controllo build release su telefono (shader costellazione: Impeller/Skia, vedi memoria).
- [ ] Controllo web: percorsi, cache, dominio.
- [ ] Scheda store e screenshot.

## Ordine consigliato

1. Sez. 1 e 2 (pulizia e rimozioni): piccole, indipendenti.
2. Sez. 4 (dati pronti alla sync), in parallelo ai tuoi passi 5a.
3. Sez. 3 (Riflessioni), costruite già sull'entità sync-ready.
4. Sez. 5b e 6 (sync, media, legale).
5. Sez. 7 (rifinitura).

## Fuori dal piano (deciso)

- Backup dei dati locali / export JSON: non serve per ora, l'app la usa solo l'autore.

## Idee per dopo la v1

- Pacchetti di suoni a pagamento come contenuti extra (Sound Lab nascosto per ora).
- Stella cadente con desideri a tempo e storico.
- Amici come galassie lontane.
- Video nella moodboard, altri allegati, cifratura opzionale, esportazione JSON manuale.
- Sistema di achievement per tutta l'app (riflessioni incluse).
