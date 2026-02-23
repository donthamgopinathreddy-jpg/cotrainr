-- =============================================================================
-- FOOD CATALOG: Portion dedupe (additive patch)
-- Run after 20250220_food_catalog_hardening_v4_1.sql
-- Fixes: Prevent duplicate portions on re-seed via unique constraint + upsert-by-label
--
-- REQUIREMENT: Seed scripts MUST use admin_upsert_portion RPC only — no direct
-- INSERT into food_portions. The unique index uq_food_portions_food_label_norm
-- will reject duplicate (food_id, label_norm); admin_upsert_portion handles
-- upsert-by-label. Confirmed: scripts/seed_food_catalog.js uses rpc only.
-- =============================================================================

-- =============================================================================
-- 1) Dedupe existing portions before adding unique index (keep one per food_id, label_norm)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.food_portions') IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.food_portions
  WHERE id IN (
    SELECT id FROM (
      SELECT id,
             ROW_NUMBER() OVER (
               PARTITION BY food_id, lower(regexp_replace(trim(label), '\s+', ' ', 'g'))
               ORDER BY is_default DESC, id ASC
             ) AS rn
      FROM public.food_portions
    ) sub
    WHERE rn > 1
  );
END
$$;

-- =============================================================================
-- 1b) Post-dedupe cleanup: ensure only one default portion per food
--     (dedupe by label_norm does not guarantee one default across labels)
--     Deterministic: keep most recent default (created_at DESC), else smallest id
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.food_portions') IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.food_portions fp
  SET is_default = false
  WHERE fp.is_default = true
    AND fp.id NOT IN (
      SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY food_id
                 ORDER BY created_at DESC NULLS LAST, id ASC
               ) AS rn
        FROM public.food_portions
        WHERE is_default = true
      ) sub
      WHERE rn = 1
    );
END
$$;

-- =============================================================================
-- 2) Unique index: one portion per (food_id, normalized label)
-- =============================================================================
DO $$
BEGIN
  IF to_regclass('public.food_portions') IS NOT NULL THEN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_food_portions_food_label_norm ON public.food_portions (food_id, lower(regexp_replace(trim(label), ''\s+'', '' '', ''g'')))';
  END IF;
END
$$;

-- =============================================================================
-- 3) admin_upsert_portion: upsert by (food_id, label) to prevent re-seed duplicates
-- Required params first, optional last (Postgres 42P13 compliance)
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
  v_label_norm text;
BEGIN
  IF p_food_id IS NULL OR p_label IS NULL OR trim(p_label) = '' OR p_grams IS NULL OR p_grams <= 0 THEN
    RAISE EXCEPTION 'food_id, label, and grams > 0 are required';
  END IF;

  v_label_norm := lower(regexp_replace(trim(p_label), '\s+', ' ', 'g'));

  SELECT id INTO v_id
  FROM public.food_portions
  WHERE food_id = p_food_id
    AND lower(regexp_replace(trim(label), '\s+', ' ', 'g')) = v_label_norm
  LIMIT 1;

  v_id := COALESCE(v_id, p_id, gen_random_uuid());

  BEGIN
    INSERT INTO public.food_portions (id, food_id, label, grams, is_default)
    VALUES (v_id, p_food_id, regexp_replace(trim(p_label), '\s+', ' ', 'g'), p_grams, false)
    ON CONFLICT (id) DO UPDATE SET
      food_id = EXCLUDED.food_id,
      label = EXCLUDED.label,
      grams = EXCLUDED.grams,
      is_default = false;
  EXCEPTION
    WHEN unique_violation THEN
      SELECT id INTO v_id FROM public.food_portions
      WHERE food_id = p_food_id
        AND lower(regexp_replace(trim(label), '\s+', ' ', 'g')) = v_label_norm
      LIMIT 1;
      IF v_id IS NULL THEN RAISE; END IF;
      UPDATE public.food_portions SET
        grams = p_grams,
        label = regexp_replace(trim(p_label), '\s+', ' ', 'g')
      WHERE id = v_id;
  END;

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
-- VERIFICATION: Duplicate portions (should return 0 rows after migration)
-- =============================================================================
--
-- SELECT food_id, lower(regexp_replace(trim(label), '\s+', ' ', 'g')) AS label_norm, count(*)
-- FROM public.food_portions
-- GROUP BY food_id, lower(regexp_replace(trim(label), '\s+', ' ', 'g'))
-- HAVING count(*) > 1;
--
