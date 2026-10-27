# Product Requirements

## Vision
BattleQuiz is a fast-paced, competitive, social trivia game mixing casual-game accessibility, game-show excitement and modern progression. A player understands it within 10 seconds and finishes a satisfying first match within 3 minutes.

**Audience:** casual mobile gamers, students, friends and families, trivia fans, ages 16–45, short sessions.
**Markets:** Italy (default language Italian) → English-speaking markets → other European markets. All UI strings are localized (`src/i18n`).

## Core loop
Open → start match → 10 server-selected questions, 4 answers, 12 s each → server validates and scores → next question → results (score, accuracy, XP, review) → play again / share / challenge (M3).

## Modes
| Mode | Milestone | Key rules |
| --- | --- | --- |
| A · Quick Play | **M1 — shipped** | 10 questions, progressive difficulty (3 easy, 3 medium, 3 hard, 1 expert), 12 s, speed + streak scoring |
| B · Daily Challenge | M3 | Same ordered questions per locale + ruleset per UTC day (`YYYY-MM-DD:locale:ruleset`), one ranked attempt (`daily_challenge_entries` PK) |
| C · Friend Battle (async) | M3 | A plays, B replays the same persisted sequence, server compares |
| D · Live 1 vs 1 | M4 | Server-authoritative state machine; Realtime only distributes events |
| E · Tournaments | post-MVP | Cosmetic prizes only; no real money, paid entry or wagering |

## Non-negotiables
- Server-authoritative scoring, timing and match state; the client never receives correct answers before the answer is locked.
- Premium never grants ranked advantages; essential gameplay is never paywalled.
- AI generates questions offline into a review queue; never during a match.
- Privacy-preserving defaults; no email in public profiles.

## Milestone 1 acceptance criteria (all verified — see TESTING.md)
1. A guest can complete a full 10-question match without errors (e2e, desktop + mobile).
2. Timer expiry records a timeout with zero points (e2e + unit).
3. Scoring is deterministic and matches SCORING_RULES.md (unit).
4. Correct answers and explanations are not exposed before an answer is locked (e2e + unit).
5. Duplicate / concurrent submissions are scored exactly once (integration, memory + PostgreSQL).
6. Players cannot read each other's matches (integration).
7. Italian default, English switchable (e2e).
8. Production build, lint, typecheck pass.
