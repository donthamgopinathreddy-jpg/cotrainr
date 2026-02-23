-- =============================================================================
-- FOOD CATALOG HARDENING V4
-- Additive/idempotent patches. Run after 20250218_food_catalog_hardening_v3.sql
-- Fixes:
-- 1) to_regclass guards: ALTER TABLE, CREATE INDEX wrapped so migration won't fail if tables missing
-- 2) admin_upsert_food: v_normalized matches generated column expression EXACTLY
-- 3) Dedupe: remap food_portions.food_id and meal_items.food_id (loser->winner) before deleting losers
-- 4) Additive/idempotent, safe for reruns
-- =============================================================================

-- =============================================================================
-- A) Add generated column normalized_name (guarded)
-- NOTE: normalized_name MUST be GENERATED ALWAYS AS
--   (lower(regexp_replace(trim(name), '\s+', ' ', 'g'))) STORED
-- If drift is detected (see verification e), fix manually. Do NOT auto-drop.
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.foods') IS NOT NULL THEN
    ALTER TABLE public.foods
      ADD COLUMN IF NOT EXISTS normalized_name text
      GENERATED ALWAYS AS (lower(regexp_replace(trim(name), '\s+', ' ', 'g'))) STORED;
  END IF;
END
$$;

-- =============================================================================
-- B) Deterministic dedupe with remapping BEFORE unique index
-- 1) Remap food_portions.food_id (loser -> winner)
-- 2) Remap meal_items.food_id (loser -> winner) if table/column exist
-- 3) Delete loser food rows
-- Winner: earliest created_at ASC NULLS LAST, then smallest id; else smallest id
-- =============================================================================
DO $$
DECLARE
  v_has_created_at boolean;
  v_has_meal_items boolean;
  v_has_meal_items_food_id boolean;
BEGIN
  IF to_regclass('public.foods') IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'created_at'
  ) INTO v_has_created_at;

  v_has_meal_items := (to_regclass('public.meal_items') IS NOT NULL);
  IF v_has_meal_items THEN
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'meal_items' AND column_name = 'food_id'
    ) INTO v_has_meal_items_food_id;
  ELSE
    v_has_meal_items_food_id := false;
  END IF;

  IF v_has_created_at THEN
    -- Remap references: loser -> winner
    IF to_regclass('public.food_portions') IS NOT NULL THEN
      WITH ranked AS (
        SELECT id, normalized_name,
               ROW_NUMBER() OVER (
                 PARTITION BY normalized_name
                 ORDER BY created_at ASC NULLS LAST, id ASC
               ) AS rn
        FROM public.foods
      ),
      loser_winner AS (
        SELECT r_loser.id AS loser_id, r_winner.id AS winner_id
        FROM ranked r_loser
        JOIN ranked r_winner ON r_loser.normalized_name = r_winner.normalized_name AND r_winner.rn = 1
        WHERE r_loser.rn > 1
      )
      UPDATE public.food_portions fp
      SET food_id = lw.winner_id
      FROM loser_winner lw
      WHERE fp.food_id = lw.loser_id;
    END IF;

    IF v_has_meal_items_food_id THEN
      WITH ranked AS (
        SELECT id, normalized_name,
               ROW_NUMBER() OVER (
                 PARTITION BY normalized_name
                 ORDER BY created_at ASC NULLS LAST, id ASC
               ) AS rn
        FROM public.foods
      ),
      loser_winner AS (
        SELECT r_loser.id AS loser_id, r_winner.id AS winner_id
        FROM ranked r_loser
        JOIN ranked r_winner ON r_loser.normalized_name = r_winner.normalized_name AND r_winner.rn = 1
        WHERE r_loser.rn > 1
      )
      UPDATE public.meal_items mi
      SET food_id = lw.winner_id
      FROM loser_winner lw
      WHERE mi.food_id = lw.loser_id;
    END IF;

    -- Delete losers
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
  ELSE
    -- No created_at: keep smallest id
    IF to_regclass('public.food_portions') IS NOT NULL THEN
      WITH ranked AS (
        SELECT id, normalized_name,
               ROW_NUMBER() OVER (PARTITION BY normalized_name ORDER BY id ASC) AS rn
        FROM public.foods
      ),
      loser_winner AS (
        SELECT r_loser.id AS loser_id, r_winner.id AS winner_id
        FROM ranked r_loser
        JOIN ranked r_winner ON r_loser.normalized_name = r_winner.normalized_name AND r_winner.rn = 1
        WHERE r_loser.rn > 1
      )
      UPDATE public.food_portions fp
      SET food_id = lw.winner_id
      FROM loser_winner lw
      WHERE fp.food_id = lw.loser_id;
    END IF;

    IF v_has_meal_items_food_id THEN
      WITH ranked AS (
        SELECT id, normalized_name,
               ROW_NUMBER() OVER (PARTITION BY normalized_name ORDER BY id ASC) AS rn
        FROM public.foods
      ),
      loser_winner AS (
        SELECT r_loser.id AS loser_id, r_winner.id AS winner_id
        FROM ranked r_loser
        JOIN ranked r_winner ON r_loser.normalized_name = r_winner.normalized_name AND r_winner.rn = 1
        WHERE r_loser.rn > 1
      )
      UPDATE public.meal_items mi
      SET food_id = lw.winner_id
      FROM loser_winner lw
      WHERE mi.food_id = lw.loser_id;
    END IF;

    WITH ranked AS (
      SELECT id,
             ROW_NUMBER() OVER (PARTITION BY normalized_name ORDER BY id ASC) AS rn
      FROM public.foods
    )
    DELETE FROM public.foods
    WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
  END IF;
