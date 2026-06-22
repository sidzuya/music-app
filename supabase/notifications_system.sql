-- ============================================================
-- Notifications System
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'artist_application_approved', 'artist_application_rejected', 'song_approved', 'song_rejected', etc.
  title TEXT NOT NULL,
  message TEXT,
  data JSONB, -- Additional data like application_id, song_id
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_created_idx ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_read_idx ON public.notifications(read);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS: Users can only read their own notifications
DROP POLICY IF EXISTS "notifications self read" ON public.notifications;
CREATE POLICY "notifications self read"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- RLS: Only server can insert/update notifications (via trigger/RPC)
DROP POLICY IF EXISTS "notifications server insert" ON public.notifications;
CREATE POLICY "notifications server insert"
  ON public.notifications FOR INSERT
  WITH CHECK (FALSE); -- Only security definer functions can insert

DROP POLICY IF EXISTS "notifications self update" ON public.notifications;
CREATE POLICY "notifications self update"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Update approve_artist_application to send notification
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

  -- Send notification to user
  INSERT INTO public.notifications (user_id, type, title, message, data)
  VALUES (
    app.user_id,
    'artist_application_approved',
    'Заявка одобрена',
    'Поздравляем! Ваша заявка на роль исполнителя одобрена. Вы можете начать загружать свои треки.',
    jsonb_build_object(
      'application_id', app.id,
      'artist_name', app.artist_name,
      'reviewer_note', note
    )
  );

  RETURN app;
END;
$$;

-- 3. Update reject_artist_application to send notification
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

  -- Send notification to user
  INSERT INTO public.notifications (user_id, type, title, message, data)
  VALUES (
    app.user_id,
    'artist_application_rejected',
    'Заявка отклонена',
    'К сожалению, ваша заявка на роль исполнителя была отклонена. Причина: ' || note,
    jsonb_build_object(
      'application_id', app.id,
      'artist_name', app.artist_name,
      'rejection_reason', note
    )
  );

  RETURN app;
END;
$$;

-- 4. Create function to mark notification as read
CREATE OR REPLACE FUNCTION public.mark_notification_as_read(notification_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.notifications
     SET read = TRUE
   WHERE id = notification_id
     AND user_id = auth.uid();
END;
$$;

-- 5. Create function to get unread notification count
CREATE OR REPLACE FUNCTION public.unread_notification_count()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::INTEGER FROM public.notifications
  WHERE user_id = auth.uid() AND read = FALSE;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.mark_notification_as_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unread_notification_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_artist_application(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_artist_application(UUID, TEXT) TO authenticated;
