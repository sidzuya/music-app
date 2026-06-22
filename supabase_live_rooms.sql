-- Безопасное создание таблицы (если ещё не существует)
CREATE TABLE IF NOT EXISTS public.live_rooms (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  host_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  current_song jsonb,
  created_at timestamp with time zone DEFAULT now()
);

-- Включить RLS (безопасно повторить)
ALTER TABLE public.live_rooms ENABLE ROW LEVEL SECURITY;

-- Удалить старые политики и пересоздать (если уже существуют)
DROP POLICY IF EXISTS "Enable read access for all users" ON public.live_rooms;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.live_rooms;
DROP POLICY IF EXISTS "Enable update for host only" ON public.live_rooms;
DROP POLICY IF EXISTS "Enable delete for host only" ON public.live_rooms;

CREATE POLICY "Enable read access for all users" ON public.live_rooms
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users only" ON public.live_rooms
  FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Enable update for host only" ON public.live_rooms
  FOR UPDATE USING (auth.uid() = host_id);

CREATE POLICY "Enable delete for host only" ON public.live_rooms
  FOR DELETE USING (auth.uid() = host_id);
