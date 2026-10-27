-- BattleQuiz initial schema.
-- Target: Supabase PostgreSQL (auth.users / auth.uid() provided by Supabase).
-- Security model:
--   * RLS is enabled on every table. Default is deny.
--   * The Next.js server connects with a privileged role (table owner / service role)
--     and is the only writer of game state, scores, XP and rewards.
--   * Browser clients (anon/authenticated) may only read or change the rows that the
--     policies below allow. Questions and answers are NEVER readable by clients.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Identity & administration
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  display_name text check (char_length(display_name) <= 40),
  avatar_id text not null default 'default',
  locale text not null default 'it' check (locale in ('it', 'en')),
  leaderboard_visibility text not null default 'friends' check (leaderboard_visibility in ('public', 'friends', 'private')),
  profile_visibility text not null default 'public' check (profile_visibility in ('public', 'friends', 'private')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Server-managed staff roles. Never derived from a client-editable profile field.
create table public.staff_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('admin', 'moderator')),
  granted_by uuid references auth.users (id),
  granted_at timestamptz not null default now()
);

create or replace function public.is_staff(required_role text default 'admin')
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.staff_roles s
    where s.user_id = auth.uid()
      and (s.role = required_role or s.role = 'admin')
  );
$$;

-- ---------------------------------------------------------------------------
-- Questions
-- ---------------------------------------------------------------------------

create table public.question_categories (
  id text primary key,
  sort_order int not null default 0,
  name_it text not null,
  name_en text not null,
  icon text not null,
  active boolean not null default true
);

create table public.questions (
  id text primary key,
  translation_key text not null,
  locale text not null check (locale in ('it', 'en')),
  category_id text not null references public.question_categories (id),
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard', 'expert')),
  text text not null check (char_length(text) between 8 and 300),
  options text[] not null check (array_length(options, 1) = 4),
  correct_index smallint not null check (correct_index between 0 and 3),
  explanation text not null,
  source_kind text not null check (source_kind in ('editorial', 'seed_ai_assisted', 'ai_generated')),
  source_reference text not null,
  review_status text not null default 'pending_review' check (review_status in ('draft', 'pending_review', 'approved', 'rejected')),
  ranked_eligible boolean not null default false,
  version int not null default 1 check (version > 0),
  -- Normalised text used for duplicate detection.
  fingerprint text generated always as (lower(regexp_replace(text, '\s+', ' ', 'g'))) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (translation_key, locale),
  unique (locale, fingerprint),
  -- Ranked play requires an approved question.
  check (not ranked_eligible or review_status = 'approved')
);
create index questions_playable_idx on public.questions (locale, review_status, category_id, difficulty);

create table public.question_versions (
  question_id text not null references public.questions (id) on delete cascade,
  version int not null,
  snapshot jsonb not null,
  edited_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  primary key (question_id, version)
);

