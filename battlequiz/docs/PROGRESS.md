# Progress

_Last updated: 27 Oct 2026 — Milestone 1 complete; Milestone 2 not started (awaiting go-ahead)._

## Milestone 0 — Product & architecture ✅
Docs in this folder; full schema migration (30 tables incl. `staff_roles`, RLS on all) applied and tested on PostgreSQL 16.

## Milestone 1 — Playable MVP ✅ (acceptance passed)
**Working and verified**
- Landing page: hero, Play Now, modes (with honest "coming soon" badges), how it works, leaderboard design preview (labelled as example data), pricing (Plus marked not available), FAQ, legal links.
- Guest Quick Play: category picker (Mix + 14), 3-2-1 countdown, 10 questions with progressive difficulty, 12 s server-enforced timer, speed bonus, streak multiplier, timeout handling, feedback animations, keyboard play, optional synthesized sound.
- Results: score, accuracy, best streak, average time, XP/level (device-local for guests), personal best, share, replay, full answer review with explanations, confetti.
- Server-authoritative engine with persisted question sequence, balanced answer positions, idempotent submissions, optimistic concurrency, expiry, audit + fast-answer anomaly logging.
- Storage: PostgreSQL adapter (Supabase-compatible) and clearly labelled in-memory dev store.
- Question bank: 168 questions × IT/EN, 14 categories, all 4 difficulties, schema-validated.
- i18n IT (default) / EN; reduced motion; security headers; rate limits; CSRF check; signed guest cookie.
- Draft Privacy / Terms / Cookie pages, flagged for legal review.
- Tests: 101 Vitest (unit, RTL, integration on memory + PostgreSQL incl. RLS), 12 Playwright e2e (desktop + mobile). Lint, typecheck, production build pass.

**Not in M1 (by plan)**: accounts, persistent server-side progression, achievements unlock, friends, daily challenge, leaderboards, live multiplayer, AI generation, admin dashboard, shop/subscriptions, analytics dashboard, settings screen (language & sound toggles exist inline; motion follows the OS).

## Known issues / caveats
- Seed questions were written with AI assistance from stable, well-known facts and reference articles; they are `approved` for casual play but `ranked_eligible = false` until a human editor signs them off.
- Guest progress (XP/level/best) lives in localStorage and can be lost; this is by design until accounts exist.
- In-memory rate limiter is per instance (see SECURITY.md).
- CI workflow is written but has not yet run on GitHub at the time of writing.

## External blockers for later milestones
| Needed for | What the product owner must provide |
| --- | --- |
| M2 | Supabase project (URL, anon key, service role key), Google OAuth client, SMTP/email settings |
| M5 | Anthropic API key + monthly budget cap |
| M6 | Stripe test-mode keys, product/price ids; explicit approval before live payments |
| Launch | legal entity details, lawyer review, production deploy approval |
