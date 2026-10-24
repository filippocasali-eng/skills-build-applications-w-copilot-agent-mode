# MIXO: Color Rush

Runner arcade a colori per bambini e ragazzi (6–15 anni), Android, Flutter + Flame.
Mixo, una creatura gelatinosa, corre in un tunnel infinito e deve attraversare **solo le porte del suo colore**. Le gocce cambiano il suo colore e, più avanti, **lo mescolano** (Rosso + Blu = Viola).

Progettato per Google Play **"Designed for Families"**: nessun dato personale, nessuna pubblicità, nessuna loot box, nessuna chat, acquisti solo estetici dietro parental gate.

| Documento | Contenuto |
|---|---|
| [GAME_DESIGN.md](GAME_DESIGN.md) | regole, meccaniche, tabelle di bilanciamento |
| [DECISIONS.md](DECISIONS.md) | scelte tecniche e di design con motivazione |
| [MULTIPLAYER_PLAN.md](MULTIPLAYER_PLAN.md) | roadmap multiplayer v2/v3 |
| [PLAY_STORE_CHECKLIST.md](PLAY_STORE_CHECKLIST.md) | Families Policy, Data Safety, IARC, testi scheda IT/EN |
| [PRIVACY_POLICY.md](PRIVACY_POLICY.md) | bozza informativa privacy (da validare con un legale) |
| [PERFORMANCE.md](PERFORMANCE.md) | budget prestazioni e procedura di profiling |
| [ROADMAP_v1.1.md](ROADMAP_v1.1.md) | 10 idee prioritarie per la v1.1 |

## Requisiti

- Flutter **3.47.8** stable (Dart 3.13)
- JDK 17, Android SDK (platform e build-tools richiesti da Flutter 3.47)
- Python 3 + numpy + Pillow, solo per rigenerare audio/icone (`tools/`)

## Comandi

```bash
flutter pub get
./tools/ci.sh                     # format + analyze (zero warning) + 66 test unit/widget
flutter run                       # emulatore o dispositivo
flutter test integration_test     # flusso completo su emulatore/dispositivo
flutter build apk --debug         # → build/app/outputs/flutter-apk/app-debug.apk
flutter build appbundle --release # → build/app/outputs/bundle/release/app-release.aab
```

Rigenerazione asset (deterministica, nessun asset di terze parti):

```bash
python3 tools/generate_audio.py   # SFX + 3 strati di musica → assets/generated/audio/
python3 tools/generate_icons.py   # icone launcher/adaptive/web + store/icon_512.png
python3 tools/gen_arb.py && flutter gen-l10n   # stringhe IT/EN da un'unica tabella
```

### Build automatica su GitHub

`.github/workflows/mixo-android.yml` (alla radice del repository) esegue CI, poi produce `app-debug.apk`, `app-release.apk` e `app-release.aab` come artifact scaricabili dalla pagina **Actions** di GitHub. Si avvia a ogni push che tocca `mixo_color_rush/` oppure manualmente ("Run workflow").

## Firma

**Debug / test locale.** Senza `android/key.properties` la build release è firmata con la chiave di debug di Android: va bene per provarla sul telefono, **non** per Google Play.

**Produzione (upload key).**

1. Genera la chiave una volta sola e conservala con un backup sicuro:
   ```bash
   keytool -genkey -v -keystore ~/mixo-upload-keystore.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias upload
   ```
2. Crea `android/key.properties` (è in `.gitignore`, non va mai committato):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/percorso/assoluto/mixo-upload-keystore.jks
   ```
3. `flutter build appbundle --release`.
4. Su Play Console attiva **Play App Signing** (Google conserva la chiave di firma dell'app; tu carichi con la upload key).
5. Per la CI: aggiungi i secret `MIXO_KEYSTORE_BASE64` (`base64 -w0 mixo-upload-keystore.jks`), `MIXO_KEY_ALIAS`, `MIXO_KEY_PASSWORD`, `MIXO_STORE_PASSWORD`.

## Pubblicazione su Play Console (internal testing)

1. Crea l'app: nome "MIXO: Color Rush", lingua predefinita Italiano, **Gioco**, **Gratuita**.
2. Compila *Contenuti dell'app* seguendo [PLAY_STORE_CHECKLIST.md](PLAY_STORE_CHECKLIST.md): pubblico di destinazione (6-8, 9-12, 13-15), Families Policy, Data Safety "nessun dato raccolto", annunci "No", classificazione IARC, informativa privacy (URL pubblico della [PRIVACY_POLICY.md](PRIVACY_POLICY.md)).
3. *Monetizza → Prodotti in-app*: crea i 4 prodotti **non consumabili** con gli ID di `Products` in `lib/core/models/cosmetics.dart`:
   `mixo_supporter_pack`, `mixo_pack_dino`, `mixo_pack_space`, `mixo_pack_sweet`.
4. *Test → Test interno*: crea una release, carica `app-release.aab`, aggiungi i tester (email Google).
5. *Impostazioni → Test delle licenze*: aggiungi gli stessi account → acquisti di prova senza addebito (carte di test).
6. Installa dal link di opt-in del test interno e verifica acquisto + ripristino.

> Opzionale in debug: `flutter run --dart-define=MIXO_STATIC_TEST_SKU=true` interroga il prodotto statico di Google `android.test.purchased` al posto del Pacchetto Sostenitore.

## Architettura in breve

```
lib/
  main.dart                avvio: asset, storage, audio, billing
  app/                     MaterialApp, tema, localizzazione
  core/                    modelli (profilo, missioni, trofei, cosmetici), progressione,
                           servizi (storage, audio/aptica, billing, ads, multiplayer, benessere)
  game/
    sim/                   SIMULAZIONE DETERMINISTICA (Dart puro, 60 Hz, RNG cross-platform, replay)
    ai/                    TrackGenerator a chunk, ChunkValidator, AdaptiveDirector, Coach, pattern
    systems/               colori/mescolamento, punteggio/combo
    components/ render/    rendering Flame (tunnel pseudo-3D, Mixo, particelle, effetti, fantasma)
    mixo_game.dart         FlameGame: passo fisso, eventi → effetti/audio/aptica
  features/                schermate (home, play, results, collection, missions, academy, daily,
                           ghost, settings, shop, parental_gate, splash)
  l10n/                    ARB IT/EN generati da tools/gen_arb.py + contenuti localizzati
assets/data/               51 pattern JSON + difficulty_config.json (bilanciamento)
assets/generated/          audio generato
test/unit test/widget      66 test · integration_test/  flusso su dispositivo
```

Dettagli e motivazioni in [DECISIONS.md](DECISIONS.md).

## Stato dei criteri di accettazione v1

Vedi la tabella aggiornata in fondo a [PLAY_STORE_CHECKLIST.md](PLAY_STORE_CHECKLIST.md#stato-criteri-di-accettazione-v1).
