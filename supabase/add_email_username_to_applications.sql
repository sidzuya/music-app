-- ============================================================
-- Add missing email and username columns to artist_applications table
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE public.artist_applications ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.artist_applications ADD COLUMN IF NOT EXISTS username TEXT;
