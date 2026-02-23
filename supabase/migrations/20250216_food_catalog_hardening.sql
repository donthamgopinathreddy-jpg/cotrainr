-- =============================================================================
-- FOOD CATALOG HARDENING
-- Additive/idempotent patches for foods + food_portions + admin RPCs.
-- Run after 20250215_add_food_catalog.sql
-- Note: uq_foods_lower_name requires no duplicate lower(trim(name)). If you have
--       duplicates, delete them first or the migration will fail.
-- =============================================================================

-- =============================================================================
-- 1. Uniqueness for foods by name (case-insensitive)
-- =============================================================================
DROP INDEX IF EXISTS public.idx_foods_lower_name;
CREATE UNIQUE INDEX IF NOT EXISTS uq_foods_lower_name ON public.foods (lower(trim(name)));

-- =============================================================================
-- 2. One default portion per food
-- =============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_food_portions_one_default_per_food
  ON public.food_portions (food_id)
  WHERE is_default = true;

-- =============================================================================
-- 3. Guard meal_items alteration (only if table exists)
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
-- 4. admin_upsert_food: upsert by name + validation + security
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
BEGIN
  -- Normalize name: trim, collapse multiple spaces
  v_name := regexp_replace(trim(COALESCE(p_name, '')), '\s+', ' ', 'g');

  IF v_name = '' THEN
    RAISE EXCEPTION 'name is required';
  END IF;

  -- Reject negative macros
  IF COALESCE(p_kcal_100g, 0) < 0 OR COALESCE(p_protein_100g, 0) < 0
     OR COALESCE(p_carbs_100g, 0) < 0 OR COALESCE(p_fat_100g, 0) < 0
     OR COALESCE(p_fiber_100g, 0) < 0 THEN
    RAISE EXCEPTION 'kcal, protein, carbs, fat, fiber must be >= 0';
  END IF;

  -- Find existing by lower(name); prefer it over p_id for upsert-by-name
  SELECT id INTO v_id
  FROM public.foods
  WHERE lower(trim(name)) = lower(v_name)
  LIMIT 1;

  v_id := COALESCE(v_id, p_id, gen_random_uuid());

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

  RETURN v_id;
END;
$$;

ALTER FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) TO service_role;

-- =============================================================================
-- 5. admin_upsert_portion: clear other defaults when setting is_default=true
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

  -- When setting is_default=true, clear other defaults for this food (enforces one default per food)
  IF COALESCE(p_is_default, false) THEN
    UPDATE public.food_portions
    SET is_default = false
    WHERE food_id = p_food_id AND is_default = true;
  END IF;

  v_id := COALESCE(p_id, gen_random_uuid());

  INSERT INTO public.food_portions (id, food_id, label, grams, is_default)
  VALUES (v_id, p_food_id, trim(p_label), p_grams, COALESCE(p_is_default, false))
  ON CONFLICT (id) DO UPDATE SET
    food_id = EXCLUDED.food_id,
    label = EXCLUDED.label,
    grams = EXCLUDED.grams,
    is_default = EXCLUDED.is_default;

  RETURN v_id;
END;
$$;

ALTER FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) TO service_role;

-- =============================================================================
-- 6. admin_search_foods: security hardening
-- =============================================================================
ALTER FUNCTION public.admin_search_foods(text, int, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_foods(text, int, boolean) TO service_role;
