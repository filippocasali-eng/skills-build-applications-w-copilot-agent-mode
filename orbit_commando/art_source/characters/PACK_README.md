# Arcade Run-and-Gun — Character Animation Pack (Prototype v1)

Eight original 2D pixel-art characters: Roxy, Brutus, Nyx, Doc (heroes); Grunt, Rocket, Cyclops, Bulwark (enemies).

## Contents

- `spritesheets/`: 8 transparent PNG contact sheets, four columns x two rows.
- `frames/<character>/`: 8 individually cropped transparent PNG frames per character.
- `gifs/`: 24 looping animated previews: `run`, `attack`, and `preview` per character.
- `export_animations.sh`: deterministic export from the included sprite sheets using ImageMagick `convert`.

## Animation rows and timing

| Source row | Frames (zero-based) | Action | Loop timing |
|---|---|---|---|
| Top | 0–3 | Run / walk / hover patrol | 120 ms per frame |
| Bottom | 4–7 | Attack / fire | 140 ms per frame |

The animations are keyframe prototypes, not final polished sprite animation. AI-generated cells may vary slightly in size and alignment, and a few effects may approach or cross tile edges. Review collision shapes and adjust frame pivots/feet baselines before using in a released game. The frames are currently concept-resolution: downscale consistently with nearest-neighbor filtering to preserve pixels. Avoid smoothing and bilinear interpolation.

## Engine setup

Import each PNG frame as a transparent 2D sprite. Group frames 0–3 into a looping movement animation, and 4–7 into a looping attack animation. Keep a common anchor point at the feet, and align imported frames to that anchor. Use 8.33 fps for movement and about 7.14 fps for attack. Roxy, Brutus, Nyx, and Doc face right; the enemies face left by default. Flip horizontally in engine when required.

The GIFs are for quick preview; use the PNGs inside the actual game to avoid GIF palette limitations.
