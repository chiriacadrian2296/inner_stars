# Piano di rilascio – Inner Stars

Documento di lavoro: si procede per step, in ordine, spuntando le voci. Aggiornare questo file
quando una decisione cambia.

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
3. Tutorial: cosa resta nell'app prima di rivederli (parte C).

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

- [ ] UUID v4 (`uuid`) per Star, Project, Habit, HabitCompletion, HabitCycle, StarsShape;
      riferimenti incrociati a stringa (~330 occorrenze in 34 file).
- [ ] Migrazione una tantum degli id esistenti (modello: `lib/data/legacy_constellation_migration.dart`),
      idempotente, con versione schema.
- [ ] `updatedAt` non nullo, aggiornato nel punto unico di scrittura
      (`lib/data/repository_write.dart` e gli `_saveAll`).
- [ ] Flag `deleted` (tombstone) al posto delle cancellazioni vere: progetti, completion, cicli,
      forme, risposte/riflessioni, visioni, moodboard e reset. Le UI filtrano `deleted`.
- [ ] Dati per area (visioni, desiderio): record `{value, updatedAt, deleted}` per chiave.
- [ ] Moodboard: un record per elemento con `{updatedAt, deleted}`, non più una lista JSON per
      area. Rimuovere la possibilità di aggiungere video; limite rigido di **12 elementi per area**,
      anche in locale (la UI non permette di aggiungerne oltre).
- [ ] Test di migrazione e tombstone.

## A3. Nuova funzione: Riflessioni

Oggi: 4 domande preimpostate per area, ne scegli una e rispondi. Obiettivo: riflessioni libere.
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
    **condividi, modifica, elimina**. Come negli altri "Vedi", Fly (torna alla Galaxy) resta l'ultima
    azione a destra, da sola.
  - **Elimina** è definitivo, senza archivio (in sync diventa un tombstone, vedi A2).
  - Ordine nell'elenco di un'area: dalla più recente (da riconfermare vedendola).
- [ ] Costruire: modello, elenco per area con "nuova riflessione" (libera o da suggerimento),
      "Vedi riflessione", migrazione delle risposte esistenti, condivisione come card.

## A4. Pagina di personalizzazione della scheda da condividere

- [ ] Ogni volta che si condivide qualcosa (vittoria, obiettivo, stella accesa, pulsar,
      costellazione, contenuto d'area, riflessione) si apre **la pagina che oggi è nel Share Lab**
      (`lib/screens/share_lab_screen.dart`, `share_lab_page.dart`). Il tipo di contenuto non è più
      un parametro che si sceglie: è automatico in base a ciò da cui si preme "Condividi".
- [ ] Sostituisce l'attuale flusso di anteprima (`share_preview_screen.dart`); il Share Lab come
      strumento di sviluppo resta dietro `kDevTools`.
- [ ] Di default la card di una riflessione mostra titolo/domanda, area e testo (vedi A3).

## A5. Pulizia residua

- [x] Frame rate: scelto **Free**. Limitatore, sonde e riga "FPS Limit" eliminati dal codice; resta da ripulire il worktree di scratch `baseline` del vecchio profiling (`git worktree list`).
- [ ] Sound Lab: verificare che i controlli audio che servono all'utente (volume, musica di
      sottofondo) esistano anche fuori dal Sound Lab, ora che nelle build pubbliche non c'è.
- [ ] Testi scritti a mano in italiano da portare nelle stringhe localizzate: i dock di Vedi
      costellazione ("Nuova stella", "Condividi", "Modifica", "Elimina") e ogni altra schermata che
      resta visibile in release.
- [ ] Build pubblica senza lab: con `kDevTools` falso il codice dei lab viene tolto in release; verificare costruendo la release senza `DEV_TOOLS` e controllando anche che non restino asset usati solo dai lab.
- [ ] Provare sul telefono quanto fatto in A1 non ancora visto: dock con "Gestisci", tooltip
      Galaxy, blocco nota vocale e link con una vera registrazione, statistiche vuote e scroll.

## A6. Account e sync nell'app (dipende da B1–B3)

- [ ] Impostazioni: si sincronizzano tutte **tranne la qualità della Galaxy e il volume audio**
      (restano per dispositivo).
- [ ] ⭐ **Blocco app e promemoria sul web**: vuoi portarli anche sul web. Da parlarne prima di
      costruire: il PIN è semplice; l'impronta sul web richiederebbe un metodo diverso (passkey o
      WebAuthn); il promemoria giornaliero nel browser richiede il permesso per le notifiche e un
      servizio di notifiche push (Firebase Cloud Messaging), che funziona solo se il browser lo
      permette. Da decidere anche se PIN e orario del promemoria si sincronizzano tra i dispositivi.
- [ ] ⭐ Pannello Account in Settings: cosa mostra prima del login; e come cancellare i dati locali
      in release finché non c'è il login ("Reset all data" è ora solo in sviluppo).
- [ ] UI in Settings (Quick Settings restano nascoste): Accedi con Google, account, "Sincronizza
      ora", ultimo sync, Disconnetti, **Elimina account e dati**. Dialog del primo sync quando
      locale e cloud hanno entrambi dati (Cancel grigio).

---

# PARTE B – Infrastruttura, sync e store

Da fare dopo la parte A (tranne i passi tuoi di B1, che puoi anticipare quando vuoi).

## B1. Cose da fare tu (nell'ordine)

1. Comprare `innerstars.app` su Cloudflare Registrar.
2. Cloudflare Pages: due progetti collegati a GitHub, uno per la landing (`innerstars.app`, `www`)
   e uno per la web app (`my.innerstars.app`).
3. Progetto Firebase: abilitare Authentication → Google; creare Firestore in produzione, regione `eur3`.
4. Registrare le app in Firebase: Android (`app.innerstars` + SHA-1 debug e release) e Web
   (`my.innerstars.app` e `localhost` tra i domini autorizzati). iOS (`app.innerstars`) più avanti.
5. Passarmi i file di configurazione (`google-services.json`, `GoogleService-Info.plist`, config web).

## B2. Lavoro tecnico (in ordine)

- [ ] Livello di sync astratto (`RemoteStore` con versione finta per i test), `exportChangesSince`
      / `applyRemote` nei repository, `lib/sync/merge.dart` puro con test (conflitti, tombstone,
      idempotenza).
- [ ] Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`.
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
- [ ] **Firma Android per la release**: verificare che la chiave di firma (keystore) esista, sia
      salvata al sicuro e che l'impronta SHA-1 di release sia registrata in Firebase.
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

## Ordine consigliato

1. A5 (pulizia residua) e, in parallelo, i tuoi passi B1.
2. A2 (dati pronti alla sync).
3. A3 (Riflessioni) e A4 (personalizzazione della scheda).
4. B2 e A6 (sync, media, account).
5. B3 e B4 (legale e store), poi la parte C.

## Idee per dopo la v1

- Pacchetti di suoni a pagamento come contenuti extra (Sound Lab nascosto per ora).
- Stella cadente con desideri a tempo e storico.
- Amici come galassie lontane.
- Video nella moodboard, altri allegati, cifratura opzionale, esportazione JSON manuale.
- Sistema di achievement per tutta l'app (riflessioni incluse).
