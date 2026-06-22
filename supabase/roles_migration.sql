-- ============================================================================
-- Roles, Artist Applications, Songs (extended), Reports — Migration
-- ----------------------------------------------------------------------------
-- Apply in Supabase Dashboard → SQL Editor.
-- Idempotent: safe to re-run.
--
-- Roles model:
--   user       — default. Listens, builds playlists, can apply to be an artist.
--   artist     — uploads own songs (premoderated by moderator).
--   moderator  — reviews artist applications, premoderates songs, handles reports.
--   admin      — manages moderators, demotes artists, marks featured songs,
--                full system access.
--
-- Lifecycle:
--   user → submits artist_applications (pending)
--        → moderator approves    → role becomes 'artist'
--        → moderator rejects     → user sees reason, may re-apply
--   artist uploads song (status='pending')
--        → moderator approves   (status='approved', visible everywhere)
--        → moderator rejects    (status='rejected' with reason)
--   admin uploads song          → status='approved' immediately
--   admin can flip is_featured on any approved song.
--
-- After applying, set yourself as admin:
--   UPDATE public.profiles SET role = 'admin' WHERE email = 'YOUR_EMAIL';
-- ============================================================================


-- 1) PROFILES.ROLE -----------------------------------------------------------
-- Already added as TEXT in admin_migration.sql. Tighten with CHECK constraint.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';

-- Drop any prior role check (idempotent rename).
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('user', 'artist', 'moderator', 'admin'));

CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles (role);


-- 2) ROLE HELPER FUNCTIONS ---------------------------------------------------
-- SECURITY DEFINER lets these be called inside RLS policies on profiles
-- without recursive RLS evaluation.
CREATE OR REPLACE FUNCTION public.current_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_moderator()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('moderator', 'admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_artist()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('artist', 'admin')
  );
$$;


-- 3) PROFILES RLS — let moderators/admins read all profiles ------------------
DROP POLICY IF EXISTS "Admin read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "profiles staff read all" ON public.profiles;
CREATE POLICY "profiles staff read all"
  ON public.profiles FOR SELECT
  USING (
    auth.uid() = id
    OR public.is_moderator()
  );

-- Only admin can change role (users cannot self-promote).
DROP POLICY IF EXISTS "profile self update" ON public.profiles;
CREATE POLICY "profile self update no role"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "profile admin update role" ON public.profiles;
CREATE POLICY "profile admin update role"
  ON public.profiles FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- 4) ARTIST APPLICATIONS -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.artist_applications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  artist_name     TEXT NOT NULL,
  bio             TEXT,
  links           TEXT,                          -- comma/newline separated URLs
  reason          TEXT NOT NULL,                 -- why they want to be an artist
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewer_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewer_note   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS artist_applications_user_idx
  ON public.artist_applications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS artist_applications_status_idx
  ON public.artist_applications (status, created_at DESC);

-- Only one open (pending) application per user.
CREATE UNIQUE INDEX IF NOT EXISTS artist_applications_one_pending
  ON public.artist_applications (user_id)
  WHERE status = 'pending';

ALTER TABLE public.artist_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "applications self select" ON public.artist_applications;
CREATE POLICY "applications self select"
  ON public.artist_applications FOR SELECT
  USING (auth.uid() = user_id OR public.is_moderator());

DROP POLICY IF EXISTS "applications self insert" ON public.artist_applications;
CREATE POLICY "applications self insert"
  ON public.artist_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users may withdraw their own pending application; staff can update verdicts.
DROP POLICY IF EXISTS "applications self delete pending" ON public.artist_applications;
CREATE POLICY "applications self delete pending"
  ON public.artist_applications FOR DELETE
  USING (auth.uid() = user_id AND status = 'pending');

DROP POLICY IF EXISTS "applications staff update" ON public.artist_applications;
CREATE POLICY "applications staff update"
  ON public.artist_applications FOR UPDATE
  USING (public.is_moderator())
  WITH CHECK (public.is_moderator());


