# Pubblicare Blockitty sul Google Play Store (guida passo-passo)

Tempo stimato: 1–2 ore di lavoro tuo, più i tempi di revisione di Google (di solito 1–7 giorni).

## 0. Cosa è già pronto
- App Android con **target API 36** (requisito Play Store obbligatorio da agosto 2026), Billing Library 9, AdMob con modulo di consenso GDPR (UMP).
- Build automatica su GitHub Actions: APK di test sempre. **AAB firmato** quando configuri la chiave (passo 2).
- Grafiche dello store in `store/`, testi in `store/listing.md`, privacy policy in `privacy.html`.

## 1. Account
1. Crea l'account sviluppatore: https://play.google.com/console ($25 una tantum, verifica identità).
2. **Account personali nuovi**: Google richiede un *closed test* con almeno **12 tester per 14 giorni** prima della produzione. Usa amici e parenti: è anche il primo test di viralità.
3. Crea un account AdMob (https://admob.google.com), aggiungi l'app Android e crea due unità: **Rewarded** e **Interstitial**.

## 2. Chiave di firma (una volta sola)
Ti ho generato una chiave di upload (`blockitty-upload.jks`, inviata in chat con le password). **Conservala in un posto sicuro**: senza di essa non potrai pubblicare aggiornamenti. Se la perdi, Play App Signing ti permette comunque di chiedere il reset a Google.

Su GitHub › repository › Settings › Secrets and variables › Actions › *New repository secret*, crea:
| Nome | Valore |
|---|---|
| `KEYSTORE_BASE64` | il contenuto del file `blockitty-upload.jks.base64.txt` |
| `KEYSTORE_PASSWORD` | la password del keystore |
| `KEY_ALIAS` | `blockitty` |
| `KEY_PASSWORD` | la password della chiave |
| `ADMOB_APP_ID` | l'App ID AdMob (formato `ca-app-pub-XXXX~YYYY`) |

Poi in `js/config.js` sostituisci gli ID di test di AdMob con le tue unità e metti `testing: false`.
Al push successivo la release su GitHub conterrà **`blockitty-release.aab`**: è il file da caricare su Play Console.

## 3. Crea l'app su Play Console
- Nome: *Blockitty: Cat Block Puzzle* · Gioco · Gratuito.
- **Scheda dello store**: copia testi e immagini da `store/listing.md` e `store/`.
- **Privacy policy**: attiva GitHub Pages (Settings › Pages › Source: GitHub Actions) e fai il merge su `main`. L'URL sarà quello indicato in `store/listing.md`.
- **Prodotti in-app**: crea i 7 prodotti con gli ID esatti della tabella in `store/listing.md`.

## 4. Questionari obbligatori (risposte consigliate)
- **Annunci**: Sì, contiene annunci.
- **Classificazione dei contenuti (IARC)**: nessuna violenza, nessun contenuto sensibile. Rispondi *Sì* a "acquisti digitali" e *Sì* a "oggetti casuali a pagamento (loot box)". Le probabilità sono mostrate nel gioco.
- **Pubblico target**: **13+** (non selezionare fasce sotto i 13: con loot box e annunci personalizzati le policy Families sarebbero molto restrittive).
- **Sicurezza dei dati**: raccoglie *ID dispositivo/pubblicità* e *interazioni con l'app* tramite AdMob (pubblicità, analisi). Dati crittografati in transito: sì. Nessun dato personale raccolto dallo sviluppatore. Gli acquisti sono gestiti da Google Play.
- **App governative / finanziarie / salute**: No.

## 5. Rilascio
1. *Test › Test chiuso*: carica l'AAB, aggiungi i 12+ tester e attendi 14 giorni.
2. *Produzione*: carica lo stesso AAB (o uno nuovo), scegli i paesi (inizia da USA, Canada, UK, Australia) e invia in revisione.

## 6. Dopo il lancio (crescita)
- Le sfide tra amici aprono la versione web: tieni GitHub Pages attivo.
- Guarda su AdMob l'eCPM delle rewarded e su Play Console la retention D1/D7. Bilancia prezzi e premi da `js/data.js`.
- Ogni stagione (28 giorni) il Paw Pass si rinnova da solo. Aggiungere nuovi gatti richiede solo una riga in `js/data.js`.
