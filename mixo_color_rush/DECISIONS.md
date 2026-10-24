# DECISIONS — MIXO: Color Rush

Registro delle scelte tecniche e di design, con motivazione. Ogni voce: **contesto → scelta → perché**.

## D-001 · Posizione del progetto nel repository
Il repository ospita già un esercizio (`octofit-tracker`). L'app vive in `mixo_color_rush/` come progetto Flutter autonomo, per non toccare il materiale esistente.

## D-002 · Toolchain
- Flutter **3.47.8 stable** / Dart **3.13.7** (ultima stable al 2026-10-24).
- Flame 1.38, flame_audio 2.12, flutter_riverpod 3.4, in_app_purchase 3.3, shared_preferences 2.5.

## D-003 · Persistenza: `shared_preferences` + documenti JSON versionati (niente Hive)
Hive 2.x non riceve aggiornamenti da anni e richiede adapter/codegen. I dati di v1 sono piccoli (profilo, statistiche, ultime 10 partite, replay del record). Scelta: un'interfaccia `KeyValueStore` con implementazione `shared_preferences` (produzione) e in-memory (test). Ogni documento ha un campo `schemaVersion` e una catena di migrazioni esplicite.

## D-004 · Lint
`flutter_lints` + regole extra (`strict-casts`, `strict-inference`, `strict-raw-types`, `avoid_dynamic_calls`, `unawaited_futures`, …). `require_trailing_commas` escluso perché in conflitto con il formatter "tall style" di Dart 3.7+, che gestisce le virgole da solo. `flutter analyze --fatal-infos` deve essere pulito.

## D-005 · CI locale
`tools/ci.sh`: `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`. Va eseguito prima di ogni commit di milestone.

## D-006 · Android
`minSdk = 24`, `targetSdk` = default del Flutter SDK (allineato al requisito Play corrente), orientamento `portrait` fissato sia nel manifest sia via `SystemChrome`.

## D-007 · Ambiente di sviluppo cloud: Android SDK non scaricabile
Nell'ambiente cloud in cui è stato sviluppato il progetto, la policy di rete blocca `dl.google.com`, quindi l'Android SDK (platform, build-tools) non è installabile e `flutter build apk/appbundle` non può essere eseguito lì. Tutta la logica di gioco è Dart puro e coperta da `flutter test` (VM). Le build APK/AAB vanno eseguite in locale o in un ambiente con accesso a `dl.google.com` (vedi README).

## D-008 · Anteprima web
Aggiunta la piattaforma `web` solo come **anteprima giocabile dal browser** (anche da smartphone) mentre l'Android SDK non è disponibile nell'ambiente cloud. Build: `flutter build web --release --no-web-resources-cdn --pwa-strategy=none` (CanvasKit e font inclusi, nessuna richiesta a CDN esterne). Il target di prodotto resta Android.

## D-009 · Simulazione deterministica separata dal rendering
`lib/game/sim/` è Dart puro (nessuna dipendenza da Flutter/Flame): tick fisso a 60 Hz, RNG `mulberry32` implementato con moltiplicazioni a 16 bit per essere identico su VM e web, input registrati come `(tick, azione)`. `MixoGame` (Flame) accumula il tempo reale ed esegue N step fissi per frame, poi disegna lo stato. Ne derivano gratis: replay, Sfida Fantasma, Sfida del Giorno e (v2) multiplayer con stessa seed.

## D-010 · La pista non dipende da come si gioca
`TrackGenerator` lavora in **distanza**, non in tempo: velocità e distanza fra le file sono funzioni della distanza percorsa e dei `DifficultyParams` fissati a inizio partita. Così stessa seed + stessi parametri = stessa pista per chiunque. Il generatore tiene traccia dell'insieme dei colori che Mixo *potrebbe* avere (prendendo o saltando le gocce) e garantisce che ogni fila di porte sia superabile per ciascuno di essi, oppure lascia una corsia libera.

## D-011 · Rendering "a codice"
Tunnel, porte, gocce, ostacoli e Mixo sono disegnati su `Canvas` con `Paint`/`Path` preallocati (nessuna allocazione di oggetti di gioco nel loop; le file della pista vengono da un `RowPool`). Le porte vicine (z < 0.4) sono disegnate sopra Mixo per dare l'effetto di attraversamento.

## D-012 · Regole di mescolamento non specificate nel prompt
- Secondario + uno dei suoi primari = **nessun cambio** (es. Arancione + Rosso = Arancione).
- Secondario + secondario diverso, o secondario + primario mancante = **Marrone**.
- Marrone resta marrone con qualsiasi goccia di colore: serve la **Bianca** (che riporta al colore base, il rosso di partenza).
- La goccia Bianca arriva insieme al mescolamento (nello stesso momento in cui il marrone diventa possibile); Arcobaleno e Inverti sono le "gocce speciali" sbloccate dopo.
- Colori misti con simbolo: Arancione = rombo, Verde = stella, Viola = esagono, Marrone = croce.

