# Roadmap

| Milestone | Scope | Status |
| --- | --- | --- |
| 0 · Product & architecture | requirements, architecture, schema, design system, risks | ✅ done (docs/, migration) |
| 1 · Playable MVP | landing, guest Quick Play, question DB, timer, scoring, results, replay, animations, tests | ✅ done & verified |
| 2 · Accounts & progression | Supabase Auth (email + verification, Google OAuth, reset), guest → account upgrade, profiles, persistent stats, XP ledger, achievements engine, match history, deletion & export | ⏭ next — awaiting go-ahead |
| 3 · Social | friends, requests, blocks/reports, async Friend Battle + invite links, Daily Challenge, leaderboards (daily/weekly/all-time/friends) | planned |
| 4 · Live multiplayer | private rooms, matchmaking, synchronized timers, Realtime events, reconnection, rematch | planned |
| 5 · AI content pipeline | Claude batch generation (offline), strict JSON schema, dedupe, quality checks, review queue, cost tracking, admin question management | planned |
| 6 · Monetization | Stripe test mode, Plus, cosmetics shop & inventory, entitlements | planned |
| 7 · Production readiness | security & a11y audit, performance, nonce CSP, shared rate limiting, legal review, launch report | planned |

## Risks
| Risk | Mitigation |
| --- | --- |
| Question factual errors | stable well-known facts only, sources recorded, report flow, human review before ranked |
| Content volume (168 per locale) | AI pipeline (M5) with review; history-aware selection meanwhile |
| Cheating via lookup | short timer, speed bonus, anomaly audit |
| Serverless state | all match state in Postgres; memory store dev-only |
| Legal/GDPR | minimal data, draft policies flagged for review |
