# Architecture

```
 Browser (Next.js client components, Zustand)          Server (Next.js route handlers, Node runtime)
 ┌──────────────────────────────┐   fetch JSON   ┌──────────────────────────────────────────────┐
 │ PlayClient → stores/game.ts  │ ─────────────▶ │ app/api/matches/**  (Zod, rate limit, CSRF,   │
 │  Setup · Countdown · Game ·  │ ◀───────────── │  signed guest cookie)                         │
 │  Results  (motion, lucide)   │  no answers    │        │                                       │
 └──────────────────────────────┘  until locked  │        ▼                                       │
                                                 │ features/gameplay/service.ts (orchestration,  │
                                                 │  optimistic concurrency + retries, audit)     │
                                                 │        │ pure                                  │
                                                 │ engine.ts · selection.ts · lib/scoring        │
                                                 │        │                                       │
                                                 │ lib/store: Repositories interface              │
                                                 │   ├─ memory.ts   (LOCAL DEV MODE)              │
                                                 │   └─ postgres.ts (pg → Supabase Postgres)      │
                                                 └──────────────────────┬───────────────────────┘
                                                                        ▼
                                                  Supabase PostgreSQL (RLS on every table)
```

## Layers
- **Domain (pure TS, no React/DB):** `src/lib/scoring`, `src/features/gameplay/engine.ts` (state machine), `src/features/questions/selection.ts`, `src/features/progression/levels.ts`. Fully unit-tested.
- **Service:** `src/features/gameplay/service.ts` — loads state, applies a pure transition, saves with `expectedVersion`; on conflict re-reads and retries (max 4). Idempotent duplicates return the stored result.
- **Persistence:** `Repositories` interface. `postgres.ts` writes `matches`, `match_players`, `match_questions`, `player_answers` in one transaction guarded by `UPDATE … WHERE version = $expected`; the `player_answers` primary key is a second duplicate guard.
- **HTTP:** thin route handlers in `src/app/api`. `src/lib/http.ts` provides error mapping, same-origin check, rate limiting, guest identity.
- **UI:** `src/components/{game,landing,layout,ui}`; client state in `src/stores` (Zustand). The client mirrors server state; it never computes score.

## Request flow (Quick Play)
1. Countdown (client only) → `POST /api/matches {locale, category}` → server selects 10 questions (difficulty plan, history-aware, category spread), fixes a balanced answer order, **delivers Q1 and starts its timer**, returns the public question.
2. `POST /api/matches/:id/answers {questionIndex, selectedIndex|null}` → server measures elapsed time from its own `current_issued_at`, rejects late answers (> 12 s + 1 s grace) as timeouts, scores, advances. Returns feedback incl. the correct index.
3. After the feedback animation the client calls `GET /api/matches/:id/question`, which delivers the next question and starts its timer. Re-fetching never resets the timer (reconnect-safe).
4. On completion `GET /api/matches/:id/results` returns score, stats, XP and the full review with explanations.

## Key decisions
- **Direct `pg` instead of supabase-js on the server:** transactions + row locks for answer submission; works with Supabase's connection string. supabase-js/Auth/Realtime will be added in M2/M4 for auth and event distribution only.
- **Next question fetched separately** rather than bundled with feedback, so the feedback animation never eats into the next timer and future questions never reach the client early.
- **In-memory store** keeps the app runnable with zero setup; it refuses to start in production unless `BATTLEQUIZ_ALLOW_MEMORY_STORE=true`.
- **Question bank as validated JSON seed** (`src/data/questions`) — one source for dev mode and `npm run db:seed`.
- **Monolith:** no microservices. Next.js App Router 16 with Cache Components; API routes are dynamic.
- The app lives in `battlequiz/` because the repository root hosts an unrelated GitHub Skills exercise whose grading workflows must stay intact.
