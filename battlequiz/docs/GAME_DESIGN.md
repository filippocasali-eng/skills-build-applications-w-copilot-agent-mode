# Game Design

## App experience (v0.2)
The game runs in a native-style **app shell** (`src/components/app`), used by the Android app and by the web at `/app` and `/play`:
- **Bottom tab bar:** Home · Gioca · Trofei · Profilo, with an animated active indicator and haptic feedback.
- **Home:** greeting + avatar, day-streak flame, level ring and XP bar, Quick Play hero card, Daily Challenge card (state + countdown to the next UTC day), category carousel, next-trophy progress, recent matches.
- **Gioca:** mode cards (Quick Play, Daily Challenge, locked Friend Battle and Live 1v1) and a category practice grid.
- **Trofei:** 11 achievements with progress bars, rewards and unlock dates; personal records.
- **Profilo:** large avatar, level, six stat tiles, accuracy by category, match history.
- **Settings** (pushed screen): nickname, avatar colour, language, sound, vibration, animations, reset progress (bottom-sheet confirmation), version, legal.
- **Onboarding** on first launch: three slides + nickname and colour; skippable.
- **Match** is a full-screen pushed page: question card at the top, answers at the bottom in thumb reach, quit confirmation as a bottom sheet, results with level-up and unlocked trophies and sticky actions.
- Native polish: edge-to-edge with safe areas, light system-bar icons, Android back button (closes sheets, confirms quitting a live match, pops screens, returns to Home), haptics, no text selection or tap highlight in the UI, press-scale feedback.

## Progression (on device until accounts exist)
`src/features/progression/player.ts` (pure, tested): XP, levels, day streak (local calendar), per-category accuracy, history (last 50), daily results, idempotent crediting by match id. Achievements: `src/features/achievements/catalog.ts`; multiplayer ones stay locked until battles exist.

## Flow (M1)
Landing → **Setup** (category: Mix + every category with ≥ 10 approved questions) → **3-2-1 countdown** (the server timer starts only after it) → **10 questions** → **Results** → Play again.

## Game screen
Quit · 10-segment progress bar (green correct / red wrong / amber timeout) · sound toggle · animated score · streak flame (≥ 2) · countdown ring (cyan → amber ≤ 6 s → red pulse ≤ 3 s) · question card with category + difficulty · four large answer buttons (A–D, keys 1–4 / A–D) · feedback strip with points pop.
After answering: pending state → correct (green glow) / wrong (red shake) + correct answer revealed. Auto-advance after 1.1 s (correct) or 1.8 s (miss); explanations are shown in the results review so play isn't interrupted.

## Results
Grade (≥ 90 % Legendary, ≥ 70 % Great, ≥ 40 % Good), animated score, personal-best badge, stats (correct, accuracy, best streak, average time), XP + level bar, Play again, Share (Web Share API or clipboard, emoji grid, no tokens), Challenge friend (disabled, M3), account-benefits card after the first match, collapsible answer review with explanations, confetti on great results.

## Design system
Tokens in `src/app/globals.css`: bg `#0B1020`, surface `#151B30`, primary `#7C3AED`, secondary `#06B6D4`, success `#22C55E`, error `#EF4444`, gold `#FBBF24`, text `#F8FAFC`. Fonts: Outfit (display) + Inter (body), self-hosted by `next/font`. Rounded 2xl/3xl cards, glass surfaces, ambient glows + particles. Lucide icons, Motion (`motion/react`) animations, shadcn-style `Button` (cva).
Original logo (shield + bolt "Q") drawn as inline SVG. No third-party game assets.

## Accessibility
Reduced motion: honours OS setting via `MotionConfig reducedMotion="user"` and CSS; confetti and count-ups disabled. Visible focus rings, labelled buttons (`Risposta A: …`), `role=timer`, `aria-live` feedback, keyboard play. Audio never carries information.

## Sound
Original tones synthesised with Web Audio (no files, no licensing). Off by default, created only after a user gesture, mute toggle on every game screen.

## Question selection
Difficulty plan E-E-E-M-M-M-H-H-H-X. Unseen questions first (last 120 seen are deprioritised), then nearest difficulty, then least-recently seen. Mixed mode: ≤ 3 per category, no back-to-back category. Correct-answer position drawn from a balanced bag (each of A–D 2–3 times per match).