END
$$;

-- =============================================================================
-- C) Drop old index, create unique index (guarded)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.foods') IS NOT NULL THEN
    DROP INDEX IF EXISTS public.uq_foods_lower_name;
    DROP INDEX IF EXISTS public.idx_foods_lower_name;
    CREATE UNIQUE INDEX IF NOT EXISTS uq_foods_normalized_name ON public.foods (normalized_name);
  END IF;
END
$$;

-- =============================================================================
-- D) Keep portions partial unique index (guarded)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.food_portions') IS NOT NULL THEN
    CREATE UNIQUE INDEX IF NOT EXISTS uq_food_portions_one_default_per_food
      ON public.food_portions (food_id)
      WHERE is_default = true;
  END IF;
END
$$;

-- =============================================================================
-- E) Guard meal_items alteration (only if both tables exist)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.meal_items') IS NOT NULL AND to_regclass('public.foods') IS NOT NULL THEN
    ALTER TABLE public.meal_items
      ADD COLUMN IF NOT EXISTS food_id uuid REFERENCES public.foods(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_meal_items_food_id ON public.meal_items (food_id) WHERE food_id IS NOT NULL;
  END IF;
END
$$;

-- =============================================================================
-- F) admin_upsert_food: v_normalized matches generated column EXACTLY
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
  -- v_normalized: EXACT match to generated column expression
  -- lower(regexp_replace(trim(name), '\s+', ' ', 'g'))
  v_normalized := lower(regexp_replace(trim(COALESCE(p_name, '')), '\s+', ' ', 'g'));
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
      -- Concurrency: another row with same normalized_name won; re-select id and apply update
      SELECT id INTO v_id
      FROM public.foods
      WHERE normalized_name = v_normalized
      LIMIT 1;
      IF v_id IS NULL THEN
        RAISE;
      END IF;
      -- Apply incoming payload to the winner row
      UPDATE public.foods SET
        name = v_name,
        aliases = p_aliases,
        cuisine = p_cuisine,
        category = p_category,
        is_prepared = COALESCE(p_is_prepared, false),
        source = p_source,
        source_ref = p_source_ref,
        kcal_100g = GREATEST(0, COALESCE(p_kcal_100g, 0)),
        protein_100g = GREATEST(0, COALESCE(p_protein_100g, 0)),
        carbs_100g = GREATEST(0, COALESCE(p_carbs_100g, 0)),
        fat_100g = GREATEST(0, COALESCE(p_fat_100g, 0)),
        fiber_100g = GREATEST(0, COALESCE(p_fiber_100g, 0)),
        micros = p_micros,
        verified = COALESCE(p_verified, false),
        updated_at = now()
      WHERE id = v_id;
  END;

  RETURN v_id;
