-- =============================================================================
-- FOOD CATALOG HARDENING V2
-- Additive/idempotent patches. Run after 20250216_food_catalog_hardening.sql
-- - Generated column normalized_name for consistent dedupe/upsert
-- - Deterministic dedupe before unique index
-- - admin_upsert_food uses normalized_name + unique_violation handling
-- - admin_upsert_portion: insert first, then set default (safer)
-- =============================================================================

-- =============================================================================
-- A) Add generated column normalized_name
-- =============================================================================
ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS normalized_name text
  GENERATED ALWAYS AS (lower(regexp_replace(trim(name), '\s+', ' ', 'g'))) STORED;

-- =============================================================================
-- B) Deterministic dedupe BEFORE unique index
-- Keep earliest created_at, else smallest uuid. Delete the rest.
-- =============================================================================
DO $$
DECLARE
  v_has_created_at boolean;
BEGIN
  IF to_regclass('public.foods') IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'created_at'
  ) INTO v_has_created_at;

  IF NOT v_has_created_at THEN
    RETURN;  -- Skip dedupe if no created_at
  END IF;

  -- Delete duplicates: keep one per normalized_name (earliest created_at, then smallest id)
  WITH ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY normalized_name
             ORDER BY created_at ASC NULLS LAST, id ASC
           ) AS rn
    FROM public.foods
  )
  DELETE FROM public.foods
  WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
END
$$;

-- =============================================================================
-- C) Drop old index, create unique index on normalized_name
-- =============================================================================
DROP INDEX IF EXISTS public.uq_foods_lower_name;
DROP INDEX IF EXISTS public.idx_foods_lower_name;
CREATE UNIQUE INDEX IF NOT EXISTS uq_foods_normalized_name ON public.foods (normalized_name);

-- D) Search index: unique index already supports lookups; add non-unique only if needed for other queries.
-- The unique index uq_foods_normalized_name serves equality lookups. For LIKE/ILIKE search,
-- idx_foods_aliases_gin and the unique index are sufficient. Skip redundant idx to avoid bloat.

-- =============================================================================
-- E) Keep portions partial unique index (already exists from v1)
-- =============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_food_portions_one_default_per_food
  ON public.food_portions (food_id)
  WHERE is_default = true;

