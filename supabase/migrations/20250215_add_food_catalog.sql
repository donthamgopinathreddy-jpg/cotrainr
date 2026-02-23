-- =============================================================================
-- FOOD CATALOG: foods + food_portions
-- Per-100g nutrition for auto-calculation of macros from grams.
-- Supports Indian + international foods, USDA FDC imports, verified/unverified.
-- =============================================================================

-- =============================================================================
-- 1. public.foods
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.foods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  aliases text[],
  cuisine text,
  category text,
  is_prepared boolean NOT NULL DEFAULT false,
  source text,
  source_ref text,
  kcal_100g numeric(8,2) NOT NULL DEFAULT 0,
  protein_100g numeric(8,2) NOT NULL DEFAULT 0,
  carbs_100g numeric(8,2) NOT NULL DEFAULT 0,
  fat_100g numeric(8,2) NOT NULL DEFAULT 0,
  fiber_100g numeric(8,2) NOT NULL DEFAULT 0,
  micros jsonb,
  verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for search and filtering
CREATE INDEX IF NOT EXISTS idx_foods_lower_name ON public.foods (lower(name));
CREATE INDEX IF NOT EXISTS idx_foods_aliases_gin ON public.foods USING gin (aliases);
CREATE INDEX IF NOT EXISTS idx_foods_verified ON public.foods (verified) WHERE verified = true;

COMMENT ON TABLE public.foods IS 'Food catalog with per-100g nutrition. Used for meal logging macro calculation.';

-- =============================================================================
-- 2. public.food_portions
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.food_portions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id uuid NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
  label text NOT NULL,
  grams numeric(8,2) NOT NULL CHECK (grams > 0),
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_food_portions_food_id ON public.food_portions (food_id);

COMMENT ON TABLE public.food_portions IS 'Saved portions for foods (e.g. 1 cup = 240g). Used for quick gram selection.';

-- =============================================================================
-- 3. updated_at trigger for foods
-- =============================================================================
CREATE OR REPLACE FUNCTION public.set_foods_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_foods_updated_at ON public.foods;
CREATE TRIGGER trg_foods_updated_at
  BEFORE UPDATE ON public.foods
  FOR EACH ROW
  EXECUTE FUNCTION public.set_foods_updated_at();

-- =============================================================================
-- 4. Add food_id to meal_items (nullable, backward compatible)
-- =============================================================================
ALTER TABLE public.meal_items
  ADD COLUMN IF NOT EXISTS food_id uuid REFERENCES public.foods(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_meal_items_food_id ON public.meal_items (food_id) WHERE food_id IS NOT NULL;

-- =============================================================================
-- 5. RLS for foods
-- =============================================================================
ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can select foods" ON public.foods;
CREATE POLICY "Authenticated can select foods"
  ON public.foods FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE policy for authenticated; admin uses service_role RPCs

-- =============================================================================
-- 6. RLS for food_portions
-- =============================================================================
ALTER TABLE public.food_portions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can select food_portions" ON public.food_portions;
CREATE POLICY "Authenticated can select food_portions"
  ON public.food_portions FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE policy for authenticated

-- =============================================================================
-- 7. Admin RPCs (service_role only)
-- =============================================================================

-- admin_upsert_food
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
BEGIN
  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'name is required';
  END IF;

  v_id := COALESCE(p_id, gen_random_uuid());

  INSERT INTO public.foods (
    id, name, aliases, cuisine, category, is_prepared,
    source, source_ref, kcal_100g, protein_100g, carbs_100g, fat_100g, fiber_100g,
    micros, verified
  )
  VALUES (
    v_id, trim(p_name), p_aliases, p_cuisine, p_category, COALESCE(p_is_prepared, false),
    p_source, p_source_ref,
    COALESCE(p_kcal_100g, 0), COALESCE(p_protein_100g, 0), COALESCE(p_carbs_100g, 0),
    COALESCE(p_fat_100g, 0), COALESCE(p_fiber_100g, 0),
    p_micros, COALESCE(p_verified, false)
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

REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) TO service_role;

-- admin_upsert_portion (required params first for Postgres 42P13)
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

REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) TO service_role;

-- admin_search_foods (for admin tooling; app uses direct SELECT with RLS)
CREATE OR REPLACE FUNCTION public.admin_search_foods(
  p_query text DEFAULT '',
  p_limit int DEFAULT 50,
  p_verified_only boolean DEFAULT false
)
RETURNS SETOF public.foods
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM public.foods f
  WHERE (p_verified_only = false OR f.verified = true)
    AND (p_query IS NULL OR trim(p_query) = '' OR
         lower(f.name) LIKE '%' || lower(trim(p_query)) || '%' OR
         EXISTS (SELECT 1 FROM unnest(COALESCE(f.aliases, '{}')) a WHERE lower(a) LIKE '%' || lower(trim(p_query)) || '%'))
  ORDER BY f.name
  LIMIT greatest(1, least(COALESCE(p_limit, 50), 200));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_foods(text, int, boolean) TO service_role;
