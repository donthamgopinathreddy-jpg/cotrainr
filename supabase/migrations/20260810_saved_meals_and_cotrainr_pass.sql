-- Saved meals templates + Cotrainr Pass member ID.
-- Recent foods are derived from meal_items (no dedicated table).

-- ========== Saved meals ==========
CREATE TABLE IF NOT EXISTS public.saved_meals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT saved_meals_name_nonempty CHECK (char_length(trim(name)) > 0)
);

CREATE TABLE IF NOT EXISTS public.saved_meal_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  saved_meal_id uuid NOT NULL REFERENCES public.saved_meals(id) ON DELETE CASCADE,
  food_name text NOT NULL,
  quantity numeric(8,2) NOT NULL,
  unit text NOT NULL,
  calories numeric NOT NULL DEFAULT 0,
  protein numeric NOT NULL DEFAULT 0,
  carbs numeric NOT NULL DEFAULT 0,
  fat numeric NOT NULL DEFAULT 0,
  fiber numeric NOT NULL DEFAULT 0,
  food_id uuid REFERENCES public.foods(id) ON DELETE SET NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_saved_meals_user_id ON public.saved_meals(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_meal_items_meal_id ON public.saved_meal_items(saved_meal_id);

ALTER TABLE public.saved_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_meal_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own saved meals" ON public.saved_meals;
CREATE POLICY "Users manage own saved meals"
ON public.saved_meals FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own saved meal items" ON public.saved_meal_items;
CREATE POLICY "Users manage own saved meal items"
ON public.saved_meal_items FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.saved_meals sm
    WHERE sm.id = saved_meal_id AND sm.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.saved_meals sm
    WHERE sm.id = saved_meal_id AND sm.user_id = auth.uid()
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_meals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_meal_items TO authenticated;

-- ========== Cotrainr Pass ID ==========
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cotrainr_pass_id text,
  ADD COLUMN IF NOT EXISTS cotrainr_pass_created_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_cotrainr_pass_id_unique
  ON public.profiles (cotrainr_pass_id)
  WHERE cotrainr_pass_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.get_or_create_cotrainr_pass()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_existing text;
  v_candidate text;
  v_digits text;
  v_attempts int := 0;
  v_num bigint;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT cotrainr_pass_id INTO v_existing
  FROM public.profiles
  WHERE id = v_uid;

  IF v_existing IS NOT NULL AND v_existing ~ '^CT[0-9]{8}$' THEN
    RETURN v_existing;
  END IF;

  LOOP
    v_attempts := v_attempts + 1;
    IF v_attempts > 40 THEN
      RAISE EXCEPTION 'pass_id_generation_failed';
    END IF;

    -- Non-sequential 8-digit space derived from UUID entropy (not PII / not auth id).
    v_num := (('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint);
    v_num := abs(v_num) % 100000000;
    v_digits := lpad(v_num::text, 8, '0');
    v_candidate := 'CT' || v_digits;

    BEGIN
      UPDATE public.profiles
      SET
        cotrainr_pass_id = v_candidate,
        cotrainr_pass_created_at = coalesce(cotrainr_pass_created_at, now()),
        updated_at = now()
      WHERE id = v_uid
        AND (cotrainr_pass_id IS NULL OR cotrainr_pass_id !~ '^CT[0-9]{8}$');

      IF FOUND THEN
        RETURN v_candidate;
      END IF;

      SELECT cotrainr_pass_id INTO v_existing
      FROM public.profiles
      WHERE id = v_uid;

      IF v_existing IS NOT NULL AND v_existing ~ '^CT[0-9]{8}$' THEN
        RETURN v_existing;
      END IF;
    EXCEPTION WHEN unique_violation THEN
      -- retry on collision
      NULL;
    END;
  END LOOP;
END;
$$;

ALTER FUNCTION public.get_or_create_cotrainr_pass() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_or_create_cotrainr_pass() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_cotrainr_pass() TO authenticated;

-- Prevent client UPDATE from changing / clearing an assigned Pass ID.
CREATE OR REPLACE FUNCTION public.protect_cotrainr_pass_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.cotrainr_pass_id IS NOT NULL
     AND OLD.cotrainr_pass_id ~ '^CT[0-9]{8}$'
     AND NEW.cotrainr_pass_id IS DISTINCT FROM OLD.cotrainr_pass_id THEN
    RAISE EXCEPTION 'cotrainr_pass_id is immutable';
  END IF;
  IF OLD.cotrainr_pass_created_at IS NOT NULL
     AND NEW.cotrainr_pass_created_at IS DISTINCT FROM OLD.cotrainr_pass_created_at THEN
    NEW.cotrainr_pass_created_at := OLD.cotrainr_pass_created_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_cotrainr_pass_id ON public.profiles;
CREATE TRIGGER trg_protect_cotrainr_pass_id
  BEFORE UPDATE OF cotrainr_pass_id, cotrainr_pass_created_at ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_cotrainr_pass_id();

-- Pass ID is not included in get_public_profile / search RPCs (explicit column lists).
-- Own profile: get_my_profile() returns SELECT * so the column is available to the owner.
-- Preferred client path: get_or_create_cotrainr_pass() RPC.
