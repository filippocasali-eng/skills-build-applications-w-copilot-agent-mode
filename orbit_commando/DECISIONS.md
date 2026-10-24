# Decisions

Each entry: what was decided, why, and what would make us revisit it.

## M1 – Setup

### D1. Project lives in `orbit_commando/` inside the existing repository
The repository already holds unrelated exercise material. Keeping the game in
its own folder avoids mixing histories and makes it trivial to move into a
dedicated repo later (`git subtree split`).

### D2. Flutter 3.47.8 stable, Flame 1.38, Riverpod 3, Hive 2
Latest stable at project start (2026-10). Hive 2 is the requested store; we
keep the save as a single JSON document in one box (no type adapters), so
migrating to `hive_ce` or another store later is a few lines.

### D3. Low-res offscreen rendering instead of Flame's fixed-resolution viewport
`CameraComponent.withFixedResolution` scales vector drawing, so sprites at
fractional positions or rotations would be smoothed and sub-pixel. We record
the whole tree into a 384×216 picture (`toImageSync`), then upscale it with
nearest-neighbour in a `PostProcessor`. Benefits: real pixels everywhere, a
single hook for the CRT shader (M8), and an easy frame dump for tests.
Cost: one 384×216 GPU image per frame (~330 KB), disposed immediately.
Revisit if profiling on a 2021 mid-range device shows it in the budget.

### D4. Integer scaling by default, letterbox with a thin frame
20:9 phones at 1080p get 5× with 240 px side bars. A "fill" mode
(`ScaleMode.fit`) exists for a future setting. Screens below 384×216 fall
back to fractional scaling.

### D5. Sprite components are "crisp"
Rotated sprites (planetary gravity) are drawn with anti-aliasing off and
nearest sampling (`makeCrisp`). A render test checks that every sampled pixel
is one of the 64 palette colours, which caught anti-aliased edges in M1.

### D6. Fixed 60 Hz tick, `FixedTick` registry, own PRNG
`FixedStepClock` converts frame times to whole ticks (cap 5 per frame).
Simulation components implement `fixedUpdate(tick)`, dispatched in mount
order. `DetRandom` (xorshift32) replaces `dart:math Random` for anything that
affects the simulation. Physics will use doubles and avoid platform `sin/cos`
in the simulation path where cross-device bit-exactness matters (decision to
be finalised in M2 when the solver is written: fixed-point vs. deterministic
polynomial trig).

### D7. Asset generators in Python, single source of truth
`tools/pixel_art/build.py` generates sprites, the bitmap font and the palette,
including `lib/engine/render/palette.g.dart`, so code and art can't drift.
The build fails if any sprite pixel is outside the 64-colour palette.

### D8. Original bitmap font "ORBIT-5"
5×7 caps, digits, punctuation, `€`, `♥`, and accented capitals for IT
(and ES/DE/FR/PT). Text is upper-cased before rendering. A test checks that
every string in every ARB file is renderable.

### D9. minSdk 24, landscape (`sensorLandscape`), immersive sticky
As specified. `targetSdk`/`compileSdk` follow the Flutter defaults, which
track the Play requirement.

### D10. Localisation through `gen-l10n`; the game gets a `GameStrings` object
Keeps Flame code free of `BuildContext` while still using ARB files.

## Character pack (after M1)

### D11. Characters come from the supplied pack, not from generated sprites
The owner supplied an 8-character pack (`art_source/characters/`, concept
resolution, AI-generated, declared original). It replaces the generated
placeholder "Rex".
- **Heroes (playable):** Roxy, Brutus, Nyx, Doc. They replace Rex
  "Torpedo" Calloway and Vera "Nova" Kuznetsova from the brief. Brief §7
  asked for 2 heroes + 1 unlockable: plan is Roxy and Brutus available from
  the start, Nyx unlocked through the campaign, Doc as the 4th unlock
  (e.g. Boss Rush or Arcade clear). Final unlock rules go in GAME_DESIGN.md.
- **Enemies:** Grunt, Rocket, Cyclops, Bulwark become the Glorbo Empire's
  hired mechanised army: the bureaucrat aliens stay as officers, bosses and
  comic relief, and the troopers do the fighting. Brief §4.2 asks for at least
  12 enemy types, so 8 more are still needed (generated or from a new pack).

### D12. Import pipeline: concept art -> game pixels
`tools/pixel_art/import_characters.py` (run by `build.py`):
splits each 4×2 sheet by connected components (guns and muzzle flashes cross
the cell borders, so a grid crop cut them), anchors frames on the feet
baseline and hip centre, downscales every frame of a character with one
factor (heroes 40–44 px tall, enemies 40–48 px), uses hard alpha, quantizes
to a shared per-character palette and adds a 1 px dark outline. Enemies are
mirrored so every atlas faces right. Source sheets live in the repo (16 MB,
not bundled in the APK); only the ~260 KB of converted atlases ship.

### D13. Palette rule relaxed: 64-colour master palette + per-sprite palettes
Quantizing the pack to the 64-colour master palette lost skin tones and
Doc's denim. Each character now has its own palette of up to 24 colours plus
the outline, in the spirit of 16-bit sprite sub-palettes. Environments, UI and
generated FX keep the master palette. The render test now allows exactly the
master palette plus the colours found in the loaded atlases, so it still
catches blended or anti-aliased pixels. The brief's "max 64 colours on screen"
target no longer holds strictly and becomes a guideline.

### D14. Maps follow the new art direction
No maps existed yet (levels arrive in M5). Because the characters are gritty
military / scrap-tech, the tilesets will mix that look with the space setting:
riveted, rusted plating, sandbags and crates on planetoids, hazard stripes on
stations. The planetoid now comes in a larger size (`planetoid_medium`,
r = 60) that suits 40+ px characters. Small planetoids stay as props.

### D15. Open risk: closeness to an existing franchise's look
The pack is declared original, but its overall style (chunky military
commandos, a ponytailed heroine with a scarf, steampunk scrap-tech) is close
to a famous 90s arcade series that brief §1 names as off-limits. Nothing is
traced or copied as far as we can tell, but the owner should do a visual
review, ideally with legal input, before the store launch.

## Environment notes

- The build container could not reach `dl.google.com` (Android SDK
  downloads), so M1 was verified with `flutter analyze` and `flutter test`
  only. No APK was built here; see README for the commands.
