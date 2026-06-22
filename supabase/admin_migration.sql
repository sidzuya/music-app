-- ============================================================
-- Admin Panel Migration
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add role column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- 2. Set your admin user (replace with your actual user email after running)
-- UPDATE profiles SET role = 'admin' WHERE email = 'your-admin@email.com';

-- 3. Create covers bucket (for album art)
INSERT INTO storage.buckets (id, name, public)
VALUES ('covers', 'covers', true)
ON CONFLICT (id) DO NOTHING;

-- 4. RLS policies for covers bucket
CREATE POLICY "Public read covers"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'covers');

CREATE POLICY "Admin insert covers"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'covers'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admin delete covers"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'covers'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 5. Admin policies for songs bucket
CREATE POLICY "Admin insert songs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'songs'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admin delete songs"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'songs'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 6. Admin policies for featured bucket
CREATE POLICY "Admin insert featured"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'featured'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admin delete featured"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'featured'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 7. Allow admins to read all profiles (for user count dashboard)
CREATE POLICY "Admin read all profiles"
  ON profiles FOR SELECT
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role = 'admin'
    )
  );
