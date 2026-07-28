-- ============================================================
-- Ormond Turtle Nest Log — Supabase Setup SQL
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. Create the turtle_nests table
CREATE TABLE IF NOT EXISTS public.turtle_nests (
  id                   UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  nest_number          TEXT        NOT NULL,
  species              TEXT        NOT NULL CHECK (species IN ('loggerhead', 'leatherback', 'green')),
  date_found           DATE        NOT NULL,
  latitude             DOUBLE PRECISION NOT NULL,
  longitude            DOUBLE PRECISION NOT NULL,
  photo_url            TEXT,
  notes                TEXT,
  -- Predicted hatch window. Nullable: these were added after the first
  -- nests were logged, so historical rows can legitimately lack them.
  hatch_date_min       DATE,
  hatch_date_max       DATE,
  -- Observed outcome, filled in from the edit form after a nest hatches.
  hatch_date           DATE,
  num_hatchlings       INT,
  whole_eggs_remaining INT,
  created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- If you are upgrading an existing table rather than creating a fresh one:
ALTER TABLE public.turtle_nests
  ADD COLUMN IF NOT EXISTS hatch_date           DATE,
  ADD COLUMN IF NOT EXISTS num_hatchlings       INT,
  ADD COLUMN IF NOT EXISTS whole_eggs_remaining INT;
ALTER TABLE public.turtle_nests ALTER COLUMN hatch_date_min DROP NOT NULL;
ALTER TABLE public.turtle_nests ALTER COLUMN hatch_date_max DROP NOT NULL;

-- 2. Enable Row Level Security (required for anon key access)
ALTER TABLE public.turtle_nests ENABLE ROW LEVEL SECURITY;

-- 3. Allow anyone with the anon key to read, insert, update, and delete nests
--    (This is appropriate for a small trusted community app.
--     Tighten with auth if you later add user login.)
--    NOTE: the UPDATE policy is required by the edit-nest form. Without it
--    RLS silently rejects every edit, and saves appear to do nothing.
CREATE POLICY "Allow public read"
  ON public.turtle_nests
  FOR SELECT
  USING (true);

CREATE POLICY "Allow public insert"
  ON public.turtle_nests
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow public update"
  ON public.turtle_nests
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow public delete"
  ON public.turtle_nests
  FOR DELETE
  USING (true);

-- 4. Helpful index for ordering by newest first
CREATE INDEX IF NOT EXISTS turtle_nests_created_at_idx
  ON public.turtle_nests (created_at DESC);

-- ============================================================
-- STORAGE BUCKET SETUP  (do this in the Supabase UI)
-- ============================================================
-- After running the SQL above, go to:
--   Storage → New bucket
--   Name: nest-photos
--   Public: YES (toggle on)
--   Click "Create bucket"
--
-- Then add a storage policy:
--   Storage → nest-photos → Policies → New policy → "Full access" template
--   Or use the SQL below:

INSERT INTO storage.buckets (id, name, public)
VALUES ('nest-photos', 'nest-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

CREATE POLICY "Public read nest photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'nest-photos');

CREATE POLICY "Public upload nest photos"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'nest-photos');

CREATE POLICY "Public delete nest photos"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'nest-photos');