END;
$$;

ALTER FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_food(uuid, text, text[], text, text, boolean, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, boolean) TO service_role;

-- =============================================================================
-- G) admin_upsert_portion: row locking + 2-step update for default (race-safe)
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

  -- If p_is_default=true: lock rows, then 2-step update to avoid race
  IF COALESCE(p_is_default, false) THEN
    PERFORM 1 FROM public.food_portions WHERE food_id = p_food_id FOR UPDATE;
    UPDATE public.food_portions SET is_default = false
    WHERE food_id = p_food_id AND is_default = true;
    UPDATE public.food_portions SET is_default = true WHERE id = v_id;
  END IF;

  RETURN v_id;
END;
$$;

ALTER FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_portion(uuid, text, numeric, boolean, uuid) TO service_role;

-- =============================================================================
-- H) admin_search_foods: security hardening
-- =============================================================================
ALTER FUNCTION public.admin_search_foods(text, int, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_search_foods(text, int, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_foods(text, int, boolean) TO service_role;

-- =============================================================================
-- VERIFICATION CHECKLIST (run manually after migration)
-- =============================================================================
--
-- a) Duplicates by normalized_name = 0:
--    SELECT normalized_name, count(*) FROM public.foods GROUP BY normalized_name HAVING count(*) > 1;
--
-- b) uq_foods_normalized_name exists:
--    SELECT indexname FROM pg_indexes WHERE tablename = 'foods' AND indexname = 'uq_foods_normalized_name';
--
-- c) No food has >1 default portion (should return 0 rows):
--    SELECT food_id, count(*) FROM public.food_portions WHERE is_default = true GROUP BY food_id HAVING count(*) > 1;
--
-- d) admin_upsert_food called twice updates same row and macros (kcal_100g changes):
--    SELECT admin_upsert_food(p_name := 'Test Food V4', p_kcal_100g := 100);
--    SELECT admin_upsert_food(p_name := 'Test Food V4', p_kcal_100g := 200);
--    SELECT id, name, kcal_100g FROM public.foods WHERE normalized_name = 'test food v4';
--    -- Should return 1 row with kcal_100g = 200
--
-- e) normalized_name generated column definition check:
--    Expected: lower(regexp_replace(trim(name), '\s+', ' ', 'g')) STORED
--    SELECT a.attname, a.attgenerated, pg_get_expr(d.adbin, d.adrelid) AS generation_expr
--    FROM pg_attribute a
--    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
--    WHERE a.attrelid = 'public.foods'::regclass AND a.attname = 'normalized_name' AND NOT a.attisdropped;
--    -- attgenerated = 's', generation_expr matches
--
-- f) Reference integrity: no orphaned references
--    -- food_portions: all food_id must exist in foods
--    SELECT fp.id, fp.food_id FROM public.food_portions fp
--    LEFT JOIN public.foods f ON f.id = fp.food_id WHERE f.id IS NULL;
--    -- Should return 0 rows
--    -- meal_items: all food_id (if non-null) must exist in foods
--    SELECT mi.id, mi.food_id FROM public.meal_items mi
--    LEFT JOIN public.foods f ON f.id = mi.food_id
--    WHERE mi.food_id IS NOT NULL AND f.id IS NULL;
--    -- Should return 0 rows
--
