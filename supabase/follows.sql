-- Social graph migration for the music app.
--
-- Apply this in the Supabase SQL Editor (Dashboard → SQL).
-- Idempotent: safe to run multiple times.

-- 1) Make sure profiles can be looked up by any authenticated user, otherwise
--    follower / following lists return empty rows.
alter table public.profiles enable row level security;

drop policy if exists "profiles readable by authenticated" on public.profiles;
create policy "profiles readable by authenticated"
  on public.profiles for select
  using (auth.role() = 'authenticated');

drop policy if exists "profile self upsert" on public.profiles;
create policy "profile self upsert"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profile self update" on public.profiles;
create policy "profile self update"
  on public.profiles for update
  using (auth.uid() = id);

-- 2) Follows table — one row per (follower, followee).
create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followee_id uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  constraint follows_no_self check (follower_id <> followee_id)
);

create index if not exists follows_followee_idx
  on public.follows (followee_id);
create index if not exists follows_follower_idx
  on public.follows (follower_id);

-- 3) RLS policies for follows.
alter table public.follows enable row level security;

drop policy if exists "follows readable by authenticated" on public.follows;
create policy "follows readable by authenticated"
  on public.follows for select
  using (auth.role() = 'authenticated');

drop policy if exists "follows insert self only" on public.follows;
create policy "follows insert self only"
  on public.follows for insert
  with check (auth.uid() = follower_id);

drop policy if exists "follows delete self only" on public.follows;
create policy "follows delete self only"
  on public.follows for delete
  using (auth.uid() = follower_id);
