-- ============================================================
-- Complete Roles Setup for Music App
-- This script creates all missing tables and functions
-- ============================================================

-- 1. Add role column to profiles if not exists
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- 2. Create helper functions for role checking
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

-- 3. Create set_user_role RPC function (admin only)
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

-- 4. Create artist_applications table
CREATE TABLE IF NOT EXISTS public.artist_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT,
  email TEXT,
  bio TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS artist_applications_user_idx ON public.artist_applications(user_id);
CREATE INDEX IF NOT EXISTS artist_applications_status_idx ON public.artist_applications(status);

ALTER TABLE public.artist_applications ENABLE ROW LEVEL SECURITY;

-- RLS for artist_applications
DROP POLICY IF EXISTS "applications self select" ON public.artist_applications;
CREATE POLICY "applications self select"
  ON public.artist_applications FOR SELECT
  USING (auth.uid() = user_id OR public.is_moderator());

DROP POLICY IF EXISTS "applications self insert" ON public.artist_applications;
CREATE POLICY "applications self insert"
  ON public.artist_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "applications self delete pending" ON public.artist_applications;
CREATE POLICY "applications self delete pending"
  ON public.artist_applications FOR DELETE
  USING (auth.uid() = user_id AND status = 'pending');

DROP POLICY IF EXISTS "applications staff update" ON public.artist_applications;
CREATE POLICY "applications staff update"
  ON public.artist_applications FOR UPDATE
  USING (public.is_moderator())
  WITH CHECK (public.is_moderator());

-- 5. Create songs table
CREATE TABLE IF NOT EXISTS public.songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT,
  duration_seconds INTEGER,
  cover_url TEXT,
  audio_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  is_featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS songs_owner_idx ON public.songs(owner_id);
CREATE INDEX IF NOT EXISTS songs_status_idx ON public.songs(status);
CREATE INDEX IF NOT EXISTS songs_created_idx ON public.songs(created_at DESC);

ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;

-- RLS for songs
DROP POLICY IF EXISTS "songs readable" ON public.songs;
CREATE POLICY "songs readable"
  ON public.songs FOR SELECT
  USING (
    status = 'approved'
    OR auth.uid() = owner_id
    OR public.is_moderator()
  );

DROP POLICY IF EXISTS "songs admin insert" ON public.songs;
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

-- 6. Update profiles RLS policies for role management
DROP POLICY IF EXISTS "profiles staff read all" ON public.profiles;
CREATE POLICY "profiles staff read all"
  ON public.profiles FOR SELECT
  USING (
    auth.uid() = id
    OR public.is_moderator()
  );

DROP POLICY IF EXISTS "profile admin update role" ON public.profiles;
CREATE POLICY "profile admin update role"
  ON public.profiles FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 7. Auto-update updated_at for profiles
CREATE OR REPLACE FUNCTION public.set_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_updated_at ON public.profiles;
CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_profiles_updated_at();

-- Grant execute on functions to authenticated users
GRANT EXECUTE ON FUNCTION public.set_user_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_moderator() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_artist() TO authenticated;
