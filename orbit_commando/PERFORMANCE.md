# Performance

Target: a locked 60 fps on a 2019 mid-range phone (Snapdragon 665 /
Helio G85 class, 3 GB RAM), at under 150 MB RSS. APK under 40 MB.

## Budget per frame (16.6 ms)

| Stage | Budget | Notes |
|---|---|---|
| Simulation (1 tick) | ≤ 1 ms | Pure Dart, no allocations in the hot loop |
| World draw into the 640×360 offscreen picture | ≤ 4 ms | Sprite atlases, batched `drawImageRect` |
| `toImageSync` + upscale (or CRT shader) | ≤ 3 ms | One full-screen quad |
| Flutter/engine overhead and HUD | ≤ 4 ms | |
| Headroom | ~4 ms | |

## Measured

The headless simulation runs on the CI-class x86 container (Xeon 2.1 GHz)
in JIT test mode, with the autopilot playing:

| Level | Ticks | Average per tick | Worst tick |
|---|---|---|---|
| 1-1 Cintura Tranquilla | 2,413 | 47 µs | 4.2 ms (JIT warm-up) |
| 2-4 Anelli della Pizza | 3,600 | 17 µs | 0.7 ms |
| 3-3 Fabbrica di Moduli | 2,235 | 21 µs | 2.2 ms |
| 3-5 Emperor Glorbo (boss) | 3,600 | 19 µs | 4.2 ms (GC) |

AOT on a phone CPU is about 2–3× slower than this desktop core and about
1.5× faster than JIT. That puts the average tick around 50 µs, about 5 %
of the 1 ms sim budget.

| Asset | Size |
|---|---|
| All game assets | 2.7 MB |
| Audio (OGG music, WAV SFX) | 1.4 MB |
| Sprites | 0.8 MB |

## Techniques in place

- **Rendering:**
  - Low-res offscreen rendering: the game draws 230,400 pixels a frame
    whatever the phone's resolution, and the upscale is a single
    textured quad.
  - Sprite atlases per character and per enemy group; nearest filtering;
    no anti-aliasing (`makeCrisp`).
  - Pre-rendered backdrops and planet textures (generated offline), drawn
    as images with parallax instead of being composed per frame.
- **Simulation:**
  - Fixed-size pools for bullets, particles and pickups (`BulletPool`, `Fx`),
    so there is no per-frame allocation in combat.
  - A spatial grid for static geometry (`StaticWorld`): collision queries
    only test the segments near the body.
  - The fixed-step clock caps catch-up at 5 ticks per frame, so a slow
    frame cannot spiral.
- **Audio:**
  - SFX are short mono 22 kHz WAVs preloaded into `flame_audio` pools.
  - Music is streamed OGG.

## How to profile

```bash
flutter run --profile                         # on a real device
# DevTools → Performance: check raster vs UI thread per frame
flutter build apk --analyze-size --target-platform android-arm64
```

- **Overlay:** for an fps counter, add Flame's `FpsTextComponent` to
  `PlayGame` in a profile build.
- **Hot spots to watch:**
  - `WorldRenderer.render` when many enemies are on screen (the swarm
    enemy)
  - The CRT shader on Mali-G52 GPUs: use the "arcade" preset; "broken
    tube" adds noise sampling.

## Known limits

- `toImageSync` allocates one GPU texture per frame, and the engine
  recycles it. On very old Mali drivers this can cause frame pacing
  jitter.
  - Fallback idea: draw straight to the canvas with a scale transform
    when the CRT is off. Pixel snapping is already done in the renderer.
- If the CRT shader fails to load (an old GPU or driver), `PlayGame`
  catches the error and keeps the plain `NearestUpscaler`.
