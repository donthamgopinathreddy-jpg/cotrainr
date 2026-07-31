-- Meal tracker safety: ensure columns, uniqueness, table grants, and foods RLS.
-- Idempotent. Safe to re-run. Does not archive/drop meal tables.

-- =============================================================================
-- 1. Require base tables
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.meals') IS NULL OR to_regclass('public.meal_items') IS NULL THEN
    RAISE EXCEPTION 'Meal tracker requires public.meals and public.meal_items';
  END IF;
END $$;

-- =============================================================================
-- 2. Columns used by the Flutter meal tracker
-- =============================================================================
ALTER TABLE public.meals
  ADD COLUMN IF NOT EXISTS consumed_date date;

ALTER TABLE public.meal_items
  ADD COLUMN IF NOT EXISTS fiber numeric(6,2) NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF to_regclass('public.foods') IS NOT NULL THEN
    ALTER TABLE public.meal_items
      ADD COLUMN IF NOT EXISTS food_id uuid REFERENCES public.foods(id) ON DELETE SET NULL;
  END IF;
END $$;

-- =============================================================================
-- 3. Unique constraint for meal upsert (user_id, consumed_date, meal_type)
-- =============================================================================
ALTER TABLE public.meals
  DROP CONSTRAINT IF EXISTS uq_meals_user_date_meal_type;

DROP INDEX IF EXISTS public.uq_meals_user_date_meal_type;

ALTER TABLE public.meals
  ADD CONSTRAINT uq_meals_user_date_meal_type UNIQUE (user_id, consumed_date, meal_type);

CREATE INDEX IF NOT EXISTS idx_meals_user_consumed_date
  ON public.meals (user_id, consumed_date);

CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id
  ON public.meal_items (meal_id);

-- =============================================================================
-- 4. Table grants (RLS still applies)
-- =============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.meals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.meal_items TO authenticated;
GRANT ALL ON public.meals TO service_role;
GRANT ALL ON public.meal_items TO service_role;

DO $$
BEGIN
  IF to_regclass('public.nutrition_goals') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON public.nutrition_goals TO authenticated';
    EXECUTE 'GRANT ALL ON public.nutrition_goals TO service_role';
  END IF;
END $$;

-- =============================================================================
-- 5. Own-row RLS for meals / meal_items (recreate if missing)
-- =============================================================================
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own meals" ON public.meals;
CREATE POLICY "Users can manage own meals"
  ON public.meals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage own meal items" ON public.meal_items;
CREATE POLICY "Users can manage own meal items"
  ON public.meal_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.meals m
      WHERE m.id = meal_items.meal_id AND m.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.meals m
      WHERE m.id = meal_items.meal_id AND m.user_id = auth.uid()
    )
  );

-- =============================================================================
-- 6. Foods catalog read access (if table exists)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.foods') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.foods TO authenticated';
    EXECUTE 'GRANT ALL ON public.foods TO service_role';
    EXECUTE 'ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Authenticated can select foods" ON public.foods';
    EXECUTE $p$
      CREATE POLICY "Authenticated can select foods"
        ON public.foods FOR SELECT
        TO authenticated
        USING (true)
    $p$;
  END IF;

  IF to_regclass('public.food_portions') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON public.food_portions TO authenticated';
    EXECUTE 'GRANT ALL ON public.food_portions TO service_role';
    EXECUTE 'ALTER TABLE public.food_portions ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Authenticated can select food_portions" ON public.food_portions';
    EXECUTE $p$
      CREATE POLICY "Authenticated can select food_portions"
        ON public.food_portions FOR SELECT
        TO authenticated
        USING (true)
    $p$;
  END IF;
END $$;
