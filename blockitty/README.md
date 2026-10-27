# Blockitty: Cat Block Puzzle 🐱🧱 (v2)

Block puzzle 8×8 con gatti da collezionare. È pensato per il trend n.1 per download su Google Play USA
(block puzzle + gatti) e monetizza con le meccaniche dei giochi che incassano di più.

![screenshot](store/screenshot-2.png)

- **Pubblicazione sul Play Store**: guida passo-passo in [`PUBLISHING.md`](PUBLISHING.md).
- **Scheda dello store** (testi, grafiche, prodotti in-app): [`store/listing.md`](store/listing.md).

## Cosa rende la v2 "trending"

| Area | Scelta | Perché |
|---|---|---|
| **Meccanica firma** | **Gattini intrappolati** nei blocchi: completando la loro linea li salvi; 5 salvataggi attivano la **Catnip Frenzy** (3 mosse a punti ×3). Gattini anche nella Daily Challenge e una missione dedicata | Un gioco riconoscibile e diverso dai cloni di Block Blast |
| Primo avvio | Si entra **subito in partita** con il tutorial, i menu compaiono dopo la prima partita | Ogni schermata prima del gameplay perde utenti |
| Equità | Ogni tris di pezzi è **sempre piazzabile** (verificato dall'algoritmo); inizio più facile, fine partita più impegnativa | "Pezzi impossibili" è la lamentela n.1 nelle recensioni di Block Blast |
| Pubblicità | **Rewarded opzionali** (revive, monete x2, box e spin extra); interstitial solo dalla 4ª partita, al massimo 1 ogni 3 partite e ogni 3 minuti, **mai durante il gioco**; prodotto "No Ads" | Gli annunci aggressivi sono la lamentela n.1 anche per Meowdoku |
| Viralità | **Sfida un amico**: il link fa giocare l'amico con gli *stessi pezzi* dal browser, senza installare nulla. Card del punteggio 1080×1350 per Instagram/TikTok. Gemme bonus alla prima condivisione del giorno | Sfida asincrona più "provalo subito" senza download |
| Abitudine | Streak giornaliera 🔥, login di 7 giorni, missioni, ruota, box gratis, Daily Challenge, notifiche promemoria (chieste solo dopo la prima partita) | Il ciclo che fa tornare ogni giorno |
| Spesa | Collezione a set, Mystery Box con pity, Paw Pass stagionale, offerte giornaliere, Starter Pack, gem pack, No Ads | Le meccaniche di Monopoly GO, Pokémon TCG Pocket e Roblox |
| Semplicità | 4 schede, 2 valute (i doppioni diventano monete), un solo pulsante "Rewards" per tutto il giornaliero | Meno scelte, più gioco |
| Audio | **Colonna sonora originale** generata in tempo reale (menu lo-fi e gioco pop che si intensifica con le combo), meow e SFX sintetizzati | Zero copyright, zero file audio, funziona offline |
| Qualità | Font Fredoka (OFL), rendering fino a 3x, scossa e flash sulle linee, punteggio animato, vignetta di pericolo, haptics nativi | Sensazione "premium" |

## Ottimizzazioni finali (v2.1)
- **Conformità Play Store**: target API 36, edge-to-edge gestito (barre di sistema con icone scure), rimosso il permesso limitato `SCHEDULE_EXACT_ALARM` (i promemoria non lo richiedono), recensioni tramite l'**API ufficiale In-App Review** (nessun popup che orienta il voto), icona di notifica monocromatica.
- **Prestazioni**: verificate con CPU rallentata 4× (telefono economico): 61 fps, caricamento in 1,6 s, drag fluido. Tetto alle particelle e rispetto dell'impostazione "riduci animazioni".
- **Affidabilità**: la partita in corso si riprende sempre, anche se l'app viene chiusa durante la prima partita. 15 scenari end-to-end automatici superati (ripresa, gattini e Frenzy, Daily Challenge, cambio giorno, sfide, Pass, negozio).

## Protezione contro le copie
- **Codice offuscato**: la build di produzione (APK, AAB e sito web) contiene un solo `app.js`, unito, minificato e offuscato con stringhe cifrate, flusso di controllo rimescolato e self-defending. Il sorgente leggibile non viene mai distribuito.
- **Anti-clone**: il gioco parte solo con il package ufficiale `com.blockitty.game` o sui domini autorizzati (`WEB_HOSTS` in `js/config.js`). Altrove mostra "Unofficial copy" e il link al Play Store.
- **Licenza proprietaria** in [`LICENSE`](LICENSE) (tutti i diritti riservati) e copyright visibile nel gioco.
- ⚠️ **Da fare tu**: rendi il repository **privato** (Settings › General › Danger Zone › Change visibility). Finché è pubblico, chiunque vede il sorgente in chiaro. Note:
  - con il repo privato GitHub Pages richiede GitHub Pro: in alternativa pubblica la cartella `www/` su Cloudflare Pages o Netlify (gratis) e aggiungi il dominio a `WEB_HOSTS`;
  - i link di download delle release richiederanno il login: per i tester usa il canale di test di Play Console.
- Consigliati: registra il marchio "Blockitty" (EUIPO/USPTO) e attiva la **Play Integrity API** quando aggiungerai un server (classifiche online).

## Copyright e licenze
- **Grafica**: gatti, blocchi, icone e banner sono generati dal codice di questo progetto.
- **Musica e suoni**: composizioni originali sintetizzate con WebAudio, senza campioni.
- **Font**: Fredoka, SIL Open Font License (`fonts/OFL-LICENSE.txt`), uso commerciale consentito.
- **Nome**: "Blockitty" e "Paw Pass" sono nomi originali. Non usiamo marchi di altri giochi.

## Sviluppo
```bash
npm install
npm test             # 20 test su logica di gioco ed economia
npm start            # versione web su http://localhost:8080
npm run assets       # rigenera icone, splash e screenshot dello store
npm run android:init # crea il progetto Android (target API 36)
npm run android:apk  # APK di test (serve l'Android SDK)
```
Ogni push avvia **GitHub Actions**, che produce l'APK di test, l'AAB firmato (se la chiave è configurata), la release `blockitty-latest` e il branch `blockitty-apk`.

```
js/core.js     logica pura: board, pezzi equi, scoring
js/state.js    economia, collezione, box, missioni, streak, pass, salvataggi
js/data.js     catalogo e bilanciamento: si modifica tutto da qui
js/game.js     schermata di gioco ed effetti
js/ui.js       menu, negozio, collezione, pass, sfide, risultati
js/audio.js    musica originale + effetti sonori + vibrazione
js/ads.js      AdMob (rewarded/interstitial + consenso GDPR)
js/billing.js  Google Play Billing (demo nel browser)
js/share.js    card del punteggio + link di sfida
js/notify.js   promemoria locali
js/config.js   ID AdMob, URL, regole di frequenza degli annunci
```
