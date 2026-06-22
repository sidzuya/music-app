-- ============================================================
-- Artist Analytics System
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Track listens table (for analytics)
CREATE TABLE IF NOT EXISTS public.track_listens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id UUID NOT NULL REFERENCES public.songs(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  artist_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  duration_seconds INTEGER, -- how long did they listen (0-100% estimate)
  country TEXT,
  device_type TEXT -- 'mobile', 'web', 'desktop'
);

CREATE INDEX IF NOT EXISTS track_listens_artist_idx ON public.track_listens(artist_id);
CREATE INDEX IF NOT EXISTS track_listens_track_idx ON public.track_listens(track_id);
CREATE INDEX IF NOT EXISTS track_listens_listened_at_idx ON public.track_listens(listened_at DESC);
CREATE INDEX IF NOT EXISTS track_listens_user_idx ON public.track_listens(user_id);

ALTER TABLE public.track_listens ENABLE ROW LEVEL SECURITY;

-- RLS: Artists can only read their own track listens, admins can read all
DROP POLICY IF EXISTS "track_listens self read" ON public.track_listens;
CREATE POLICY "track_listens self read"
  ON public.track_listens FOR SELECT
  USING (
    artist_id = auth.uid()
    OR public.is_admin()
  );

-- RLS: Anyone can insert (when they listen to a track)
DROP POLICY IF EXISTS "track_listens insert" ON public.track_listens;
CREATE POLICY "track_listens insert"
  ON public.track_listens FOR INSERT
  WITH CHECK (TRUE);

-- 2. Daily track stats (aggregated, for faster queries)
CREATE TABLE IF NOT EXISTS public.daily_track_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id UUID NOT NULL REFERENCES public.songs(id) ON DELETE CASCADE,
  artist_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  listens_count INTEGER DEFAULT 0,
  unique_listeners INTEGER DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(track_id, date)
);

CREATE INDEX IF NOT EXISTS daily_track_stats_artist_idx ON public.daily_track_stats(artist_id, date DESC);
CREATE INDEX IF NOT EXISTS daily_track_stats_track_idx ON public.daily_track_stats(track_id, date DESC);

ALTER TABLE public.daily_track_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "daily_track_stats read" ON public.daily_track_stats;
CREATE POLICY "daily_track_stats read"
  ON public.daily_track_stats FOR SELECT
  USING (
    artist_id = auth.uid()
    OR public.is_admin()
  );

-- 3. Artist stats summary
CREATE TABLE IF NOT EXISTS public.artist_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  total_listens INTEGER DEFAULT 0,
  total_unique_listeners INTEGER DEFAULT 0,
  average_track_listens INTEGER DEFAULT 0,
  top_track_id UUID REFERENCES public.songs(id) ON DELETE SET NULL,
  top_track_listens INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS artist_stats_artist_idx ON public.artist_stats(artist_id);

ALTER TABLE public.artist_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "artist_stats read" ON public.artist_stats;
CREATE POLICY "artist_stats read"
  ON public.artist_stats FOR SELECT
  USING (
    artist_id = auth.uid()
    OR public.is_admin()
  );

-- 4. Country stats (for geography)
CREATE TABLE IF NOT EXISTS public.track_country_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id UUID NOT NULL REFERENCES public.songs(id) ON DELETE CASCADE,
  artist_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  country TEXT NOT NULL,
  listens_count INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(track_id, country)
);

CREATE INDEX IF NOT EXISTS track_country_stats_artist_idx ON public.track_country_stats(artist_id);
CREATE INDEX IF NOT EXISTS track_country_stats_track_idx ON public.track_country_stats(track_id);

ALTER TABLE public.track_country_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "track_country_stats read" ON public.track_country_stats;
CREATE POLICY "track_country_stats read"
  ON public.track_country_stats FOR SELECT
  USING (
    artist_id = auth.uid()
    OR public.is_admin()
  );

