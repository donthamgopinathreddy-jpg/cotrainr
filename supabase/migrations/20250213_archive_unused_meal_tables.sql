-- Archive unused meal tables (meal_tracker uses local state only)
-- RUN ONLY AFTER: 1) Backup, 2) Verification that no app code uses these tables
-- This script is for manual review. Uncomment and run when ready.

-- Step 1: Create archive schema
-- CREATE SCHEMA IF NOT EXISTS archive;

-- Step 2: Verify tables are empty or you have backed up data
-- SELECT 'meals' AS tbl, COUNT(*) FROM public.meals
-- UNION ALL SELECT 'meal_items', COUNT(*) FROM public.meal_items
-- UNION ALL SELECT 'meal_media', COUNT(*) FROM public.meal_media;

-- Step 3: Drop RLS policies (required before moving tables)
-- DROP POLICY IF EXISTS "Users can manage own meal media" ON public.meal_media;
-- DROP POLICY IF EXISTS "Users can manage own meal items" ON public.meal_items;
-- DROP POLICY IF EXISTS "Users can manage own meals" ON public.meals;

-- Step 4: Move to archive (or DROP if empty and you prefer)
-- ALTER TABLE public.meal_media SET SCHEMA archive;
-- ALTER TABLE public.meal_items SET SCHEMA archive;
-- ALTER TABLE public.meals SET SCHEMA archive;

-- Alternative: Drop entirely (only if archived or empty)
-- DROP TABLE IF EXISTS public.meal_media CASCADE;
-- DROP TABLE IF EXISTS public.meal_items CASCADE;
-- DROP TABLE IF EXISTS public.meals CASCADE;
