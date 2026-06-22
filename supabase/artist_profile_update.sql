
-- ============================================================================
-- Music App — Artist Profile Update.
-- ----------------------------------------------------------------------------
-- This script adds artist profile fields to the public.profiles table.
-- ============================================================================

-- Add new columns to profiles table for artist details
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='banner_image') THEN
        ALTER TABLE public.profiles ADD COLUMN banner_image text;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='bio') THEN
        ALTER TABLE public.profiles ADD COLUMN bio text;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='social_links') THEN
        ALTER TABLE public.profiles ADD COLUMN social_links jsonb DEFAULT '[]'::jsonb;
    END IF;
END $$;