-- 5. Function to record a track listen
CREATE OR REPLACE FUNCTION public.record_track_listen(
  p_track_id UUID,
  p_user_id UUID,
  p_duration_seconds INTEGER DEFAULT NULL,
  p_device_type TEXT DEFAULT NULL,
  p_country TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_artist_id UUID;
BEGIN
  -- Get artist_id from song
  SELECT owner_id INTO v_artist_id
  FROM public.songs
  WHERE id = p_track_id
  LIMIT 1;

  IF v_artist_id IS NULL THEN
    RAISE EXCEPTION 'Track not found';
  END IF;

  -- Insert listen record
  INSERT INTO public.track_listens (
    track_id, user_id, artist_id, duration_seconds, device_type, country
  ) VALUES (
    p_track_id, p_user_id, v_artist_id, p_duration_seconds, p_device_type, p_country
  );

  -- Update country stats
  IF p_country IS NOT NULL THEN
    INSERT INTO public.track_country_stats (track_id, artist_id, country, listens_count)
    VALUES (p_track_id, v_artist_id, p_country, 1)
    ON CONFLICT (track_id, country) DO UPDATE SET
      listens_count = listens_count + 1,
      updated_at = now();
  END IF;
END;
$$;

-- 6. Function to get daily stats for a track
CREATE OR REPLACE FUNCTION public.get_track_daily_stats(
  p_track_id UUID,
  p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
  stat_date DATE,
  listens_count INTEGER,
  unique_listeners INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH date_range AS (
    SELECT CURRENT_DATE - (i || ' days')::INTERVAL AS d
    FROM generate_series(0, p_days - 1) i
  )
  SELECT
    COALESCE(dts.date, dr.d::DATE) AS stat_date,
    COALESCE(dts.listens_count, 0) AS listens_count,
    COALESCE(dts.unique_listeners, 0) AS unique_listeners
  FROM date_range dr
  LEFT JOIN public.daily_track_stats dts ON dts.date = dr.d::DATE AND dts.track_id = p_track_id
  ORDER BY stat_date DESC;
$$;

-- 7. Function to get artist summary
CREATE OR REPLACE FUNCTION public.get_artist_summary(p_artist_id UUID)
RETURNS TABLE (
  total_listens BIGINT,
  total_unique_listeners BIGINT,
  total_tracks BIGINT,
  avg_listens_per_track NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COUNT(tl.id)::BIGINT AS total_listens,
    COUNT(DISTINCT tl.user_id)::BIGINT AS total_unique_listeners,
    COUNT(DISTINCT s.id)::BIGINT AS total_tracks,
    CASE 
      WHEN COUNT(DISTINCT s.id) > 0 THEN (COUNT(tl.id)::NUMERIC / COUNT(DISTINCT s.id)::NUMERIC)
      ELSE 0
    END AS avg_listens_per_track
  FROM public.songs s
  LEFT JOIN public.track_listens tl ON tl.track_id = s.id
  WHERE s.owner_id = p_artist_id AND s.status = 'approved';
$$;

-- 8. Function to get top tracks for artist
CREATE OR REPLACE FUNCTION public.get_artist_top_tracks(
  p_artist_id UUID,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  track_id UUID,
  track_title TEXT,
  listens_count BIGINT,
  unique_listeners BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    s.title,
    COUNT(tl.id)::BIGINT AS listens_count,
    COUNT(DISTINCT tl.user_id)::BIGINT AS unique_listeners
  FROM public.songs s
  LEFT JOIN public.track_listens tl ON tl.track_id = s.id
  WHERE s.owner_id = p_artist_id AND s.status = 'approved'
  GROUP BY s.id, s.title
  ORDER BY listens_count DESC
  LIMIT p_limit;
$$;

-- 9. Function to get country distribution
CREATE OR REPLACE FUNCTION public.get_artist_country_distribution(
  p_artist_id UUID,
  p_track_id UUID DEFAULT NULL
)
RETURNS TABLE (
  country TEXT,
  listens_count BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(tcs.country, 'Unknown') AS country,
    COUNT(tl.id)::BIGINT AS listens_count
  FROM public.track_listens tl
  LEFT JOIN public.track_country_stats tcs ON tcs.track_id = tl.track_id AND tcs.country = tl.country
  WHERE tl.artist_id = p_artist_id
    AND (p_track_id IS NULL OR tl.track_id = p_track_id)
  GROUP BY COALESCE(tcs.country, 'Unknown')
  ORDER BY listens_count DESC;
$$;

-- 10. Grant permissions
GRANT EXECUTE ON FUNCTION public.record_track_listen(UUID, UUID, INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_track_daily_stats(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_artist_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_artist_top_tracks(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_artist_country_distribution(UUID, UUID) TO authenticated;
