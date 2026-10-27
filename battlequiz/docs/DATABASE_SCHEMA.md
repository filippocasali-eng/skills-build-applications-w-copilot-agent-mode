# Database Schema

Migration: `supabase/migrations/20261027000000_initial_schema.sql` (all 29 required tables + `staff_roles`, `public_profiles` view, reference data). Applied and tested on PostgreSQL 16.

## Security model
- RLS enabled on **every** table and all privileges revoked from `anon`/`authenticated`; access is then granted narrowly.
- The Next.js server connects with a privileged role and is the only writer of matches, scores, XP and rewards.
- `questions`, `match_questions`, `player_answers`: **no client access** (anon: permission denied; authenticated non-staff: 0 rows). Staff read via `is_staff()` policy.
- Admin rights live in `staff_roles`, writable only server-side — never a profile field. Tested: users cannot insert themselves.
- `public_profiles` view exposes username, display name, avatar, level only (no email, no private settings).

## Tables
| Area | Tables | Notable constraints |
| --- | --- | --- |
| Identity | `profiles`, `staff_roles` | username regex + unique; visibility enums |
| Questions | `question_categories`, `questions`, `question_versions`, `question_reviews` | exactly 4 options, correct_index 0–3, `unique(locale, fingerprint)` duplicate detection, `ranked_eligible ⇒ approved` |
| Matches | `matches`, `match_players`, `match_questions`, `player_answers`, `player_question_history` | `version` for optimistic concurrency; `player_answers` PK `(match, player, question_index)` blocks duplicate answers |
| Progression | `player_stats`, `xp_transactions`, `achievements`, `player_achievements`, `cosmetic_items`, `player_inventory` | `xp_transactions unique(user, source_type, source_id)` and `player_inventory unique(user, grant_key)` → idempotent rewards |
| Daily / ranks | `daily_challenges`, `daily_challenge_entries`, `leaderboard_snapshots` | entry PK `(challenge, user)` = one ranked attempt; rank index `(score desc, total_elapsed_ms, completed_at)` = tie-break |
| Social | `friend_requests`, `friendships`, `blocks`, `challenge_invitations`, `user_reports` | one pending request per pair; friendships stored once with `user_a < user_b`; invitation codes are random, never auth tokens |
| Billing | `subscriptions`, `billing_events` | `billing_events.stripe_event_id` PK = webhook replay protection |
| AI | `ai_generation_jobs`, `ai_usage` | batch size 1–50, attempts ≤ 3, cost per call recorded |
| Audit | `audit_events` | salted `ip_hash` only, no raw IPs, no secrets |

`player_key` is `guest:<uuid>` or `user:<uuid>`, so guest and account matches share one model.

## Seed
`npm run db:seed` inserts the 168 × 2 bundled questions (`on conflict do nothing`, so admin edits are never overwritten). Achievements (10) and categories (14) are inserted by the migration.
