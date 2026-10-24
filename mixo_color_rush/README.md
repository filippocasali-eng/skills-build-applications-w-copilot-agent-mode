# MIXO: Color Rush

Runner arcade a colori per bambini e ragazzi (6–15 anni), Android, Flutter + Flame.
Mixo attraversa solo le porte del suo colore; le gocce cambiano (e **mescolano**) il suo colore.

> Progetto pensato per Google Play "Designed for Families": nessun dato personale, nessuna pubblicità, nessuna loot box, nessuna chat.

## Requisiti
- Flutter 3.47.x stable (Dart 3.13)
- Android SDK (platform 36, build-tools) + JDK 17/21
- Python 3 + numpy (solo per rigenerare gli asset audio, `tools/`)

## Comandi
```bash
flutter pub get
./tools/ci.sh                 # format + analyze + unit/widget test
flutter run                   # su emulatore/dispositivo
flutter test integration_test # su emulatore/dispositivo
flutter build apk --debug
flutter build appbundle --release
```

## Struttura
```
lib/app        routing, tema, localizzazione
lib/core       costanti, servizi (storage, audio, aptica, billing)
lib/game       FlameGame, componenti, sistemi, AI, simulazione deterministica
lib/features   schermate (home, play, results, collection, …)
assets/        dati (pattern JSON, bilanciamento) e asset generati
tools/         CI locale e script di generazione asset
```

Le sezioni su firma, rilascio e Play Console vengono completate nella milestone M10.
