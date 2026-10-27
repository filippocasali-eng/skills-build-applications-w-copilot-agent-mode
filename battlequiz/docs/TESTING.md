# Testing

| Suite | Command | Covers |
| --- | --- | --- |
| Unit | `npm test` | scoring (correct, wrong, timeout, speed bonus, streaks, rounding, immutability), level curve & XP, question bank validation (schema, duplicates, coverage per category/difficulty, ranked flag), selection (difficulty plan, category spread, repetition avoidance, exhaustion, fallback, determinism), answer-position balance, state machine (transitions, delivery, late/duplicate/out-of-order/invalid answers, completion, replay, expiry), React components (RTL) |
| Integration — memory | `npm test` | full 10-question match through the service, player isolation, results gating, 5 simultaneous submits scored once, reconnect keeps timer, no repeats across matches |
| Integration — PostgreSQL | `TEST_DATABASE_URL=… npm test` | migrations apply & are idempotent, seed, check constraints, DB-level duplicate-answer rejection, RLS (anon/authenticated cannot read questions/answers, own-profile only, public view hides email, no self-granted admin, staff read), **and the whole integration suite again on PostgreSQL** |
| E2E (Playwright) | `npm run build && npm run test:e2e` | landing → play, full guest match with review and replay, timeout, language switch, API does not leak answers, cross-site POST rejected — on Desktop Chrome and Pixel 7 |

Latest local run (27 Oct 2026): **101 Vitest tests passed** (incl. PostgreSQL 16), **12 Playwright tests passed** against both the memory and the PostgreSQL store. Coverage of scoring/engine/selection/progression: 98.3 % lines, 94.6 % branches (CI threshold 95 / 90).

Not yet automated: payments, multiplayer, auth (features not built), formal accessibility audit (axe) — planned for M7.