-- 5) SONGS -------------------------------------------------------------------
-- Existing `songs` table from songs_admin_migration.sql is extended here.
-- Schema (target):
--   id, title, artist, audio_url, cover_url, album, genre, duration_seconds,
--   owner_id (uploader), status (pending|approved|rejected), is_featured,
--   review_note, reviewer_id, created_at, approved_at.

-- Create the table if it does not exist yet (fresh installs).
CREATE TABLE IF NOT EXISTS public.songs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  artist       TEXT NOT NULL,
  audio_url    TEXT NOT NULL,
  cover_url    TEXT,
  uploaded_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.songs
  ADD COLUMN IF NOT EXISTS album            TEXT,
  ADD COLUMN IF NOT EXISTS genre            TEXT,
  ADD COLUMN IF NOT EXISTS duration_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS owner_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status           TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS is_featured      BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS review_note      TEXT,
  ADD COLUMN IF NOT EXISTS reviewer_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at      TIMESTAMPTZ;

-- Backfill owner_id from legacy uploaded_by where missing.
UPDATE public.songs
   SET owner_id = uploaded_by
 WHERE owner_id IS NULL AND uploaded_by IS NOT NULL;

ALTER TABLE public.songs DROP CONSTRAINT IF EXISTS songs_status_check;
ALTER TABLE public.songs
  ADD CONSTRAINT songs_status_check
  CHECK (status IN ('pending', 'approved', 'rejected'));

CREATE INDEX IF NOT EXISTS songs_status_idx        ON public.songs (status, created_at DESC);
CREATE INDEX IF NOT EXISTS songs_owner_idx         ON public.songs (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS songs_is_featured_idx   ON public.songs (is_featured) WHERE is_featured;
CREATE INDEX IF NOT EXISTS songs_genre_idx         ON public.songs (genre);

ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;

-- SELECT: approved songs are visible to everyone authenticated.
--         Owners see their own (any status). Moderators see all.
DROP POLICY IF EXISTS "songs readable by authenticated" ON public.songs;
DROP POLICY IF EXISTS "songs readable" ON public.songs;
CREATE POLICY "songs readable"
  ON public.songs FOR SELECT
  USING (
    status = 'approved'
    OR auth.uid() = owner_id
    OR public.is_moderator()
  );

-- INSERT:
--   admin → may insert anything (we'll force status='approved' from client).
--   artist → may insert only with owner_id=self and status='pending'.
DROP POLICY IF EXISTS "songs admin insert" ON public.songs;
DROP POLICY IF EXISTS "songs admin write" ON public.songs;
CREATE POLICY "songs admin insert"
  ON public.songs FOR INSERT
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "songs artist insert" ON public.songs;
CREATE POLICY "songs artist insert"
  ON public.songs FOR INSERT
  WITH CHECK (
    public.is_artist()
    AND owner_id = auth.uid()
    AND status = 'pending'
    AND is_featured = FALSE
  );

-- UPDATE:
--   admin → anything.
--   moderator → may approve/reject, set review_note/reviewer_id/approved_at,
--               may NOT toggle is_featured (admin-only).
--   artist (owner) → may edit metadata of own pending/rejected songs only.
DROP POLICY IF EXISTS "songs admin update" ON public.songs;
CREATE POLICY "songs admin update"
  ON public.songs FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "songs moderator update" ON public.songs;
CREATE POLICY "songs moderator update"
  ON public.songs FOR UPDATE
  USING (public.current_role() = 'moderator')
  WITH CHECK (public.current_role() = 'moderator' AND is_featured = FALSE);

DROP POLICY IF EXISTS "songs owner update" ON public.songs;
CREATE POLICY "songs owner update"
  ON public.songs FOR UPDATE
  USING (
    auth.uid() = owner_id
    AND public.is_artist()
    AND status IN ('pending', 'rejected')
  )
  WITH CHECK (
    auth.uid() = owner_id
    AND status = 'pending'
    AND is_featured = FALSE
  );

-- DELETE:
--   admin → any. moderator → any. owner → only own non-approved (drafts).
DROP POLICY IF EXISTS "songs admin delete" ON public.songs;
CREATE POLICY "songs admin delete"
  ON public.songs FOR DELETE
  USING (public.is_moderator());

DROP POLICY IF EXISTS "songs owner delete" ON public.songs;
CREATE POLICY "songs owner delete"
  ON public.songs FOR DELETE
  USING (
    auth.uid() = owner_id
    AND status IN ('pending', 'rejected')
  );


-- 6) MIGRATE FEATURED_SONGS → SONGS (one-time, idempotent) -------------------
-- The legacy featured_songs table (if present) is folded into `songs` with
-- is_featured=TRUE so a single catalog backs the whole app.
DO $$
DECLARE
  any_admin UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'featured_songs'
  ) THEN
    RETURN;
  END IF;

  SELECT id INTO any_admin FROM public.profiles WHERE role = 'admin' LIMIT 1;

  EXECUTE $mig$
    INSERT INTO public.songs (
      title, artist, audio_url, cover_url, owner_id,
      status, is_featured, created_at
    )
    SELECT
      fs.title,
      fs.artist,
      -- featured bucket is public; build a stable public URL
      'https://' ||
        regexp_replace(current_setting('request.headers', true)::json ->> 'host',
                       '^api\.', '') ||
        '/storage/v1/object/public/featured/' || fs.storage_path,
      fs.album_art_url,
      $1,
      'approved',
      TRUE,
      COALESCE(fs.created_at, now())
    FROM public.featured_songs fs
    WHERE NOT EXISTS (
      SELECT 1 FROM public.songs s
      WHERE s.audio_url ILIKE '%' || fs.storage_path
    );
  $mig$ USING any_admin;
