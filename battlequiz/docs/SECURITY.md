# Security

## Implemented (M1)
| Threat | Control | Where |
| --- | --- | --- |
| Score manipulation | Client sends only `{questionIndex, selectedIndex}`; score/time computed server-side | `engine.ts`, `service.ts` |
| Answer leakage / scraping | Public question view has no correct index or explanation; next question only after the current is answered; RLS denies clients `questions` | `toPublicQuestion`, migration |
| Extra time via refresh | Timer fixed at first delivery; re-fetch returns remaining time | `deliverCurrentQuestion` |
| Late answers | > limit + 1 s grace → timeout, consistently | `isLate` |
| Duplicate / concurrent submits | Idempotent replay of stored result; optimistic version check; PK on `player_answers` | engine, `postgres.ts` |
| Replay of completed matches | Terminal states have no transitions | `MATCH_TRANSITIONS` |
| Reading others' matches | Signed (HMAC-SHA256) httpOnly guest cookie; ownership check returns 404 | `guest.ts`, `loadOwned` |
| CSRF | SameSite=Lax cookie + Origin/`Sec-Fetch-Site` check on POST | `sameOrigin` |
| Request floods / bots | Per-IP fixed-window rate limits (create 20/min, answer 90/min, read 240/min) | `rate-limit.ts` |
| Automated answering | Audit event when ≥ 3 correct answers arrive in < 350 ms | `service.ts` |
| Input abuse | Zod validation of every body/param | `validation/api.ts` |
| Admin escalation | `staff_roles` server-managed; `is_staff()` security definer; RLS-tested | migration, `db.test.ts` |
| Browser hardening | CSP, HSTS, X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy, no `x-powered-by` | `next.config.ts` |
| Secrets | Server-only modules (`server-only`), no `NEXT_PUBLIC_` secrets, errors logged without payloads | `lib/store/index.ts`, `http.ts` |

## Known limitations (honest)
- The in-memory rate limiter is per instance. On Vercel add Vercel Firewall rate-limit rules or a Postgres/Redis counter before launch.
- Guest cookies identify a browser, not a person; mass guest creation is only rate-limited. Ranked modes will require accounts (M2+).
- A browser trivia game cannot stop players from looking answers up elsewhere; the 12 s limit and speed bonus are the mitigation.
- CSP uses `'unsafe-inline'` for scripts (Next.js bootstrap). Move to nonce-based CSP before launch.
- Account deletion / data export, blocking and reporting UIs arrive with accounts (M2–M3). Tables exist.
- The memory store is not durable; production refuses to run without `DATABASE_URL` unless explicitly overridden.
