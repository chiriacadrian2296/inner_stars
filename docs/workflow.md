# Come si lavora (rami, controlli, pubblicazione)

Deciso il 20 ottobre 2026. Due ambienti per ora: il proprio computer e la produzione.
Niente ramo `dev` e niente ambiente di collaudo: non ci sono ancora utenti veri. Si
riprende l’idea quando entra la prima persona che non è l’autore (vedi in fondo).

## La regola

**`main` è la produzione.** Ogni cosa che arriva su `main` pubblica da sola:

- la web app su `my.innerstars.app` (workflow `deploy-app-cloudflare.yml`, circa 3 minuti);
- la landing su `innerstars.app` (Cloudflare Pages, collegata al repository).

Per questo **non si lavora su `main`** e non ci si fa push diretti.

## Il ciclo di una novità

1. Si parte da `main` aggiornato e si crea un **ramo con un nome parlante**
   (es. `onboarding`, `sync-foto`, `fix-login`). Lo sceglie Claude, o lo dice l’autore prima
   di cominciare.
2. Si lavora e si fa commit sul ramo quanto si vuole. Un push del ramo **non pubblica nulla**:
   parte solo il workflow `Checks` (analisi e test).
3. Si prova: web in locale sulla porta 5000 (già autorizzata per il login Google), Android con
   la build di debug via USB.
4. Quando è finita e provata, **il ramo si unisce a `main`** (merge dell’intero ramo, non di
   singoli commit) e si fa push di `main`: da lì va in produzione.
5. Il ramo si cancella.

Più rami possono vivere in parallelo; ognuno si unisce a `main` quando è pronto, indipendentemente
dagli altri. Se un ramo vive a lungo, ogni tanto si riporta dentro `main` (`git merge main`) per
non allontanarsi.

## Cosa blocca gli errori

- **`Checks`** (`.github/workflows/checks.yml`): su ogni ramo diverso da `main` e su ogni pull
  request esegue `flutter analyze` e `flutter test` per l’app, e typecheck, build e test per la
  landing.
- **Il deploy della web app** esegue le stesse analisi e gli stessi test **prima** di costruire e
  pubblicare: se falliscono, non esce niente.
- **Flutter è fissato a 3.47.1** nei workflow, come sul computer dell’autore. Per cambiarlo si
  aggiorna in `checks.yml` e `deploy-app-cloudflare.yml` insieme.

## Cose di sviluppo e funzioni a metà

- Laboratori, dati di esempio e reset stanno dietro `kDevTools` (`lib/debug/dev_tools.dart`): le
  build di release non li contengono.
- Una funzione utente **non finita** resta sul suo ramo. Solo se deve stare su `main` prima
  del tempo si nasconde con una costante `false` di default (come `_kShowPlaceholderSections`).
- Il pulsante dei dati di esempio in release è un’eccezione temporanea (piano, A5): da togliere
  prima dell’uscita ufficiale.

## Se qualcosa va storto in produzione

- **Tornare indietro in un minuto:** Cloudflare conserva ogni versione. Dalla dashboard, Workers
  & Pages → `innerstars-app` → Deployments → la versione buona → *Rollback*.
- Poi si corregge su un ramo, come sopra. Se è urgente: ramo `fix-...` da `main`, test, merge.
- **Il rischio vero sono i dati.** I dati stanno nel cloud e versioni diverse dell’app convivono
  (web nuova, Android vecchia). Quindi nei modelli si **aggiungono** campi opzionali e non si
  rinominano né si tolgono quelli esistenti; un cambio più grande richiede una migrazione che
  funzioni con entrambe le versioni.

## Per dopo (quando ci sono utenti veri)

- Un ambiente di collaudo: ramo `dev` pubblicato su un sito a parte con un secondo progetto
  Firebase (`inner-stars-dev`), così le prove non toccano i dati veri. Su Android servirebbe un
  identificativo diverso (`app.innerstars.dev`) e un secondo `google-services.json`.
- Protezione di `main` su GitHub (pull request obbligatoria con i controlli verdi).
- Backup di Firestore (richiede il piano a pagamento), Crashlytics e informativa privacy (B3).
