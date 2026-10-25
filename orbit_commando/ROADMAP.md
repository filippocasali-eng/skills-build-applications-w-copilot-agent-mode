# Roadmap — 15 ideas for v1.1 → v2

Ordered roughly by value ÷ effort. Each idea reuses what v1 already has.

| # | Idea | Target | Builds on |
|---|---|---|---|
| 1 | **Online weekly leaderboards with verified replays.** The server re-simulates the inputs before accepting a score. | v1.1 | `GameSim` determinism, `MultiplayerService` (see `MULTIPLAYER_PLAN.md`) |
| 2 | **Friend ghosts.** Race the ghost of a friend or squad mate instead of your own. | v1.1 | Replay + ghost renderer |
| 3 | **World 4 "Glorbo Bureau of Taxes".** 5 levels with a new gravity type: rotating rings with centrifugal "down". | v1.2 | `GravityField` (add a ring field), level DSL |
| 4 | **Level editor on the phone.** Players place pieces on a grid; levels are shared as a short code. Pieces include segments, planetoids, spawners and hostages. | v1.3 | Tiled JSON format, validator ported to Dart |
| 5 | **Daily "Orbit Run".** A procedurally assembled level, the same for everyone that day, built from hand-made chunks. | v1.2 | Level generator chunks, fixed seed |
| 6 | **Photo mode.** Pause, free camera, CRT presets and stickers, then share a PNG. | v1.1 | Pixel renderer, collectible stickers |
| 7 | **Speedrun mode.** IGT/RTA timer, splits, route-friendly skips and a "no capsule items" category. | v1.1 | Fixed tick clock, results screen |
| 8 | **Two new heroes with real moves.** A hover-boots pilot (slow fall) and a grappling-hook engineer (latches onto planetoids). | v1.3 | `Commando` roster, player state machine |
| 9 | **Vehicle #4: gravity tank.** Treads stick to any surface and drive around a planet's full circumference. | v1.2 | Vehicle module, capsule physics |
| 10 | **Mission board.** Weekly objectives ("free 20 hostages using only the flamethrower"), cosmetic rewards and no FOMO: missions rotate back. | v1.1 | Stats, trophies, remote config |
| 11 | **Accessibility pack.** One-button aim lock, adjustable game speed (80 %), high-contrast enemy outlines, a colour-blind palette for projectile tells and subtitles for boss taunts. | v1.1 | Palette system, `Balance` |
| 12 | **Gamepad and Android TV support.** Full D-pad menus and 10-foot UI scaling. | v1.2 | Keyboard controls already exist, `PixelButton` focus |
| 13 | **Boss Rush "Remix".** Bosses with swapped patterns and mixed arenas; leaderboard only. | v1.2 | Boss pattern tables |
| 14 | **Real-time 2-player co-op over rollback netcode.** | v2 | Deterministic sim, `stateHash` (see `MULTIPLAYER_PLAN.md`) |
| 15 | **Cloud save and cross-device progress.** Through Play Games Services or Firebase Auth, with server-owned wallet. | v2 | `SaveStore.toJson()`, backend wallet |

## Technical debt to clear first

- Move the wallet to the server (gems are local in v1).
- Add `GameSim.snapshot()/restore()` (needed by rollback and by idea #4's
  test play).
- Add trigonometry lookup tables inside the sim, for cross-CPU determinism.
- Put a CI device farm smoke test (Firebase Test Lab, Robo script) on the
  release branch.
