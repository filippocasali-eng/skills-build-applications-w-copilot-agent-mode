# Installazione su Android

## Opzione A — APK già compilato (consigliata)

1. Sul telefono apri la pagina **Releases** del repository GitHub e scegli la pre-release
   **`marketpilot-android-latest`** ("MarketPilot AI per Android").
2. Scarica il file `MarketPilotAI-1.0.0-buildNN.apk`.
3. Samsung (One UI): quando il browser lo chiede, consenti **Impostazioni → App → (browser) → Installa app sconosciute**.
4. Apri il file scaricato e tocca **Installa**. Play Protect può avvisare che l'app non è nota: tocca *Installa comunque*
   (l'APK è firmato con la chiave di sideload del progetto, non è distribuito dal Play Store).
5. Apri **MarketPilot AI** e completa la configurazione iniziale (tutte le domande facoltative si possono saltare).
6. Premi **AGGIORNA MERCATO**: il primo download (2–3 anni di storico) può richiedere 1–3 minuti.

Requisiti: Android 10 (API 29) o superiore, connessione Internet per aggiornare i dati (i dati salvati restano consultabili offline).

Aggiornamenti: installa il nuovo APK sopra quello esistente; la firma è la stessa e i dati restano.

Verifica di integrità: la release include `SHA256.txt` con l'hash dell'APK.

## Opzione B — Compilare da sorgente

### Android Studio
1. Installa Android Studio (versione recente) con Android SDK 35 e JDK 17 (incluso).
2. *File → Open* → cartella `marketpilot/`.
3. Attendi la sincronizzazione Gradle, poi *Build → Build APK(s)*.
4. APK: `marketpilot/app/build/outputs/apk/debug/app-debug.apk`.

### Riga di comando
- Windows: `marketpilot\scripts\build_apk_windows.bat`
- Linux/macOS: `marketpilot/scripts/build_apk.sh`

Gli script richiedono `JAVA_HOME` (JDK 17+) e `ANDROID_HOME`/`ANDROID_SDK_ROOT` (o `local.properties` con `sdk.dir=...`).

### Installazione via USB (opzionale)
1. Sul telefono: *Impostazioni → Info sul telefono → Informazioni software*, tocca 7 volte *Numero build* per abilitare le Opzioni sviluppatore; attiva *Debug USB*.
2. `adb install -r marketpilot/app/build/outputs/apk/debug/app-debug.apk`

## Permessi richiesti
- **Internet / stato rete**: download dei dati.
- **Notifiche** (Android 13+, richiesto all'avvio): avvisi locali. Si può negare: l'app funziona comunque.

Nessun permesso di posizione, contatti, fotocamera o archiviazione. Nessuna telemetria.

## Batteria e aggiornamenti in background
L'aggiornamento automatico usa WorkManager e Android decide quando eseguirlo (Doze, risparmio energetico).
Su Samsung, per maggiore regolarità: *Impostazioni → Batteria → Limiti utilizzo in background* ed escludi MarketPilot.
