# Scoring Rules — ruleset `v1`

Implemented in `src/lib/scoring/index.ts` (pure, frozen, unit-tested). Every match stores its `ruleset_version`; published rulesets are never modified — new rules get a new version.

| Parameter | Value |
| --- | --- |
| Time limit | 12 000 ms |
| Latency grace | 1 000 ms (answers received ≤ 13 s count; later = timeout) |
| Base points | easy 100 · medium 150 · hard 200 · expert 250 |
| Speed bonus | `round(100 × remaining / 12000)`, remaining = max(0, 12000 − elapsed) |
| Streak multiplier (n-th consecutive correct) | 1 → 1.0 · 2 → 1.1 · 3 → 1.2 · 4 → 1.3 · ≥5 → 1.5 |

```
points = round((base[difficulty] + speedBonus) × multiplier(previousStreak + 1))
wrong or timeout → 0 points, streak = 0
```

`elapsed` is measured **on the server** from the moment the question was first delivered to the moment the answer arrived. Network latency therefore slightly reduces the bonus, equally for everyone; the grace window only decides whether an answer counts.

Example: medium question answered after 3 s on a 3-streak → (150 + 75) × 1.3 = 292.5 → **293**.

## XP (`src/features/progression/levels.ts`)
Completed match: 20 + 10 per correct answer + 50 if perfect. Abandoned/expired: 0.
Level n→n+1 costs `100 + 50·(n−1)` XP → L2 100, L3 250, L4 450, L5 700 (configurable `LevelCurve`, max level 100).
In M1 guest XP is stored on the device only and credited once per match id.
