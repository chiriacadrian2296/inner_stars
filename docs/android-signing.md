# Firma Android per il Play Store

Documento operativo per B4. Le password e il keystore **non** vanno mai nel repository
(`android/key.properties`, `*.jks` e `*.keystore` sono già nel `.gitignore`).

## Come funziona

- **Chiave di caricamento (upload key).** È quella che crei tu qui sotto: con lei firmi il
  bundle (`.aab`) che carichi su Play Console.
- **Firma dell’app da parte di Google (Play App Signing).** Per le app nuove è attiva di
  default: Google tiene la chiave vera con cui firma gli APK che arrivano agli utenti. Se
  perdi la chiave di caricamento, Google può reimpostarla; se Google perde la sua, non
  succede perché non la perde.
- **Google Sign-In e Firebase** controllano l’impronta SHA-1 del certificato con cui è firmata
  l’app. Ne servono **due** in Firebase (Impostazioni progetto → app Android `app.innerstars`):
  1. l’SHA-1 della **chiave di caricamento** (per le build che installi da te);
  2. l’SHA-1 della **chiave di firma dell’app di Google**, che compare in Play Console →
     Integrità dell’app → Firma dell’app, **dopo** il primo caricamento. Senza questa il
     login Google non funziona nelle app installate da Play.
  Esiste già l’SHA-1 della chiave di debug.

## 1. Creare il keystore (una volta sola, a mano)

Esegui in PowerShell. Il programma ti chiede le password: scegline due forti (puoi usare la
stessa per store e chiave) e **salvale in un gestore di password**.

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore "$HOME\inner-stars-upload.jks" -alias upload `
  -keyalg RSA -keysize 2048 -validity 10000
```

Conserva `inner-stars-upload.jks` **fuori dal repository** e fanne almeno una copia di riserva
(per esempio sul gestore di password o su un disco esterno). Senza il file e le password non
puoi più firmare gli aggiornamenti senza chiedere a Google la reimpostazione.

## 2. Dire a Gradle dove trovarlo

Crea `android/key.properties` (è ignorato da git):

```properties
storePassword=LA_TUA_PASSWORD
keyPassword=LA_TUA_PASSWORD
keyAlias=upload
storeFile=C:/Users/TUO_UTENTE/inner-stars-upload.jks
```

Con questo file presente la build di release viene firmata con la chiave di caricamento. Senza,
`build.gradle.kts` firma con la chiave di debug e stampa un avviso: va bene per prove locali,
ma Play **non** la accetta.

## 3. Costruire il bundle

```powershell
flutter build appbundle --release
```

Il file è `build/app/outputs/bundle/release/app-release.aab`.

## 4. Leggere l’SHA-1 della chiave di caricamento

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore "$HOME\inner-stars-upload.jks" -alias upload
```

Copia la riga `SHA1:` e aggiungila in Firebase. Poi, dopo il primo caricamento, aggiungi anche
l’SHA-1 che mostra Play Console (vedi sopra). Quando cambi le impronte, scarica di nuovo
`google-services.json` e controlla che l’app continui a fare il login.

## Se un giorno serve CI

La build di release non gira in CI. Se la vorrai, il keystore andrebbe in un segreto del
repository in base64, con `key.properties` generato al volo: da fare solo allora.
