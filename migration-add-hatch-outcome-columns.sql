-- ============================================================
-- MIGRATION — run once, in Supabase Dashboard → SQL Editor → New query
--
-- WHY: the edit-nest form writes hatch_date, num_hatchlings and
-- whole_eggs_remaining, but these columns were never added to the live
-- database. PostgREST rejects every save with:
--
--     42703  column turtle_nests.hatch_date does not exist
--
-- So "Save Changes" in the edit form has never worked against this
-- project. Verified against the live DB on 2026-07-28.
--
-- Safe to run more than once.
-- ============================================================

ALTER TABLE public.turtle_nests
  ADD COLUMN IF NOT EXISTS hatch_date           DATE,
  ADD COLUMN IF NOT EXISTS num_hatchlings       INT,
  ADD COLUMN IF NOT EXISTS whole_eggs_remaining INT;

-- The app treats the predicted hatch window as optional (false crawls have
-- no window at all), but the original table declared these NOT NULL.
ALTER TABLE public.turtle_nests ALTER COLUMN hatch_date_min DROP NOT NULL;
ALTER TABLE public.turtle_nests ALTER COLUMN hatch_date_max DROP NOT NULL;

-- Verify — should list all three new columns:
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'turtle_nests'
  AND column_name IN ('hatch_date', 'num_hatchlings', 'whole_eggs_remaining')
ORDER BY column_name;
