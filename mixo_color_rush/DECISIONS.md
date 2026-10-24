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