EXCEPTION WHEN OTHERS THEN
  -- request.headers may be unavailable in SQL editor; fall back to flag-only flip.
  UPDATE public.songs s
     SET is_featured = TRUE
   WHERE s.is_featured = FALSE
     AND EXISTS (
       SELECT 1 FROM public.featured_songs fs
       WHERE s.audio_url ILIKE '%' || fs.storage_path
     );
END $$;

-- Also flip is_featured on any songs that already share storage_path with featured_songs.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'featured_songs'
  ) THEN
    UPDATE public.songs s
       SET is_featured = TRUE
     WHERE s.is_featured = FALSE
       AND EXISTS (
         SELECT 1 FROM public.featured_songs fs
         WHERE s.audio_url ILIKE '%' || fs.storage_path
       );
  END IF;
END $$;


-- 7) REPORTS -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type     TEXT NOT NULL CHECK (target_type IN ('song', 'playlist', 'profile', 'comment')),
  target_id       TEXT NOT NULL,                -- UUID or composite id as text
  reason          TEXT NOT NULL,
  details         TEXT,
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'resolved', 'dismissed')),
  reviewer_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewer_note   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS reports_status_idx
  ON public.reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS reports_reporter_idx
  ON public.reports (reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS reports_target_idx
  ON public.reports (target_type, target_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reports self select" ON public.reports;
CREATE POLICY "reports self select"
  ON public.reports FOR SELECT
  USING (auth.uid() = reporter_id OR public.is_moderator());

DROP POLICY IF EXISTS "reports self insert" ON public.reports;
CREATE POLICY "reports self insert"
  ON public.reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "reports staff update" ON public.reports;
CREATE POLICY "reports staff update"
  ON public.reports FOR UPDATE
  USING (public.is_moderator())
  WITH CHECK (public.is_moderator());

DROP POLICY IF EXISTS "reports staff delete" ON public.reports;
CREATE POLICY "reports staff delete"
  ON public.reports FOR DELETE
  USING (public.is_moderator());


-- 8) STORAGE: artists may upload to songs/ under a per-user prefix -----------
-- Folder convention: songs/<user_id>/<file>.mp3
DROP POLICY IF EXISTS "Artist insert songs" ON storage.objects;
CREATE POLICY "Artist insert songs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'songs'
    AND public.is_artist()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Artist update own songs" ON storage.objects;
CREATE POLICY "Artist update own songs"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'songs'
    AND public.is_artist()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Artist delete own songs" ON storage.objects;
CREATE POLICY "Artist delete own songs"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'songs'
    AND public.is_artist()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Artist insert covers" ON storage.objects;
CREATE POLICY "Artist insert covers"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'covers'
    AND public.is_artist()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Artist update own covers" ON storage.objects;
CREATE POLICY "Artist update own covers"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'covers'
    AND public.is_artist()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Artist delete own covers" ON storage.objects;
CREATE POLICY "Artist delete own covers"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'covers'
    AND public.is_artist()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Moderators may also remove storage objects in songs/covers (clean up rejected).
DROP POLICY IF EXISTS "Moderator delete songs storage" ON storage.objects;
CREATE POLICY "Moderator delete songs storage"
  ON storage.objects FOR DELETE
  USING (
    bucket_id IN ('songs', 'covers')
    AND public.is_moderator()
  );


-- 9) RPC: APPROVE / REJECT APPLICATION (atomic role grant) -------------------
-- Moderator-callable. Approves application AND grants 'artist' role in one tx.
CREATE OR REPLACE FUNCTION public.approve_artist_application(
  application_id UUID,
  note           TEXT DEFAULT NULL
)
RETURNS public.artist_applications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  app public.artist_applications;
BEGIN
  IF NOT public.is_moderator() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.artist_applications
     SET status = 'approved',
         reviewer_id = auth.uid(),
         reviewer_note = note,
         reviewed_at = now()
   WHERE id = application_id AND status = 'pending'
  RETURNING * INTO app;

  IF app.id IS NULL THEN
    RAISE EXCEPTION 'application not found or already reviewed';
  END IF;

  -- Promote user (do not demote admin/moderator if any).
  UPDATE public.profiles
     SET role = 'artist',
         updated_at = now()
   WHERE id = app.user_id
     AND role = 'user';

  RETURN app;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_artist_application(
  application_id UUID,
  note           TEXT
)
RETURNS public.artist_applications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  app public.artist_applications;
BEGIN
  IF NOT public.is_moderator() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '42501';
  END IF;
  IF note IS NULL OR length(trim(note)) = 0 THEN
    RAISE EXCEPTION 'rejection note required';
  END IF;

  UPDATE public.artist_applications
     SET status = 'rejected',
         reviewer_id = auth.uid(),
         reviewer_note = note,
         reviewed_at = now()
   WHERE id = application_id AND status = 'pending'
  RETURNING * INTO app;

  IF app.id IS NULL THEN
    RAISE EXCEPTION 'application not found or already reviewed';
  END IF;

  RETURN app;
