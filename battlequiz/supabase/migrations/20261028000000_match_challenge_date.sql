-- Daily Challenge matches record the UTC day they belong to.
alter table public.matches add column challenge_date date;
alter table public.matches add constraint matches_daily_has_date
  check ((mode = 'daily_challenge') = (challenge_date is not null));
create index matches_daily_idx on public.matches (challenge_date, locale) where mode = 'daily_challenge';
