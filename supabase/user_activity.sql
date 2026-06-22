-- user_activity.sql

create table if not exists public.user_activity (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  song_title      text,
  song_artist     text,
  song_album_art  text,
  song_url        text,
  is_playing      boolean default false,
  updated_at      timestamptz not null default now()
);

alter table public.user_activity enable row level security;

-- Любой авторизованный пользователь может читать статусы
drop policy if exists "user_activity readable by authenticated" on public.user_activity;
create policy "user_activity readable by authenticated"
  on public.user_activity for select using (auth.role() = 'authenticated');

-- Пользователь может обновлять только свой собственный статус
drop policy if exists "user_activity insert self" on public.user_activity;
create policy "user_activity insert self"
  on public.user_activity for insert with check (auth.uid() = user_id);

drop policy if exists "user_activity update self" on public.user_activity;
create policy "user_activity update self"
  on public.user_activity for update using (auth.uid() = user_id);
