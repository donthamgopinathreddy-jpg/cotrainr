-- Partner centre applications + approved partner centres.
-- Preserves existing cotrainr_pass_id on profiles (no Pass ID changes).
-- Idempotent.

-- ========== Applications (intake) ==========
CREATE TABLE IF NOT EXISTS public.partner_center_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_code text NOT NULL,
  submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  center_id uuid NULL,
  google_place_id text NULL,

  business_name text NOT NULL,
  business_type text NOT NULL,

  contact_name text NOT NULL,
  contact_role text NOT NULL,
  business_email text NOT NULL,
  business_phone text NOT NULL,
  website text NULL,

  address_line_1 text NOT NULL,
  address_line_2 text NULL,
  city text NOT NULL,
  postal_code text NOT NULL,
  country text NOT NULL,

  approx_member_count text NULL,
  facilities jsonb NOT NULL DEFAULT '[]'::jsonb,
  description text NULL,
  partnership_interests jsonb NOT NULL DEFAULT '[]'::jsonb,

  proposed_offer_title text NULL,
  proposed_offer_description text NULL,

  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending',
      'under_review',
      'needs_information',
      'approved',
      'rejected',
      'withdrawn'
    )),

  review_notes text NULL,
  reviewed_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz NULL,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT partner_apps_name_nonempty CHECK (char_length(trim(business_name)) > 0),
  CONSTRAINT partner_apps_code_format CHECK (application_code ~ '^CP-[A-Z0-9]{8}$')
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_apps_code_unique
  ON public.partner_center_applications (application_code);

CREATE INDEX IF NOT EXISTS idx_partner_apps_submitted_by
  ON public.partner_center_applications (submitted_by);

CREATE INDEX IF NOT EXISTS idx_partner_apps_status
  ON public.partner_center_applications (status);

CREATE INDEX IF NOT EXISTS idx_partner_apps_created_at
  ON public.partner_center_applications (created_at DESC);

-- ========== Approved partner centres (permanent directory) ==========
CREATE TABLE IF NOT EXISTS public.partner_centers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NULL REFERENCES public.partner_center_applications(id) ON DELETE SET NULL,
  google_place_id text NULL,

  name text NOT NULL,
  business_type text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paused', 'archived')),

  address_line_1 text NOT NULL,
  address_line_2 text NULL,
  city text NOT NULL,
  postal_code text NOT NULL,
  country text NOT NULL,
  latitude double precision NULL,
  longitude double precision NULL,

  facilities jsonb NOT NULL DEFAULT '[]'::jsonb,
  description text NULL,
  website text NULL,
  phone text NULL,
  logo_url text NULL,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- One Discover card per Google Place when present.
CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_centers_google_place_unique
  ON public.partner_centers (google_place_id)
  WHERE google_place_id IS NOT NULL AND length(trim(google_place_id)) > 0;

CREATE INDEX IF NOT EXISTS idx_partner_centers_status
  ON public.partner_centers (status);

CREATE INDEX IF NOT EXISTS idx_partner_centers_city
  ON public.partner_centers (city);

