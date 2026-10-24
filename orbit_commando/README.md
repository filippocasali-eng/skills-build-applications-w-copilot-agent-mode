# ORBIT COMMANDO '94

A retro 16-bit run & gun with planetary gravity, for Android. Flutter + Flame,
with a custom deterministic 60 Hz simulation, a 384×216 pixel-perfect
renderer and all-original generated art and audio.

> Status: **M1 – Setup** done. See the milestone list in `DECISIONS.md`.

## Requirements

| Tool | Version |
|---|---|
| Flutter | 3.47.x stable (Dart 3.13) |
| Android SDK | platform for the current `targetSdk`, build-tools, NDK as requested by Flutter |
| JDK | 17+ |
| Python | 3.10+ with `pip install -r tools/pixel_art/requirements.txt` for the asset tools |

## Common commands

```bash
flutter pub get
python3 tools/pixel_art/build.py      # regenerate sprites, characters, font, palette
flutter analyze                       # must report no issues
flutter test                          # unit + widget tests
flutter run                           # on a device/emulator (landscape)

# Save a frame of the renderer for inspection:
ORBIT_DUMP=/tmp/frame.png flutter test test/widget/pixel_render_test.dart
```

## Build & sign

```bash
flutter build apk --debug                    # build/app/outputs/flutter-apk/app-debug.apk
flutter build appbundle --release            # build/app/outputs/bundle/release/app-release.aab
```

Release signing (to be wired in M11): create `android/key.properties`
(git-ignored) with `storePassword`, `keyPassword`, `keyAlias`, `storeFile`.
Until then the release build is signed with the debug key and is **not**
uploadable to Play.

## Layout

```
lib/
  app/         routing, theme
  core/        services (storage, …); Riverpod providers
  engine/      deterministic loop, physics, camera, pixel renderer, replay
  game/        OrbitGame, scenes, player, weapons, enemies, …
  features/    Flutter screens (title, play, shop, settings, …)
  l10n/        ARB files (EN template, IT) + generated localisations
assets/        game-ready sprites/fonts (+ tiles, audio, levels, shaders later)
art_source/    original art (character pack); converted by tools, not bundled
tools/         pixel_art (Python generators), audio, level_validation
test/          unit / widget / integration
```

## Documentation

- `DECISIONS.md`: technical decisions and their reasons.
- `ART_PIPELINE.md`: how sprites and fonts are produced and how to replace them.
- Later milestones add `GAME_DESIGN.md`, `MONETIZATION.md`,
  `MULTIPLAYER_PLAN.md`, `PERFORMANCE.md`, `STORE_LAUNCH_KIT.md`.