## D-013 · Generazione a chunk e validatore
- I pattern (51, in `assets/data/patterns/*.json`) sono **astratti**: `T` = porta del colore pianificato, `N` = porta esca, `d` = goccia che cambia il colore pianificato, `b` = goccia trappola, `W/R/I` = speciali, `O/o` = ostacoli alto/basso, `.` = libero. Il colore reale viene scelto all'istanziazione; i pattern vengono anche specchiati e, a 5 corsie, traslati.
- `ChunkValidator` esplora tutti gli stati (corsia, colore, arcobaleno) raggiungibili **senza danno**, limitando i cambi di corsia a uno ogni 0,18 s (velocità di swipe umana) e usando un margine del 10% sulla velocità. Se un'istanza è impossibile viene scartata (max 10 tentativi), poi si inserisce una fila vuota di respiro (< 5% dei casi, verificato dai test).
- Modalità `strict` (livelli bassi): ogni colore che Mixo *potrebbe* avere deve avere un percorso senza danno, non solo quello "pianificato". Così un bambino che salta una goccia non viene punito.
- Quando il marrone diventa possibile, il generatore antepone un "muro" di gocce bianche.

## D-014 · Difficoltà adattiva
- Rating stile Elo semplificato (0–1000), aggiornato a fine partita in base al tasso di successo rispetto alla fascia 70–85%, con bonus per partite lunghe/padronanza e malus silenzioso dopo 3 sconfitte sotto i 30 s.
- Il rating mappa sugli **stadi** di `difficulty_config.json` (interpolazione lineare dei numeri). Gli stadi sbloccano in ordine: gocce → ostacoli → mescolamento → porte secondarie → speciali → 5 corsie ("Esperto"). Salto e tuffo dipendono dal livello giocatore (5 e 10).
- Durante la partita il generatore legge il successo delle ultime 16 porte e sposta tier e spaziatura del chunk successivo: è deterministico rispetto agli input registrati, quindi i replay restano esatti. Sfida del Giorno e Fantasma disattivano l'adattamento live (pista uguale per tutti).
- Nessuna età viene chiesta: si parte facili (rating 60) e si sale in fretta se si è bravi.

## D-015 · Audio procedurale
`tools/generate_audio.py` (numpy) sintetizza 11 SFX e 3 strati di musica chiptune a 120 BPM (loop di 8 s, tonalità Do pentatonica). Gli strati (base → +arpeggio → +melodia) si alternano con la velocità e il `playbackRate` sale da 0,95 a 1,2: "musica il cui tempo segue la velocità" senza dover sincronizzare tracce separate. WAV 22 kHz mono (≈1,2 MB), nessun asset di terzi.

## D-016 · Accessibilità
- Simboli dei colori attivi di default su porte, gocce, Mixo e HUD; i colori di gioco restano distinguibili per forma con qualsiasi tipo di daltonismo.
- "Effetti più calmi": niente scossoni, niente slow-mo, meno particelle.
- Controllo alternativo a tocco sui lati; pulsanti ≥ 56 dp; icona prima del testo in ogni tile del menu; ricette mostrate con badge colorati anziché a parole.

## D-017 · Persistenza
Un unico documento JSON (`mixo.profile`) con `schemaVersion` e catena di migrazioni; prima di ogni salvataggio la versione precedente viene copiata in `mixo.profile.bak`, usata se il documento principale è illeggibile. Nessun backup cloud (`allowBackup=false` e regole di estrazione dati): i dati non lasciano il dispositivo.

## D-018 · "Obbligatori solo i primi 2" (Accademia)
Interpretazione: la Corsa Libera è sempre disponibile (il prompt chiede onboarding → subito Corsa Libera); le prime 2 lezioni dell'Accademia sono obbligatorie **per sbloccare Sfida del Giorno e Sfida Fantasma**, che usano parametri fissi più impegnativi e presuppongono le basi.

## D-019 · Onboarding giocato
Una vera mini-partita in modalità *practice* (gli errori non tolgono cuori) di ~230 unità con pattern "porta del tuo colore" che richiedono uno swipe; fumetto di istruzioni, "Bravo!" alla prima porta, poi si passa direttamente alla Corsa Libera.

## D-020 · Pubblicità (futuro)
v1 senza annunci (`NoAds`). Se mai introdotti: solo SDK autocertificati Families, solo rewarded non personalizzati scelti dal giocatore per un premio estetico, mai interstitial durante il gioco, mai nella prima sessione, disattivabili dal genitore.

## D-021 · Billing
`in_app_purchase` (Play Billing Library) con 4 prodotti **non consumabili**. Concessione locale alla conferma (nessun server, quindi nessun dato personale); `completePurchase` sempre chiamato; ripristino con `restorePurchases`. Test: account license-tester su internal testing (metodo ufficiale per Billing v5+); opzione `--dart-define=MIXO_STATIC_TEST_SKU=true` per il prodotto statico `android.test.purchased`. Su web/emulatori senza Play Store il negozio mostra "non disponibile" e il gioco funziona normalmente.

## D-022 · Permessi
`INTERNET` (Play Billing) e `VIBRATE` (consentito dal prompt; la vibrazione usa `HapticFeedback`). La libreria billing aggiunge `com.android.vending.BILLING`. `AD_ID` rimosso esplicitamente. Nessun permesso di notifica.

## D-023 · Build Android su GitHub Actions
Poiché l'ambiente cloud di sviluppo non può scaricare l'Android SDK, `.github/workflows/mixo-android.yml` esegue CI e produce APK debug, APK release e AAB release come artifact. Con i secret dell'upload key la release è firmata per Play; senza, è firmata con una chiave di debug temporanea (solo test).

## D-024 · Ottimizzazioni release
`isMinifyEnabled` + `isShrinkResources` attivi in release; versione 1.0.0+1; `applicationId` `com.mixogames.mixocolorrush` (modificabile prima del primo upload: dopo è definitivo).
