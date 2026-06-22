-- ============================================================
-- Enable Realtime for notifications table
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- Add notifications table to the supabase_realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