-- =============================================================================
-- F) Guard meal_items alteration (only if table exists)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.meal_items') IS NOT NULL THEN
    ALTER TABLE public.meal_items
      ADD COLUMN IF NOT EXISTS food_id uuid REFERENCES public.foods(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_meal_items_food_id ON public.meal_items (food_id) WHERE food_id IS NOT NULL;
  END IF;
END
$$;

-- =============================================================================
-- G) admin_upsert_food: use normalized_name + unique_violation handling
-- =============================================================================
CREATE OR REPLACE FUNCTION public.admin_upsert_food(
  p_id uuid DEFAULT NULL,
  p_name text DEFAULT NULL,
  p_aliases text[] DEFAULT NULL,
  p_cuisine text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_is_prepared boolean DEFAULT false,
  p_source text DEFAULT NULL,
  p_source_ref text DEFAULT NULL,
  p_kcal_100g numeric DEFAULT 0,
  p_protein_100g numeric DEFAULT 0,
  p_carbs_100g numeric DEFAULT 0,
  p_fat_100g numeric DEFAULT 0,
  p_fiber_100g numeric DEFAULT 0,
  p_micros jsonb DEFAULT NULL,
  p_verified boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_name text;
  v_normalized text;
BEGIN
  -- Normalize: trim, collapse multiple spaces, lower
  v_name := regexp_replace(trim(COALESCE(p_name, '')), '\s+', ' ', 'g');
  v_normalized := lower(v_name);

  IF v_name = '' THEN
    RAISE EXCEPTION 'name is required';
  END IF;

  -- Reject negative macros
  IF COALESCE(p_kcal_100g, 0) < 0 OR COALESCE(p_protein_100g, 0) < 0
     OR COALESCE(p_carbs_100g, 0) < 0 OR COALESCE(p_fat_100g, 0) < 0
     OR COALESCE(p_fiber_100g, 0) < 0 THEN
    RAISE EXCEPTION 'kcal, protein, carbs, fat, fiber must be >= 0';
  END IF;

  -- Find existing by normalized_name
  SELECT id INTO v_id
  FROM public.foods
  WHERE normalized_name = v_normalized
  LIMIT 1;

  v_id := COALESCE(v_id, p_id, gen_random_uuid());

  BEGIN
    INSERT INTO public.foods (
      id, name, aliases, cuisine, category, is_prepared,
      source, source_ref, kcal_100g, protein_100g, carbs_100g, fat_100g, fiber_100g,
      micros, verified
    )
    VALUES (
      v_id, v_name, p_aliases, p_cuisine, p_category, COALESCE(p_is_prepared, false),
      p_source, p_source_ref,
      GREATEST(0, COALESCE(p_kcal_100g, 0)),
      GREATEST(0, COALESCE(p_protein_100g, 0)),
      GREATEST(0, COALESCE(p_carbs_100g, 0)),
      GREATEST(0, COALESCE(p_fat_100g, 0)),
      GREATEST(0, COALESCE(p_fiber_100g, 0)),
      p_micros,
      COALESCE(p_verified, false)
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      aliases = EXCLUDED.aliases,
      cuisine = EXCLUDED.cuisine,
      category = EXCLUDED.category,
      is_prepared = EXCLUDED.is_prepared,
      source = EXCLUDED.source,
      source_ref = EXCLUDED.source_ref,
      kcal_100g = EXCLUDED.kcal_100g,
      protein_100g = EXCLUDED.protein_100g,
      carbs_100g = EXCLUDED.carbs_100g,
      fat_100g = EXCLUDED.fat_100g,
      fiber_100g = EXCLUDED.fiber_100g,
      micros = EXCLUDED.micros,
      verified = EXCLUDED.verified,
      updated_at = now();
  EXCEPTION
    WHEN unique_violation THEN
      -- Concurrency: another row with same normalized_name won; re-select id
      SELECT id INTO v_id
      FROM public.foods
      WHERE normalized_name = v_normalized
      LIMIT 1;
      IF v_id IS NULL THEN
        RAISE;
      END IF;
  END;

  RETURN v_id;
END;
$$;

ALTER FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) TO service_role;

-- =============================================================================
-- H) admin_upsert_portion: insert/update first, then set default (safer)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.admin_upsert_portion(
  p_food_id uuid,
  p_label text,
  p_grams numeric,
  p_is_default boolean DEFAULT false,
  p_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_food_id IS NULL OR p_label IS NULL OR trim(p_label) = '' OR p_grams IS NULL OR p_grams <= 0 THEN
    RAISE EXCEPTION 'food_id, label, and grams > 0 are required';
  END IF;

  v_id := COALESCE(p_id, gen_random_uuid());

  -- Insert/update first (with is_default=false to avoid unique violation)
  INSERT INTO public.food_portions (id, food_id, label, grams, is_default)
  VALUES (v_id, p_food_id, trim(p_label), p_grams, false)
  ON CONFLICT (id) DO UPDATE SET
    food_id = EXCLUDED.food_id,
    label = EXCLUDED.label,
    grams = EXCLUDED.grams,
    is_default = false;

  -- If p_is_default=true, set ours to true and clear others (one update)
  IF COALESCE(p_is_default, false) THEN
    UPDATE public.food_portions
    SET is_default = (id = v_id)
    WHERE food_id = p_food_id;
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) TO service_role;

-- =============================================================================
-- I) admin_search_foods: security hardening
-- =============================================================================
ALTER FUNCTION public.admin_search_foods(text, int, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_foods(text, int, boolean) TO service_role;

-- =============================================================================
-- VERIFICATION CHECKLIST (run manually after migration)
-- =============================================================================
-- 1) Duplicates by normalized_name should be 0:
--    SELECT normalized_name, count(*) FROM public.foods GROUP BY normalized_name HAVING count(*) > 1;
--
-- 2) uq_foods_normalized_name exists:
--    SELECT indexname FROM pg_indexes WHERE tablename = 'foods' AND indexname = 'uq_foods_normalized_name';
--
-- 3) One default portion constraint works (no food should have >1 default):
--    SELECT food_id, count(*) FROM public.food_portions WHERE is_default = true GROUP BY food_id HAVING count(*) > 1;
--
-- 4) Calling admin_upsert_food twice with same name updates same row:
--    SELECT admin_upsert_food(p_name := 'Test Food', p_kcal_100g := 100);
--    SELECT admin_upsert_food(p_name := 'Test Food', p_kcal_100g := 200);
--    SELECT id, name, kcal_100g FROM public.foods WHERE normalized_name = 'test food';
--    -- Should return 1 row with kcal_100g = 200
