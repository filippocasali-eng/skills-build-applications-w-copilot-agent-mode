# Multiplayer plan

## What v1 ships

- **Weekly Challenge with a ghost:** one level, a modifier and a fixed seed
  per ISO week. Your best run is saved as a replay and raced as a
  translucent ghost (`LocalGhostService`, stored in the save, last 6 boards
  only).
- **Local high-score tables:** Arcade and Boss Rush, with 3-letter
  initials.
- **Chat:** a demo service that is clearly labelled "offline demo" until a
  backend URL is configured (`backend/`).

## Why it is cheap to add online play

The game was built for it from day one:

| Property | Where | Why it matters |
|---|---|---|
| Deterministic 60 Hz simulation, no floating time steps | `GameSim`, `FixedStepClock` | Same inputs → same game, on any device |
| Own PRNG (xorshift32), seeded per run | `DetRandom` | No dependence on `dart:math` |
| Input packed in one int per tick | `InputFrame.pack` | A 2-minute run is ~7,200 ints, RLE-compressed to a few KB |
| `stateHash()` | `GameSim` | Test (`game_sim_test.dart`) checks 10,000 ticks reproduce bit-exactly |
| `MultiplayerService` interface | `lib/core/multiplayer/multiplayer.dart` | The online service plugs in without touching game code |

## v1.1 — online leaderboards and ghosts (low risk)

1. **Auth:** Firebase anonymous sign-in. Optionally link Google Play
   Games for a stable identity across devices.
2. **Submitting a run:** `submit(board, replay)` uploads the replay (seed,
   level id, RLE inputs, claimed score, game version).
3. **Server verification:** a Cloud Function runs the same Dart
   simulation, compiled with `dart compile js` or run in a Dart container
   on Cloud Run. It replays the inputs and compares the score and the
   final `stateHash`. Only verified runs enter `boards/{board}/entries`.
   This makes cheating require a genuinely playable input sequence
   (tool-assisted runs are possible, as in any replay-verified game; flag
   top-10 runs for review).
4. **Download:** `bestGhost(board)` downloads the replay of the world #1,
   your friend's best or the run just above yours.
5. **Version pinning:** replays store the balance hash; a board only
   accepts runs from the balance it was created with.

## v1.5 — asynchronous co-op challenges

"Squadron score attack": squads of up to 30 sum their weekly scores. This
needs only the leaderboard plus the squad document; no realtime networking.

## v2 — realtime 2-player co-op (deterministic lockstep with rollback)

| Topic | Plan |
|---|---|
| Model | Rollback netcode (GGPO-style). Both peers run the full sim; only inputs travel. |
| Transport | WebRTC data channel (unreliable, unordered), with a TURN relay as fallback. Signalling through Firestore or a small WebSocket service. |
| Input delay | 2 frames of local delay, plus up to 8 frames of rollback. |
| Sim requirements | `GameSim` must snapshot and restore in under 1 ms. Today the state is plain Dart objects. Add `GameSim.snapshot()`, which copies the pools (bullets, enemies, pickups); the pools are fixed-size, which helps. |
| Desync detection | Exchange `stateHash` every 60 ticks; on mismatch, resync from the host's snapshot. |
| Second player | A second `Player` in the sim, fed by a second input stream. Camera: shared framing with zoom-out, or split focus on planetoids. |
| Matchmaking | Friends and squad invites first; no random matchmaking for under-18s. |
| Cost | Peer-to-peer means no game servers; TURN relay bandwidth (~2 KB/s per player) is the only running cost. |

## Risks

- **Floating point:** Dart doubles are IEEE-754 on every target, but
  transcendental functions (`sin`, `atan2`) could differ across CPU
  libraries.
  - Mitigation in v2: lookup tables for trigonometry inside the sim.
  - Mitigation now: a CI check that runs the determinism test on ARM and
    x86.
- **Replay size for long runs:** RLE keeps typical runs under 10 KB.
  Cap online Boss Rush submissions at 20 minutes.
