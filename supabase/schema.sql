-- ============================================================================
-- Music App — complete Supabase schema.
-- ----------------------------------------------------------------------------
-- Apply in Supabase Dashboard → SQL Editor. The script is IDEMPOTENT — it can
-- be re-run safely any time to bring the DB in sync with the Flutter client.
-- ============================================================================

-- 1) PROFILES ----------------------------------------------------------------
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  username       text unique,
  email          text,
  profile_image  text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles readable by authenticated" on public.profiles;
create policy "profiles readable by authenticated"
  on public.profiles for select using (auth.role() = 'authenticated');

drop policy if exists "profile self insert" on public.profiles;
create policy "profile self insert"
  on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "profile self update" on public.profiles;
create policy "profile self update"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create a profile row on user signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, username)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      split_part(coalesce(new.email, 'user'), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- 2) USER_FAVORITES ----------------------------------------------------------
create table if not exists public.user_favorites (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  username        text,
  song_title      text not null,
  song_artist     text not null,
  song_album      text,
  song_audio_url  text,
  added_at        timestamptz not null default now(),
  unique (user_id, song_title, song_artist)
);

create index if not exists user_favorites_user_idx
  on public.user_favorites (user_id, added_at desc);

alter table public.user_favorites enable row level security;

drop policy if exists "favorites self select" on public.user_favorites;
create policy "favorites self select"
  on public.user_favorites for select using (auth.uid() = user_id);

drop policy if exists "favorites self insert" on public.user_favorites;
create policy "favorites self insert"
  on public.user_favorites for insert with check (auth.uid() = user_id);

drop policy if exists "favorites self delete" on public.user_favorites;
create policy "favorites self delete"
  on public.user_favorites for delete using (auth.uid() = user_id);


-- 3) PLAYLISTS ---------------------------------------------------------------
create table if not exists public.playlists (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  username     text,
  name         text not null,
  description  text,
  cover_url    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists playlists_user_idx
  on public.playlists (user_id, created_at desc);
create index if not exists playlists_name_idx
  on public.playlists using gin (to_tsvector('simple', name));

-- Auto-bump updated_at on update.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists playlists_set_updated_at on public.playlists;
create trigger playlists_set_updated_at
  before update on public.playlists
  for each row execute function public.set_updated_at();

alter table public.playlists enable row level security;

-- Public discovery: every authenticated user can browse all playlists.
drop policy if exists "playlists readable by authenticated" on public.playlists;
create policy "playlists readable by authenticated"
  on public.playlists for select using (auth.role() = 'authenticated');

drop policy if exists "playlists self insert" on public.playlists;
create policy "playlists self insert"
  on public.playlists for insert with check (auth.uid() = user_id);

drop policy if exists "playlists self update" on public.playlists;
create policy "playlists self update"
  on public.playlists for update using (auth.uid() = user_id);

drop policy if exists "playlists self delete" on public.playlists;
create policy "playlists self delete"
  on public.playlists for delete using (auth.uid() = user_id);


-- 4) PLAYLIST_SONGS ----------------------------------------------------------
create table if not exists public.playlist_songs (
  id              uuid primary key default gen_random_uuid(),
  playlist_id     uuid not null references public.playlists(id) on delete cascade,
  username        text,
  song_title      text not null,
  song_artist     text not null,
  song_album      text,
  song_audio_url  text,
  position        integer not null default 0,
  added_at        timestamptz not null default now()
);

create index if not exists playlist_songs_playlist_idx
  on public.playlist_songs (playlist_id, position);

alter table public.playlist_songs enable row level security;

-- Readable to any authenticated user (for public playlists to play through).
drop policy if exists "playlist_songs readable by authenticated"
  on public.playlist_songs;
create policy "playlist_songs readable by authenticated"
  on public.playlist_songs for select using (auth.role() = 'authenticated');

-- Only the owner of the parent playlist may mutate its songs.
drop policy if exists "playlist_songs owner insert" on public.playlist_songs;
create policy "playlist_songs owner insert"
  on public.playlist_songs for insert
  with check (
    exists (
      select 1 from public.playlists p
      where p.id = playlist_id and p.user_id = auth.uid()
    )
  );

drop policy if exists "playlist_songs owner delete" on public.playlist_songs;
create policy "playlist_songs owner delete"
  on public.playlist_songs for delete
  using (
    exists (
      select 1 from public.playlists p
      where p.id = playlist_id and p.user_id = auth.uid()
    )
  );

drop policy if exists "playlist_songs owner update" on public.playlist_songs;
create policy "playlist_songs owner update"
  on public.playlist_songs for update
  using (
    exists (
      select 1 from public.playlists p
      where p.id = playlist_id and p.user_id = auth.uid()
    )
  );


-- 5) FOLLOWS (social graph) --------------------------------------------------
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

alter table public.follows enable row level security;

drop policy if exists "follows readable by authenticated" on public.follows;
create policy "follows readable by authenticated"
  on public.follows for select using (auth.role() = 'authenticated');

drop policy if exists "follows insert self only" on public.follows;
create policy "follows insert self only"
  on public.follows for insert with check (auth.uid() = follower_id);

drop policy if exists "follows delete self only" on public.follows;
create policy "follows delete self only"
  on public.follows for delete using (auth.uid() = follower_id);


-- 6) BACK-FILL profiles for pre-existing auth users (one-time, idempotent) ---
insert into public.profiles (id, email, username)
select
  u.id,
  u.email,
  coalesce(
    u.raw_user_meta_data ->> 'username',
    split_part(coalesce(u.email, 'user'), '@', 1)
  )
from auth.users u
on conflict (id) do nothing;
