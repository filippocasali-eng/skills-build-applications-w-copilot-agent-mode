# Deployment (Vercel + Supabase)

**Not deployed.** No production deployment is performed without explicit approval.

## Manual configuration
1. **Supabase:** create a project (EU region for Italian users). Copy the *pooled* connection string (port 6543, `?sslmode=require`).
2. Apply schema & seed from your machine:
   `DATABASE_URL=… npm run db:migrate && DATABASE_URL=… npm run db:seed`
   (Do **not** run `db:setup-local` on Supabase — it emulates Supabase roles for plain PostgreSQL.)
   Alternatively paste the migration into the Supabase SQL editor.
3. **Vercel:** import the repo, set *Root Directory* = `battlequiz`, framework Next.js. Environment variables:
   - `DATABASE_URL` (pooled), `DATABASE_POOL_MAX=1` or `2` for serverless
   - `GUEST_COOKIE_SECRET` = `openssl rand -hex 32`
4. Add a Vercel Firewall rate-limit rule for `/api/matches*` (see SECURITY.md).
5. Verify `GET /api/health` returns `{"store":"postgres"}`.

## CI
`.github/workflows/battlequiz-ci.yml` (repo root) runs on changes under `battlequiz/**`: install, lint, typecheck, unit + PostgreSQL integration tests (service container), production build, Playwright e2e.

## Release checklist (M7)
Legal review of `/privacy`, `/terms`, `/cookies` · nonce CSP · shared rate limiter · backups & PITR on Supabase · error monitoring · human review of seed questions before ranked use.

## Android app (APK)
The Android app is the same UI as a static export wrapped with **Capacitor 8** (`android/`). It runs **offline**: the tested game engine and the bundled question bank execute on the device (`src/features/gameplay/local-api.ts`), so no server is needed. Offline scores are local and unranked by design; ranked modes will always use the server.

- Build in CI: `.github/workflows/battlequiz-android.yml` runs `npm run build:android` + `./gradlew assembleDebug` and publishes the APK on the **`battlequiz-android-latest`** GitHub pre-release (also as a workflow artifact).
- Build locally (needs JDK 21 + Android SDK 36): `npm run build:android && cd android && ./gradlew assembleDebug` → `android/app/build/outputs/apk/debug/app-debug.apk`.
- Icons/splash: `npm run android:assets` regenerates them from the logo.
- Install: on the phone open the release page, download the `.apk`, allow "Install unknown apps" for the browser, install.
- The APK is **debug-signed** (sideloading/testing only). The Play Store needs a release keystore (store it as a GitHub secret) and an `.aab` — not set up yet.
