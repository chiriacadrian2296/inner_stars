# Sincronizzazione dei media (B2)

Foto, note vocali e immagini della moodboard viaggiano su Cloud Storage per Firebase. I record
restano su Firestore e portano solo l'identificativo del file; il file viaggia a parte.

## Cosa si sincronizza

Come deciso nel piano di rilascio:

| Cosa | Cartella nel cloud | Note |
|---|---|---|
| Foto principale di una vittoria (`Star.photoPath`) | `photos/` | ridotta a max 1280 px sul lato lungo, JPEG qualità 78 |
| Una nota vocale per vittoria (`StarMedia` di tipo `voice`, max 60 s) | `voices/` | già compressa alla registrazione: AAC mono 48 kbps a 22 kHz (circa 360 KB al minuto) |
| Immagini della moodboard (solo `MoodboardKind.photo`) | `moodboard/` | come le foto; massimo 12 elementi per area |

Restano **solo sul dispositivo** le foto secondarie, i video e tutto ciò che non è in tabella
(dopo la v1). Oggi l’app non permette più di aggiungere foto secondarie né video: si tratta solo
dei dati vecchi già presenti sul dispositivo che li ha creati. Un altro dispositivo vede il
record ma non ha quel file.

Percorso nel cloud: `users/{uid}/media/<cartella>/<nome file>`. Il nome è l'ultima parte dopo
`/`, `\` o `:` dell'identificativo del record (`mediaName`), così il telefono (percorso o nome
file) e il web (chiave come `moodboard-media:123.jpg`) danno lo stesso nome.

## Come funziona

- **Invio.** Quando un archivio salva o cancella un file (`PhotoStorage`, `StarMediaStorage`,
  `MoodboardStorage`) chiama `MediaHooks`; il lavoro finisce in una **coda persistente**
  (`MediaQueue`, nelle preferenze), con un solo lavoro per file: l'ultimo vince, e una
  cancellazione annulla un invio non ancora fatto. `MediaSync.process` svuota la coda dopo ogni
  sincronizzazione riuscita e poco dopo ogni modifica; si ferma al primo errore (di solito
  offline). Un lavoro che fallisce aspetta sempre di più prima di riprovare (2 minuti, 4, 8… al
  massimo 6 ore) e **non viene mai scartato**: la causa può essere temporanea (offline, Storage non
  ancora attivato) e scartarlo farebbe perdere il file per sempre. Si scarta solo un lavoro il cui
  file locale non esiste più.
- **Scaricamento solo quando serve.** Un file fatto da un altro dispositivo non si scarica in
  anticipo: quando una schermata lo chiede e manca (`PhotoStorage.readBytes`,
  `StarMediaStorage.file/readBytes`, `MoodboardStorage.read`), `MediaHooks.fetch` lo prende dal
  cloud e lo salva con lo stesso identificativo. Richieste simultanee condividono un solo
  scaricamento.
- **Caricamento iniziale.** I file già presenti sul dispositivo prima di questa funzione non
  sono mai passati dalla coda: una volta per account, dopo la prima sincronizzazione,
  `backfillMedia` li mette in coda.
- **Compressione prima dell'invio** (`compressPhoto`); oltre 5 MB dopo la compressione il file
  non viene inviato (stesso limite delle regole).
- **Pulizie locali non toccano il cloud.** "Elimina dati su questo dispositivo" e il cambio di
  account cancellano i file locali con `syncDeletion: false`; il cambio di account svuota anche
  la coda, per non mandare i lavori di un account all'altro.
- **Cancellazione account.** `SyncService.deleteCloudData` chiama prima `deleteMedia`
  (`MediaSync.deleteAllRemote`: elenca e cancella tutto sotto `users/{uid}/media`).
- **Build di sviluppo.** Il debug è un'app locale separata (`kOfflineDevMode`): non crea la coda né
  i ganci dei media, e non parla mai con Firebase.

## Regole di sicurezza

`storage.rules`: solo il proprietario legge, scrive e cancella sotto `users/{uid}/media/`;
scritture limitate a 5 MB, a `image/*` e `audio/*` e alle tre cartelle. Tutto il resto è negato.

## Cosa non c'è ancora

- **Pulizia dei file orfani.** `MediaSync.removeOrphans` esiste ed è testata, ma non è collegata:
  va chiamata solo dopo una sincronizzazione completa, con l'elenco di ciò a cui puntano i
  record vivi. Da collegare con una politica prudente (per esempio al massimo una volta al giorno).
- **Prove su Firebase vero.** L'adattatore `FirebaseMediaRemote` è compilato (Android e web)
  ma non provato: serve il piano Blaze e il bucket attivo.
- **Test delle regole** di Firestore e Storage sull'emulatore: servono Java e `firebase-tools`.

## CORS del bucket (necessario per il web)

Il web scarica i file con il web SDK di Firebase (`getData`), che dal browser funziona solo se
il bucket autorizza il dominio dell'app. Senza, il telefono carica i file ma il web non li vede
(`Failed to fetch`, foto e note vocali assenti). Configurato il 21 ottobre 2026 dalla Cloud Shell
della console, con questo file (`cors.json`):

```json
[{"origin":["https://my.innerstars.app"],"method":["GET","HEAD"],"maxAgeSeconds":3600,"responseHeader":["Content-Type","Authorization","X-Firebase-Storage-Version","X-Firebase-GMPID","X-Firebase-AppCheck"]}]
```

```
gcloud storage buckets update gs://inner-stars-5e6d6.firebasestorage.app --cors-file=cors.json
gcloud storage buckets describe gs://inner-stars-5e6d6.firebasestorage.app --format="default(cors_config)"
```

**Da rifare se** cambia il dominio della web app, si ricrea il bucket o si aggiunge un'altra
origine (per esempio un dominio di prova). Il debug non serve: non usa Firebase.

## Altro difetto trovato provando con due dispositivi

Il record di una stella arriva sull'altro dispositivo prima del suo file, perché i file partono
dopo la sincronizzazione dei record. `PhotoImage` per questo riprova a cercare una foto mancante
(4, 10, 30 e 90 secondi) invece di restare vuota.

## Console Firebase

Fatto il 21 ottobre 2026: Blaze attivo, Storage attivato con bucket nella multi-regione **EU**
(Standard) e regole pubblicate. Restano le prove con due dispositivi e, se non c'è già,
l'avviso di budget. I passi originali, per memoria:

1. Passare il progetto al piano **Blaze** e impostare un **avviso di budget** (Cloud Storage
   non è disponibile sul piano Spark).
2. Attivare **Storage** e scegliere la posizione del bucket: controllare quali regioni hanno la
   quota gratuita (le regioni europee possono non averla, e si paga dal primo gigabyte).
3. Pubblicare le regole: `firebase deploy --only storage` (serve `firebase login`).
4. Provare con due dispositivi: foto su uno, vederla sull'altro.