-- Link applications.center_id → partner_centers after approve.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'partner_apps_center_fk'
  ) THEN
    ALTER TABLE public.partner_center_applications
      ADD CONSTRAINT partner_apps_center_fk
      FOREIGN KEY (center_id) REFERENCES public.partner_centers(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Optional active offer snapshot for Discover (approved/published only).
CREATE TABLE IF NOT EXISTS public.partner_center_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id uuid NOT NULL REFERENCES public.partner_centers(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'pending_review', 'active', 'paused', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partner_offers_center
  ON public.partner_center_offers (center_id);

CREATE INDEX IF NOT EXISTS idx_partner_offers_active
  ON public.partner_center_offers (center_id)
  WHERE status = 'active';

-- ========== RLS ==========
ALTER TABLE public.partner_center_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_center_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users insert own partner applications" ON public.partner_center_applications;
CREATE POLICY "Users insert own partner applications"
ON public.partner_center_applications FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = submitted_by
  AND status = 'pending'
);

DROP POLICY IF EXISTS "Users read own partner applications" ON public.partner_center_applications;
CREATE POLICY "Users read own partner applications"
ON public.partner_center_applications FOR SELECT TO authenticated
USING (auth.uid() = submitted_by);

-- Users may withdraw only; cannot self-approve.
DROP POLICY IF EXISTS "Users withdraw own partner applications" ON public.partner_center_applications;
CREATE POLICY "Users withdraw own partner applications"
ON public.partner_center_applications FOR UPDATE TO authenticated
USING (auth.uid() = submitted_by)
WITH CHECK (
  auth.uid() = submitted_by
  AND status = 'withdrawn'
);

DROP POLICY IF EXISTS "Anyone authenticated read active partner centres" ON public.partner_centers;
CREATE POLICY "Anyone authenticated read active partner centres"
ON public.partner_centers FOR SELECT TO authenticated
USING (status = 'active');

DROP POLICY IF EXISTS "Anyone authenticated read active partner offers" ON public.partner_center_offers;
CREATE POLICY "Anyone authenticated read active partner offers"
ON public.partner_center_offers FOR SELECT TO authenticated
USING (status = 'active');

GRANT SELECT, INSERT, UPDATE ON public.partner_center_applications TO authenticated;
GRANT SELECT ON public.partner_centers TO authenticated;
GRANT SELECT ON public.partner_center_offers TO authenticated;
GRANT ALL ON public.partner_center_applications TO service_role;
GRANT ALL ON public.partner_centers TO service_role;
GRANT ALL ON public.partner_center_offers TO service_role;

-- Block client status escalation (defense in depth beyond RLS WITH CHECK).
CREATE OR REPLACE FUNCTION public.protect_partner_application_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.status IS DISTINCT FROM NEW.status
     AND auth.uid() IS NOT NULL
     AND auth.uid() = NEW.submitted_by
     AND NEW.status IS DISTINCT FROM 'withdrawn' THEN
    RAISE EXCEPTION 'clients cannot change partner application status to %', NEW.status;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.status = 'approved'
     AND NEW.status IS DISTINCT FROM OLD.status
     AND auth.uid() IS NOT NULL
     AND auth.role() = 'authenticated' THEN
    -- Only service_role / SECURITY DEFINER admin RPCs should change approved rows.
    IF current_setting('request.jwt.claim.role', true) = 'authenticated' THEN
      RAISE EXCEPTION 'approved partner applications are immutable for clients';
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_partner_application_status ON public.partner_center_applications;
CREATE TRIGGER trg_protect_partner_application_status
  BEFORE UPDATE ON public.partner_center_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_partner_application_status();

-- ========== Client submit RPC (generates CP-XXXXXXXX) ==========
CREATE OR REPLACE FUNCTION public.submit_partner_center_application(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_code text;
  v_id uuid;
  v_open int;
  v_digits text;
  v_attempts int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT count(*) INTO v_open
  FROM public.partner_center_applications
  WHERE submitted_by = v_uid
    AND status IN ('pending', 'under_review', 'needs_information');

  IF v_open > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'duplicate_open_application',
      'detail', 'You already have a partner application in review.'
    );
  END IF;

  IF coalesce(trim(p_payload->>'business_name'), '') = ''
     OR coalesce(trim(p_payload->>'business_type'), '') = ''
     OR coalesce(trim(p_payload->>'contact_name'), '') = ''
     OR coalesce(trim(p_payload->>'contact_role'), '') = ''
     OR coalesce(trim(p_payload->>'business_email'), '') = ''
     OR coalesce(trim(p_payload->>'business_phone'), '') = ''
     OR coalesce(trim(p_payload->>'address_line_1'), '') = ''
     OR coalesce(trim(p_payload->>'city'), '') = ''
     OR coalesce(trim(p_payload->>'postal_code'), '') = ''
     OR coalesce(trim(p_payload->>'country'), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'validation_failed');
  END IF;

  IF (p_payload->>'business_email') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_email');
  END IF;

  LOOP
    v_attempts := v_attempts + 1;
    IF v_attempts > 20 THEN
      RAISE EXCEPTION 'application_code_generation_failed';
    END IF;
    v_digits := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    v_code := 'CP-' || v_digits;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.partner_center_applications WHERE application_code = v_code
    );
  END LOOP;

  INSERT INTO public.partner_center_applications (
    application_code,
    submitted_by,
    google_place_id,
    business_name,
    business_type,
    contact_name,
    contact_role,
    business_email,
    business_phone,
    website,
    address_line_1,
    address_line_2,
    city,
    postal_code,
    country,
    approx_member_count,
    facilities,
    description,
    partnership_interests,
    proposed_offer_title,
    proposed_offer_description,
    status
  ) VALUES (
    v_code,
    v_uid,
    nullif(trim(p_payload->>'google_place_id'), ''),
    trim(p_payload->>'business_name'),
    trim(p_payload->>'business_type'),
    trim(p_payload->>'contact_name'),
    trim(p_payload->>'contact_role'),
    lower(trim(p_payload->>'business_email')),
    trim(p_payload->>'business_phone'),
    nullif(trim(p_payload->>'website'), ''),
    trim(p_payload->>'address_line_1'),
    nullif(trim(p_payload->>'address_line_2'), ''),
    trim(p_payload->>'city'),
    trim(p_payload->>'postal_code'),
    trim(p_payload->>'country'),
    nullif(trim(p_payload->>'approx_member_count'), ''),
    coalesce(p_payload->'facilities', '[]'::jsonb),
    nullif(trim(p_payload->>'description'), ''),
    coalesce(p_payload->'partnership_interests', '[]'::jsonb),
    nullif(trim(p_payload->>'proposed_offer_title'), ''),
    nullif(trim(p_payload->>'proposed_offer_description'), ''),
    'pending'
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'application_code', v_code,
    'status', 'pending'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_partner_center_application(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_partner_center_application(jsonb) TO authenticated;
ALTER FUNCTION public.submit_partner_center_application(jsonb) OWNER TO postgres;

-- ========== Discover: list active partner centres (+ optional offer) ==========
CREATE OR REPLACE FUNCTION public.list_partner_centers_for_discover()
RETURNS TABLE (
  id uuid,
  name text,
  business_type text,
  city text,
  country text,
  address_line_1 text,
  google_place_id text,
  latitude double precision,
  longitude double precision,
  facilities jsonb,
  description text,
  logo_url text,
  offer_title text,
  offer_description text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    c.id,
    c.name,
    c.business_type,
    c.city,
    c.country,
    c.address_line_1,
    c.google_place_id,
    c.latitude,
    c.longitude,
    c.facilities,
    c.description,
    c.logo_url,
    o.title AS offer_title,
    o.description AS offer_description
  FROM public.partner_centers c
  LEFT JOIN LATERAL (
    SELECT title, description
    FROM public.partner_center_offers po
    WHERE po.center_id = c.id AND po.status = 'active'
    ORDER BY po.updated_at DESC
    LIMIT 1
  ) o ON true
  WHERE c.status = 'active'
  ORDER BY c.name;
$$;

REVOKE ALL ON FUNCTION public.list_partner_centers_for_discover() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_partner_centers_for_discover() TO authenticated;
ALTER FUNCTION public.list_partner_centers_for_discover() OWNER TO postgres;

-- ========== Retool admin RPCs (service_role) ==========
CREATE OR REPLACE FUNCTION public.admin_list_partner_applications(
  p_status text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  application_code text,
  business_name text,
  business_type text,
  city text,
  contact_name text,
  business_email text,
  status text,
  created_at timestamptz,
  submitted_by uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.application_code,
    a.business_name,
    a.business_type,
    a.city,
    a.contact_name,
    a.business_email,
    a.status,
    a.created_at,
    a.submitted_by
  FROM public.partner_center_applications a
  WHERE p_status IS NULL OR a.status = p_status
  ORDER BY a.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_partner_applications(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_partner_applications(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_partner_applications(text) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_get_partner_application(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.partner_center_applications%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.partner_center_applications WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;
  RETURN jsonb_build_object('ok', true, 'application', to_jsonb(v_row));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_partner_application(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_partner_application(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_partner_application(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_update_partner_application_status(
  p_actor_id uuid,
  p_application_id uuid,
  p_status text,
  p_review_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_app public.partner_center_applications%ROWTYPE;
  v_center_id uuid;
  v_offer_id uuid;
BEGIN
  IF p_actor_id IS NULL OR NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_actor_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'invalid_actor',
      'detail', 'Use admin_resolve_actor_id from Retool email'
    );
  END IF;

  IF p_status NOT IN ('pending', 'under_review', 'needs_information', 'approved', 'rejected', 'withdrawn') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_status');
  END IF;

  SELECT * INTO v_app FROM public.partner_center_applications WHERE id = p_application_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  UPDATE public.partner_center_applications
  SET
    status = p_status,
    review_notes = coalesce(p_review_notes, review_notes),
    reviewed_by = p_actor_id,
    reviewed_at = now(),
    updated_at = now()
  WHERE id = p_application_id;

  -- On approve: create/link permanent partner_centers row (never use application as centre).
  IF p_status = 'approved' THEN
    IF v_app.center_id IS NOT NULL THEN
      v_center_id := v_app.center_id;
      UPDATE public.partner_centers SET
        name = v_app.business_name,
        business_type = v_app.business_type,
        google_place_id = v_app.google_place_id,
        address_line_1 = v_app.address_line_1,
        address_line_2 = v_app.address_line_2,
        city = v_app.city,
        postal_code = v_app.postal_code,
        country = v_app.country,
        facilities = v_app.facilities,
        description = v_app.description,
        website = v_app.website,
        phone = v_app.business_phone,
        status = 'active',
        updated_at = now()
      WHERE id = v_center_id;
    ELSIF v_app.google_place_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.partner_centers pc
      WHERE pc.google_place_id = v_app.google_place_id
    ) THEN
      -- Merge onto existing centre with same Google Place ID.
      SELECT id INTO v_center_id
      FROM public.partner_centers
      WHERE google_place_id = v_app.google_place_id
      LIMIT 1;

      UPDATE public.partner_centers SET
        name = v_app.business_name,
        business_type = v_app.business_type,
        address_line_1 = v_app.address_line_1,
        address_line_2 = v_app.address_line_2,
        city = v_app.city,
        postal_code = v_app.postal_code,
        country = v_app.country,
        facilities = v_app.facilities,
        description = v_app.description,
        website = v_app.website,
        phone = v_app.business_phone,
        application_id = p_application_id,
        status = 'active',
        updated_at = now()
      WHERE id = v_center_id;
    ELSE
      INSERT INTO public.partner_centers (
        application_id,
        google_place_id,
        name,
        business_type,
        status,
        address_line_1,
        address_line_2,
        city,
        postal_code,
        country,
        facilities,
        description,
        website,
        phone
      ) VALUES (
        p_application_id,
        v_app.google_place_id,
        v_app.business_name,
        v_app.business_type,
        'active',
        v_app.address_line_1,
        v_app.address_line_2,
        v_app.city,
        v_app.postal_code,
        v_app.country,
        v_app.facilities,
        v_app.description,
        v_app.website,
        v_app.business_phone
      )
      RETURNING id INTO v_center_id;
    END IF;

    UPDATE public.partner_center_applications
    SET center_id = v_center_id
    WHERE id = p_application_id;

    IF v_app.proposed_offer_title IS NOT NULL AND length(trim(v_app.proposed_offer_title)) > 0 THEN
      INSERT INTO public.partner_center_offers (
        center_id, title, description, status
      ) VALUES (
        v_center_id,
        trim(v_app.proposed_offer_title),
        v_app.proposed_offer_description,
        'pending_review'
      )
      RETURNING id INTO v_offer_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', p_status,
    'center_id', v_center_id,
    'offer_id', v_offer_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_partner_application_status(uuid, uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_partner_application_status(uuid, uuid, text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_partner_application_status(uuid, uuid, text, text) TO service_role;
ALTER FUNCTION public.admin_update_partner_application_status(uuid, uuid, text, text) OWNER TO postgres;
