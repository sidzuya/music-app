-- ============================================================
-- Admin Songs Permissions Migration
-- Run this in Supabase SQL Editor.
-- Ensures admins can insert/update/delete into songs &
-- featured_songs tables and upload to Storage buckets.
-- Safe to re-run (idempotent).
-- ============================================================

-- 1. Enable RLS (songs is currently disabled / "Unrestricted")
ALTER TABLE public.songs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.featured_songs  ENABLE ROW LEVEL SECURITY;

-- 2. Policies for `songs`
DROP POLICY IF EXISTS "songs readable by authenticated" ON public.songs;
CREATE POLICY "songs readable by authenticated"
  ON public.songs FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "songs admin insert" ON public.songs;
CREATE POLICY "songs admin insert"
  ON public.songs FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "songs admin update" ON public.songs;
CREATE POLICY "songs admin update"
  ON public.songs FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "songs admin delete" ON public.songs;
CREATE POLICY "songs admin delete"
  ON public.songs FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 3. Policies for `featured_songs`
DROP POLICY IF EXISTS "featured_songs readable by authenticated" ON public.featured_songs;
CREATE POLICY "featured_songs readable by authenticated"
  ON public.featured_songs FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "featured_songs admin insert" ON public.featured_songs;
CREATE POLICY "featured_songs admin insert"
  ON public.featured_songs FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "featured_songs admin update" ON public.featured_songs;
CREATE POLICY "featured_songs admin update"
  ON public.featured_songs FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "featured_songs admin delete" ON public.featured_songs;
CREATE POLICY "featured_songs admin delete"
  ON public.featured_songs FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 4. Storage policies: allow admin to upload/delete in songs / featured / covers
DROP POLICY IF EXISTS "Admin insert songs" ON storage.objects;
CREATE POLICY "Admin insert songs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'songs'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin delete songs" ON storage.objects;
CREATE POLICY "Admin delete songs"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'songs'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin insert featured" ON storage.objects;
CREATE POLICY "Admin insert featured"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'featured'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin delete featured" ON storage.objects;
CREATE POLICY "Admin delete featured"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'featured'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin insert covers" ON storage.objects;
CREATE POLICY "Admin insert covers"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'covers'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin delete covers" ON storage.objects;
CREATE POLICY "Admin delete covers"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'covers'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 5. Ensure your account is admin (uncomment and set your email if needed):
-- UPDATE profiles SET role = 'admin' WHERE email = 'your-admin@email.com';