create table public.question_reviews (
  id uuid primary key default gen_random_uuid(),
  question_id text not null references public.questions (id) on delete cascade,
  reviewer_id uuid references auth.users (id),
  decision text not null check (decision in ('approved', 'rejected', 'changes_requested')),
  notes text,
  created_at timestamptz not null default now()
);
create index question_reviews_question_idx on public.question_reviews (question_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Matches
-- player_key identifies a participant: 'guest:<uuid>' or 'user:<uuid>'.
-- ---------------------------------------------------------------------------

create table public.matches (
  id uuid primary key,
  mode text not null check (mode in ('quick_play', 'daily_challenge', 'friend_battle', 'live_1v1', 'tournament')),
  status text not null check (status in ('CREATED', 'WAITING', 'READY', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED')),
  locale text not null check (locale in ('it', 'en')),
  category text not null,
  ruleset_version text not null,
  ranked boolean not null default false,
  created_by text not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  version int not null default 0
);
create index matches_status_idx on public.matches (status, created_at);

create table public.match_players (
  match_id uuid not null references public.matches (id) on delete cascade,
  player_key text not null,
  user_id uuid references auth.users (id) on delete set null,
  current_index int not null default 0,
  current_issued_at timestamptz,
  score int not null default 0 check (score >= 0),
  streak int not null default 0,
  best_streak int not null default 0,
  joined_at timestamptz not null default now(),
  finished_at timestamptz,
  primary key (match_id, player_key)
);
create index match_players_user_idx on public.match_players (user_id, joined_at desc);
create index match_players_key_idx on public.match_players (player_key, joined_at desc);

create table public.match_questions (
  match_id uuid not null references public.matches (id) on delete cascade,
  position int not null check (position >= 0),
  question_id text not null references public.questions (id),
  category text not null,
  difficulty text not null,
  option_order smallint[] not null check (array_length(option_order, 1) = 4),
  correct_display_index smallint not null check (correct_display_index between 0 and 3),
  primary key (match_id, position)
);

-- One row per (match, player, question): the primary key is the duplicate-submission guard.
create table public.player_answers (
  match_id uuid not null,
  player_key text not null,
  question_index int not null,
  selected_index smallint check (selected_index between 0 and 3),
  correct boolean not null,
  timed_out boolean not null,
  elapsed_ms int not null check (elapsed_ms >= 0),
  points int not null check (points >= 0),
  base_points int not null,
  speed_bonus int not null,
  multiplier numeric(4, 2) not null,
  streak_after int not null,
  answered_at timestamptz not null,
  primary key (match_id, player_key, question_index),
  foreign key (match_id, player_key) references public.match_players (match_id, player_key) on delete cascade
);

create table public.player_question_history (
  player_key text not null,
  question_id text not null references public.questions (id) on delete cascade,
  seen_at timestamptz not null default now(),
  times_seen int not null default 1,
  primary key (player_key, question_id)
);
create index player_question_history_recent_idx on public.player_question_history (player_key, seen_at desc);

-- ---------------------------------------------------------------------------
-- Progression
-- ---------------------------------------------------------------------------

create table public.player_stats (
  user_id uuid primary key references auth.users (id) on delete cascade,
  xp bigint not null default 0 check (xp >= 0),
  level int not null default 1,
  total_matches int not null default 0,
  total_wins int not null default 0,
  total_correct int not null default 0,
  total_answered int not null default 0,
  best_score int not null default 0,
  current_win_streak int not null default 0,
  highest_win_streak int not null default 0,
  lifetime_competitive_points bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- Idempotent XP ledger: one grant per (user, source).
create table public.xp_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null,
  source_type text not null,
  source_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, source_type, source_id)
);

create table public.achievements (
  id text primary key,
  icon text not null,
  name_it text not null,
  name_en text not null,
  description_it text not null,
  description_en text not null,
  condition jsonb not null,
  reward_cosmetic_id text,
  reward_xp int not null default 0,
  active boolean not null default true
);

create table public.player_achievements (
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null references public.achievements (id),
  unlocked_at timestamptz not null default now(),
  source_match_id uuid,
  primary key (user_id, achievement_id)
);

create table public.cosmetic_items (
  id text primary key,
  kind text not null check (kind in ('avatar', 'frame', 'title', 'theme', 'celebration', 'badge')),
  name_it text not null,
  name_en text not null,
  rarity text not null default 'common' check (rarity in ('common', 'rare', 'epic', 'legendary')),
  premium_only boolean not null default false,
  active boolean not null default true
);

create table public.player_inventory (
  user_id uuid not null references auth.users (id) on delete cascade,
  item_id text not null references public.cosmetic_items (id),
  acquired_via text not null check (acquired_via in ('achievement', 'level', 'subscription', 'event', 'purchase', 'default')),
  grant_key text not null,
  equipped boolean not null default false,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id),
  unique (user_id, grant_key)
);

-- ---------------------------------------------------------------------------
-- Daily challenge & leaderboards
-- ---------------------------------------------------------------------------

create table public.daily_challenges (
  id text primary key, -- e.g. '2026-10-27:it:v1' (UTC date : locale : ruleset)
  challenge_date date not null,
  locale text not null check (locale in ('it', 'en')),
  ruleset_version text not null,
  question_ids text[] not null,
  created_at timestamptz not null default now(),
  unique (challenge_date, locale, ruleset_version)
);

create table public.daily_challenge_entries (
  challenge_id text not null references public.daily_challenges (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  match_id uuid not null references public.matches (id),
  score int not null default 0,
  correct_count int not null default 0,
  total_elapsed_ms int not null default 0,
  completed_at timestamptz,
  primary key (challenge_id, user_id) -- one ranked attempt per day
);
create index daily_entries_rank_idx on public.daily_challenge_entries (challenge_id, score desc, total_elapsed_ms asc, completed_at asc);

create table public.leaderboard_snapshots (
  id uuid primary key default gen_random_uuid(),
  board text not null check (board in ('daily', 'weekly', 'all_time')),
  period_key text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  rank int not null,
  score bigint not null,
  created_at timestamptz not null default now(),
  unique (board, period_key, user_id)
);
create index leaderboard_snapshots_rank_idx on public.leaderboard_snapshots (board, period_key, rank);

-- ---------------------------------------------------------------------------
-- Social
-- ---------------------------------------------------------------------------

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users (id) on delete cascade,
  to_user uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (from_user <> to_user)
);
create unique index friend_requests_pending_uidx on public.friend_requests (least(from_user, to_user), greatest(from_user, to_user)) where status = 'pending';

-- Stored once per pair with user_a < user_b.
create table public.friendships (
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index friendships_b_idx on public.friendships (user_b);

create table public.blocks (
  blocker uuid not null references auth.users (id) on delete cascade,
  blocked uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table public.challenge_invitations (
  id uuid primary key default gen_random_uuid(),
  -- Random, unguessable code used in share links. Never an auth token.
  code text not null unique default encode(gen_random_bytes(12), 'hex'),
  from_user uuid not null references auth.users (id) on delete cascade,
  to_user uuid references auth.users (id) on delete cascade,
  source_match_id uuid not null references public.matches (id),
  status text not null default 'open' check (status in ('open', 'accepted', 'completed', 'expired', 'declined')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references auth.users (id) on delete cascade,
  target_user uuid references auth.users (id) on delete cascade,
  target_question text references public.questions (id) on delete cascade,
  reason text not null check (reason in ('cheating', 'offensive_name', 'harassment', 'wrong_answer', 'inappropriate_content', 'other')),
  details text check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  check (target_user is not null or target_question is not null)
);

-- ---------------------------------------------------------------------------
-- Billing
-- ---------------------------------------------------------------------------

create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  plan text not null default 'plus_monthly',
  status text not null check (status in ('trialing', 'active', 'past_due', 'canceled', 'incomplete', 'incomplete_expired', 'unpaid', 'paused')),
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Webhook idempotency: each Stripe event id is processed once.
create table public.billing_events (
  stripe_event_id text primary key,
  type text not null,
  payload jsonb not null,
  processed_at timestamptz,
  received_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- AI content pipeline
-- ---------------------------------------------------------------------------

create table public.ai_generation_jobs (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid references auth.users (id),
  category_id text not null references public.question_categories (id),
  locale text not null check (locale in ('it', 'en')),
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard', 'expert')),
  requested_count int not null check (requested_count between 1 and 50),
  status text not null default 'queued' check (status in ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
  attempts int not null default 0 check (attempts <= 3),
  accepted_count int not null default 0,
  rejected_count int not null default 0,
  error text,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.ai_generation_jobs (id) on delete set null,
  model text not null,
  input_tokens int not null,
  output_tokens int not null,
  cost_usd numeric(10, 6) not null,
  created_at timestamptz not null default now()
);
create index ai_usage_created_idx on public.ai_usage (created_at);

-- ---------------------------------------------------------------------------
-- Audit & abuse signals (no secrets, no raw IPs: ip_hash is a salted hash)
-- ---------------------------------------------------------------------------

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_key text,
  action text not null,
  subject text,
  ip_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_events_action_idx on public.audit_events (action, created_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'staff_roles', 'question_categories', 'questions', 'question_versions', 'question_reviews',
    'matches', 'match_players', 'match_questions', 'player_answers', 'player_question_history',
    'player_stats', 'xp_transactions', 'achievements', 'player_achievements', 'cosmetic_items',
    'player_inventory', 'daily_challenges', 'daily_challenge_entries', 'leaderboard_snapshots',
    'friend_requests', 'friendships', 'blocks', 'challenge_invitations', 'user_reports',
    'subscriptions', 'billing_events', 'ai_generation_jobs', 'ai_usage', 'audit_events'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- Public catalogue data.
grant select on public.question_categories, public.achievements, public.cosmetic_items to anon, authenticated;
create policy "catalogue readable" on public.question_categories for select using (active);
create policy "achievements readable" on public.achievements for select using (active);
create policy "cosmetics readable" on public.cosmetic_items for select using (active);

-- Profiles: owners read/update their own row; public fields are exposed via the view below.
grant select, update (display_name, avatar_id, locale, leaderboard_visibility, profile_visibility) on public.profiles to authenticated;
create policy "own profile read" on public.profiles for select to authenticated using (id = auth.uid());
create policy "own profile update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Own progression data (read-only for clients; the server writes it).
grant select on public.player_stats, public.player_achievements, public.player_inventory, public.xp_transactions, public.subscriptions to authenticated;
create policy "own stats" on public.player_stats for select to authenticated using (user_id = auth.uid());
create policy "own achievements" on public.player_achievements for select to authenticated using (user_id = auth.uid());
create policy "own inventory" on public.player_inventory for select to authenticated using (user_id = auth.uid());
create policy "own xp" on public.xp_transactions for select to authenticated using (user_id = auth.uid());
create policy "own subscription" on public.subscriptions for select to authenticated using (user_id = auth.uid());

-- Social: users see requests/friendships/blocks they are part of.
grant select on public.friend_requests, public.friendships, public.blocks, public.challenge_invitations to authenticated;
create policy "own friend requests" on public.friend_requests for select to authenticated using (auth.uid() in (from_user, to_user));
create policy "own friendships" on public.friendships for select to authenticated using (auth.uid() in (user_a, user_b));
create policy "own blocks" on public.blocks for select to authenticated using (blocker = auth.uid());
create policy "own invitations" on public.challenge_invitations for select to authenticated using (auth.uid() in (from_user, to_user));

-- Reports: users may file reports as themselves.
grant insert (target_user, target_question, reason, details) on public.user_reports to authenticated;
create policy "file report" on public.user_reports for insert to authenticated with check (reporter = auth.uid());

-- Staff read access to moderation and content tables.
grant select on public.questions, public.question_reviews, public.user_reports, public.ai_generation_jobs, public.ai_usage, public.audit_events to authenticated;
create policy "staff read questions" on public.questions for select to authenticated using (public.is_staff('moderator'));
create policy "staff read reviews" on public.question_reviews for select to authenticated using (public.is_staff('moderator'));
create policy "staff read reports" on public.user_reports for select to authenticated using (public.is_staff('moderator'));
create policy "staff read ai jobs" on public.ai_generation_jobs for select to authenticated using (public.is_staff('admin'));
create policy "staff read ai usage" on public.ai_usage for select to authenticated using (public.is_staff('admin'));
create policy "staff read audit" on public.audit_events for select to authenticated using (public.is_staff('admin'));

-- Public profile view: no email, no private settings. Hidden when the profile is private or deleted.
create view public.public_profiles with (security_barrier = true) as
  select p.id, p.username, p.display_name, p.avatar_id, s.level, p.created_at
  from public.profiles p
  left join public.player_stats s on s.user_id = p.id
  where p.deleted_at is null and p.profile_visibility = 'public';
grant select on public.public_profiles to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------------------

insert into public.question_categories (id, sort_order, name_it, name_en, icon) values
  ('general', 1, 'Cultura generale', 'General Knowledge', 'lightbulb'),
  ('history', 2, 'Storia', 'History', 'landmark'),
  ('geography', 3, 'Geografia', 'Geography', 'globe'),
  ('science', 4, 'Scienza', 'Science', 'flask-conical'),
  ('technology', 5, 'Tecnologia', 'Technology', 'cpu'),
  ('movies_tv', 6, 'Cinema e TV', 'Movies and TV', 'clapperboard'),
  ('music', 7, 'Musica', 'Music', 'music'),
  ('sports', 8, 'Sport', 'Sports', 'trophy'),
  ('nature', 9, 'Natura', 'Nature', 'leaf'),
  ('food', 10, 'Cucina', 'Food', 'utensils'),
  ('art', 11, 'Arte', 'Art', 'palette'),
  ('logic', 12, 'Logica e indovinelli', 'Logic and Riddles', 'puzzle'),
  ('video_games', 13, 'Videogiochi', 'Video Games', 'gamepad-2'),
  ('pop_culture', 14, 'Cultura pop', 'Pop Culture', 'sparkles');

insert into public.achievements (id, icon, name_it, name_en, description_it, description_en, condition, reward_xp) values
  ('first_victory', 'trophy', 'Prima vittoria', 'First Victory', 'Vinci la tua prima sfida.', 'Win your first battle.', '{"type":"wins","gte":1}', 25),
  ('perfect_match', 'star', 'Partita perfetta', 'Perfect Match', 'Rispondi correttamente a tutte le 10 domande.', 'Answer all 10 questions correctly.', '{"type":"perfect_match"}', 50),
  ('matches_10', 'gamepad-2', '10 partite', '10 Matches Played', 'Completa 10 partite.', 'Complete 10 matches.', '{"type":"matches","gte":10}', 25),
  ('correct_100', 'check-circle', '100 risposte esatte', '100 Correct Answers', 'Dai 100 risposte corrette.', 'Give 100 correct answers.', '{"type":"correct","gte":100}', 50),
  ('speed_demon', 'zap', 'Fulmine', 'Speed Demon', 'Rispondi correttamente in meno di 2 secondi per 5 volte in una partita.', 'Answer correctly in under 2 seconds 5 times in one match.', '{"type":"fast_answers","under_ms":2000,"gte":5}', 50),
  ('geography_expert', 'globe', 'Esperto di geografia', 'Geography Expert', 'Dai 50 risposte corrette in Geografia.', 'Give 50 correct Geography answers.', '{"type":"category_correct","category":"geography","gte":50}', 50),
  ('science_master', 'flask-conical', 'Maestro della scienza', 'Science Master', 'Dai 50 risposte corrette in Scienza.', 'Give 50 correct Science answers.', '{"type":"category_correct","category":"science","gte":50}', 50),
  ('win_streak_5', 'flame', 'Cinque di fila', 'Five Consecutive Wins', 'Vinci 5 sfide consecutive.', 'Win 5 battles in a row.', '{"type":"win_streak","gte":5}', 75),
  ('daily_challenger', 'calendar-check', 'Sfidante del giorno', 'Daily Challenger', 'Completa una Sfida del giorno.', 'Complete a Daily Challenge.', '{"type":"daily_challenges","gte":1}', 25),
  ('quiz_veteran', 'medal', 'Veterano del quiz', 'Quiz Veteran', 'Completa 100 partite.', 'Complete 100 matches.', '{"type":"matches","gte":100}', 100);
