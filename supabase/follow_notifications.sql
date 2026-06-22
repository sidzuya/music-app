-- Trigger follow notifications in Supabase.
--
-- Apply this in the Supabase SQL Editor (Dashboard → SQL).
-- Idempotent: safe to run multiple times.

-- 1) Create follow notification handler function
CREATE OR REPLACE FUNCTION public.handle_follow_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  follower_username TEXT;
BEGIN
  -- Get username of the follower
  SELECT username INTO follower_username FROM public.profiles WHERE id = NEW.follower_id;
  
  -- Send notification to target user (followee)
  INSERT INTO public.notifications (user_id, type, title, message, data)
  VALUES (
    NEW.followee_id,
    'new_follower',
    'Новый подписчик',
    '@' || COALESCE(follower_username, 'Пользователь') || ' подписался на вас',
    jsonb_build_object(
      'follower_id', NEW.follower_id,
      'follower_username', follower_username
    )
  );
  
  RETURN NEW;
END;
$$;

-- 2) Create unfollow notification cleanup function
CREATE OR REPLACE FUNCTION public.handle_unfollow_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Remove notification from user_id if they unfollow
  DELETE FROM public.notifications
   WHERE user_id = OLD.followee_id
     AND type = 'new_follower'
     AND (data->>'follower_id')::UUID = OLD.follower_id;
     
  RETURN OLD;
END;
$$;

-- 3) Attach triggers to public.follows table
DROP TRIGGER IF EXISTS on_follow_create_notification ON public.follows;
CREATE TRIGGER on_follow_create_notification
  AFTER INSERT ON public.follows
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_follow_notification();

DROP TRIGGER IF EXISTS on_unfollow_remove_notification ON public.follows;
CREATE TRIGGER on_unfollow_remove_notification
  AFTER DELETE ON public.follows
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_unfollow_notification();