END;
$$;

-- Moderator approve/reject SONG.
CREATE OR REPLACE FUNCTION public.approve_song(song_id UUID)
RETURNS public.songs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s public.songs;
BEGIN
  IF NOT public.is_moderator() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.songs
     SET status = 'approved',
         reviewer_id = auth.uid(),
         approved_at = now()
   WHERE id = song_id AND status = 'pending'
  RETURNING * INTO s;

  IF s.id IS NULL THEN
    RAISE EXCEPTION 'song not found or not pending';
  END IF;

  RETURN s;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_song(song_id UUID, note TEXT)
RETURNS public.songs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s public.songs;
BEGIN
  IF NOT public.is_moderator() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '42501';
  END IF;
  IF note IS NULL OR length(trim(note)) = 0 THEN
    RAISE EXCEPTION 'rejection note required';
  END IF;

  UPDATE public.songs
     SET status = 'rejected',
         reviewer_id = auth.uid(),
         review_note = note
   WHERE id = song_id AND status = 'pending'
  RETURNING * INTO s;

  IF s.id IS NULL THEN
    RAISE EXCEPTION 'song not found or not pending';
  END IF;

  RETURN s;
END;
$$;

-- Admin role management.
CREATE OR REPLACE FUNCTION public.set_user_role(target_user UUID, new_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '42501';
  END IF;
  IF new_role NOT IN ('user', 'artist', 'moderator', 'admin') THEN
    RAISE EXCEPTION 'invalid role: %', new_role;
  END IF;

  UPDATE public.profiles
     SET role = new_role, updated_at = now()
   WHERE id = target_user;
END;
$$;
