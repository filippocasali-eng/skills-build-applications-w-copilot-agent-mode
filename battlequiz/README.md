# BattleQuiz

**Think Fast. Battle Smart. Win Big.** — a fast, competitive, social trivia game (Italian first, English second).

Status: **Milestone 1 (Playable MVP) complete.** Guest Quick Play works end to end with server-authoritative scoring, on either PostgreSQL or an in-memory development store. See [docs/PROGRESS.md](docs/PROGRESS.md) for exactly what is and isn't built.

## Run it locally

Requirements: Node.js ≥ 20.9 (tested on 22), npm. PostgreSQL 15+ is optional.

```bash
cd battlequiz
npm install
npm run dev            # http://localhost:3000 — in-memory LOCAL DEVELOPMENT store
```

With a real database (local PostgreSQL or Supabase):

```bash
cp .env.example .env.local          # then fill DATABASE_URL and GUEST_COOKIE_SECRET
# Plain local PostgreSQL (emulates Supabase roles/auth schema — never on Supabase itself):
DATABASE_URL=postgres://user:pass@localhost:5432/battlequiz npm run db:setup-local
# Supabase project (roles and auth already exist):
DATABASE_URL=... npm run db:migrate && DATABASE_URL=... npm run db:seed
npm run dev
```

`GET /api/health` reports which store is active (`memory` or `postgres`).

## Android APK

Download the latest APK from the repository's **Releases → `battlequiz-android-latest`** (built by GitHub Actions), or build it yourself — see [DEPLOYMENT](docs/DEPLOYMENT.md#android-app-apk). The app plays Quick Play offline.

## Checks

```bash
npm run lint
npm run typecheck
npm test                       # unit + integration (Postgres tests skipped)
TEST_DATABASE_URL=postgres://…/battlequiz_test npm test   # also runs PostgreSQL + RLS tests (DROPS that DB's schema)
npm run test:coverage
npm run build && npm run test:e2e   # Playwright, desktop + mobile
```

## Documentation

| Doc | Contents |
| --- | --- |
| [PRODUCT_REQUIREMENTS](docs/PRODUCT_REQUIREMENTS.md) | Vision, audience, modes, acceptance criteria |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | System diagram, layers, request flow, decisions |
| [DATABASE_SCHEMA](docs/DATABASE_SCHEMA.md) | Tables, constraints, RLS model |
| [GAME_DESIGN](docs/GAME_DESIGN.md) | Loop, screens, UX, design system |
| [SCORING_RULES](docs/SCORING_RULES.md) | Exact formula, ruleset versioning |
| [SECURITY](docs/SECURITY.md) | Threat model, anti-cheat, known limits |
| [TESTING](docs/TESTING.md) | What is tested and how |
| [DEPLOYMENT](docs/DEPLOYMENT.md) | Vercel + Supabase setup, manual steps |
| [MONETIZATION](docs/MONETIZATION.md) | Freemium model, Plus, ads policy |
| [ROADMAP](docs/ROADMAP.md) | Milestones 0–7 |
| [PROGRESS](docs/PROGRESS.md) | What's done, verified, and outstanding |
