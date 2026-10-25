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
factor (heights updated in D16), uses hard alpha, quantizes
to a shared per-character palette and adds a 1 px dark outline. Enemies are
mirrored so every atlas faces right. Source sheets live in the repo (16 MB,
not bundled in the APK); only the ~260 KB of converted atlases ship.

### D13. Palette rule relaxed: 64-colour master palette + per-sprite palettes
Quantizing the pack to the 64-colour master palette lost skin tones and
Doc's denim. Each character now has its own palette (32 colours since D16) plus
the outline, in the spirit of 16-bit sprite sub-palettes. Environments, UI and
generated FX keep the master palette. The render test now allows exactly the
master palette plus the colours found in the loaded atlases, so it still
catches blended or anti-aliased pixels. The brief's "max 64 colours on screen"
target no longer holds strictly and becomes a guideline.

### D14. Maps follow the new art direction
No maps existed yet (levels arrive in M5). Because the characters are gritty
military / scrap-tech, the tilesets will mix that look with the space setting:
riveted, rusted plating, sandbags and crates on planetoids, hazard stripes on
stations. Planetoids now come in larger sizes (see D17) to suit the characters. Small planetoids stay as props.

### D15. Open risk: closeness to an existing franchise's look
The pack is declared original, but its overall style (chunky military
commandos, a ponytailed heroine with a scarf, steampunk scrap-tech) is close
to a famous 90s arcade series that brief §1 names as off-limits. Nothing is
traced or copied as far as we can tell, but the owner should do a visual
review, ideally with legal input, before the store launch.

## Detail pass

### D16. Internal resolution raised from 384×216 to 640×360
The owner asked for a more detailed, "more pixel" look. At 384×216 the
characters were about 42 px tall and lost most of the pack's detail. 640×360
keeps the 16:9 frame and scales by whole numbers on common screens:
2× at 720p, 3× at 1080p (also on 20:9 phones, with side bars), 4× at 1440p.
Characters are now 64–78 px tall (about 19% of the screen height, close to
the classic arcade proportion), with 32 colours each plus the outline. Cost:
the offscreen frame is 2.8× larger (0.9 MB per frame); the performance
check moves to the M11 profiling pass. The bitmap font stays 5×7 and draws
titles at integer 2× (`scale:` on `BitmapFont.draw`).

### D17. Richer generated backdrops
New generators (`sprites.py`, numpy): a horizontally tileable dithered nebula
(kept dark so it never competes with sprites), a distant ringed gas giant,
and planetoids with fbm terrain, two materials (rock and basalt), crater
bowls with lit rims, and an aqua rim light on the shadow side. All use the
master palette and 4×4 Bayer dithering. The title scene layers nebula
(slow parallax), the drifting gas giant, a 3-layer starfield and a
r = 110 planetoid.

## Game and release (M2–M11)

### D18. Pure-Dart simulation, Flame only for presentation
`GameSim` holds the whole game state and knows nothing about Flame. Flame
draws it (`WorldRenderer`, `Fx`, `Hud`) and feeds inputs.
- **Pros:** headless tests (the bot plays all 15 levels in seconds),
  replays, ghosts and a future rollback netcode.
- **Revisit if:** an effect needs per-frame engine state; keep it in the
  view layer.

### D19. Levels as generated Tiled JSON, proven by a bot
Levels are written in a Python DSL (`tools/level_gen`) that outputs Tiled
`.tmj`, so they can still be opened in Tiled. They are checked twice:
- by a static validator (reachability with the movement limits)
- by the `AutoPilot` bot, which must finish every level in
  `bot_playthrough_test.dart`

### D20. Generated chiptune instead of licensed music
`tools/audio` synthesises every SFX and track (pulse, triangle, noise,
tracker). It is original by construction, tiny (1.4 MB) and
reproducible. Music is OGG Vorbis and SFX are WAV, for instant playback.

### D21. Test store build for sideloading
Play Billing works only for apps installed from Play, so a sideloaded APK
would show a dead shop.
- `--dart-define=TEST_STORE=true` swaps in `TestBillingService`. Every
  purchase is free and instant, and the shop is labelled "TEST STORE".
- The CI release APK uses it; the AAB for Play does not.

### D22. Local wallet and receipt checks in v1, server in v2
v1 must work offline, so the wallet and purchase checks run on the device
(known SKU, non-empty token, a token granted once). The Firebase backend
in `backend/` is written but not deployed. The migration is described in
`MONETIZATION.md` §8.
- **Risk:** a rooted device can edit its own save. The impact is limited
  to that player's cosmetics; ranked modes never use paid power.

### D23. Age handling: unknown age = minor
Until the age gate is answered, these are off:
- online features
- paid capsules
- personalised ads

Ads for minors use Google's teen treatment, and the content rating is
capped at T for everyone.

### D24. Phone-first UI scale
Flutter screens use a global pixel scale `kPx = 1.25`. Widget tests run at
a 20:9 phone size (2400×1080 at 2.625 dpr, i.e. 914×411 dp), so overflow
shows up in CI, not on a player's phone.

## Global release

### D25. Challenge codes instead of accounts for the viral loop
A code holds level, remix, seed, hero and target in 50 bits (10 base-32
characters plus a checksum). The deterministic sim makes the run the same
on any phone. Codes need no backend, no sign-in and no deep-link
infrastructure, and they survive any chat app.
- **Revisit:** when online leaderboards ship (verified replays) and deep
  links are wanted.

### D26. Remix modes never unlock campaign content
Weekly, daily and challenge runs pay out tokens and XP but don't record
campaign clears. A shared code for a World 3 level is a free taste of
paid content, not a bypass.

### D27. Translations live in `tools/l10n/tr_<lang>.py`
EN/IT stay in `strings.py`. Each extra language is one dict, and the
generator refuses missing keys or mismatched placeholders. The pixel font
gained the glyphs these languages need. A test renders every main screen
in every language.

## Environment notes

- The build container cannot reach `dl.google.com` (Android SDK
  downloads). APK/AAB builds therefore run in GitHub Actions
  (`.github/workflows/orbit-commando-android.yml`). It analyzes, runs every
  test, builds the debug and release APKs (test store) and the AAB, then
  publishes them on the `orbit-commando-latest` pre-release.
