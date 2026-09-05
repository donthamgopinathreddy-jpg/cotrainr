-- PROPOSAL ONLY — DO NOT apply via supabase db push / reset.
-- Apply manually in live SQL editor AFTER inspecting live schema.
--
-- Community Events Wave 1:
--   community_events + event_registrations
--   RLS (read published; self-register; no attendee PII leak)
--   RPC get_home_community_event + register_for_community_event
--   storage bucket event-images (public-read, admin-write)

-- ---------------------------------------------------------------------------
-- 1) Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.community_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  short_description text,
  full_description text,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  location_name text,
  map_url text,
  image_path text,
  registration_enabled boolean NOT NULL DEFAULT true,
  registration_deadline timestamptz,
  max_participants integer,
  is_published boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT community_events_ends_after_starts CHECK (ends_at > starts_at),
  CONSTRAINT community_events_max_participants_positive
    CHECK (max_participants IS NULL OR max_participants > 0)
);

CREATE INDEX IF NOT EXISTS idx_community_events_home
  ON public.community_events (is_published, ends_at, starts_at)
  WHERE is_published = true;

CREATE TABLE IF NOT EXISTS public.event_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.community_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text NOT NULL,
  email text NOT NULL,
  registered_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_registrations_unique_user UNIQUE (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_registrations_event
  ON public.event_registrations (event_id);

CREATE INDEX IF NOT EXISTS idx_event_registrations_user
  ON public.event_registrations (user_id);

-- ---------------------------------------------------------------------------
-- 2) updated_at touch
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tg_community_events_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_community_events_updated_at ON public.community_events;
CREATE TRIGGER trg_community_events_updated_at
  BEFORE UPDATE ON public.community_events
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_community_events_touch_updated_at();

-- ---------------------------------------------------------------------------
-- 3) RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read published community events"
  ON public.community_events;
CREATE POLICY "Authenticated read published community events"
  ON public.community_events
  FOR SELECT
  TO authenticated
  USING (is_published = true);

-- No INSERT/UPDATE/DELETE for authenticated app users on community_events.
-- Retool/service_role bypasses RLS.

DROP POLICY IF EXISTS "Users read own event registrations"
  ON public.event_registrations;
CREATE POLICY "Users read own event registrations"
  ON public.event_registrations
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users insert own event registrations"
  ON public.event_registrations;
CREATE POLICY "Users insert own event registrations"
  ON public.event_registrations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.community_events e
      WHERE e.id = event_id
        AND e.is_published = true
        AND e.registration_enabled = true
        AND e.ends_at > now()
        AND (e.registration_deadline IS NULL OR e.registration_deadline > now())
        AND (
          e.max_participants IS NULL
          OR (
            SELECT count(*)::int
            FROM public.event_registrations r
            WHERE r.event_id = e.id
          ) < e.max_participants
        )
    )
  );

-- No UPDATE/DELETE of registrations for app users (admin/service only).

-- ---------------------------------------------------------------------------
-- 4) Home card RPC — never returns attendee PII
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_home_community_event()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_event public.community_events%ROWTYPE;
  v_count int;
  v_registered boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT *
  INTO v_event
  FROM public.community_events e
  WHERE e.is_published = true
    AND e.ends_at > now()
  ORDER BY e.starts_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT count(*)::int
  INTO v_count
  FROM public.event_registrations r
  WHERE r.event_id = v_event.id;

  SELECT EXISTS (
    SELECT 1
    FROM public.event_registrations r
    WHERE r.event_id = v_event.id
      AND r.user_id = v_uid
  )
  INTO v_registered;

  RETURN jsonb_build_object(
    'event', jsonb_build_object(
      'id', v_event.id,
      'title', v_event.title,
      'short_description', v_event.short_description,
      'full_description', v_event.full_description,
      'starts_at', v_event.starts_at,
      'ends_at', v_event.ends_at,
      'location_name', v_event.location_name,
      'map_url', v_event.map_url,
      'image_path', v_event.image_path,
      'registration_enabled', v_event.registration_enabled,
      'registration_deadline', v_event.registration_deadline,
      'max_participants', v_event.max_participants,
      'is_published', v_event.is_published
    ),
    'attendee_count', v_count,
    'is_registered', v_registered
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_home_community_event() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_home_community_event() TO authenticated;

-- ---------------------------------------------------------------------------
-- 5) Register RPC — authoritative capacity/deadline checks
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_for_community_event(
  p_event_id uuid,
  p_name text,
  p_phone text,
  p_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_event public.community_events%ROWTYPE;
  v_count int;
  v_name text := btrim(coalesce(p_name, ''));
  v_phone text := btrim(coalesce(p_phone, ''));
  v_email text := lower(btrim(coalesce(p_email, '')));
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  IF v_name = '' OR v_phone = '' OR v_email = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'validation');
  END IF;

  IF v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_email');
  END IF;

  SELECT * INTO v_event
  FROM public.community_events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND OR v_event.is_published IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF v_event.ends_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ended');
  END IF;

  IF v_event.registration_enabled IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'error', 'registration_disabled');
  END IF;

  IF v_event.registration_deadline IS NOT NULL
     AND v_event.registration_deadline <= now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'deadline_passed');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.event_registrations
    WHERE event_id = p_event_id AND user_id = v_uid
  ) THEN
    RETURN jsonb_build_object('ok', true, 'already_registered', true);
  END IF;

  SELECT count(*)::int INTO v_count
  FROM public.event_registrations
  WHERE event_id = p_event_id;

  IF v_event.max_participants IS NOT NULL
     AND v_count >= v_event.max_participants THEN
    RETURN jsonb_build_object('ok', false, 'error', 'full');
  END IF;

  INSERT INTO public.event_registrations (event_id, user_id, name, phone, email)
  VALUES (p_event_id, v_uid, v_name, v_phone, v_email);

  RETURN jsonb_build_object(
    'ok', true,
    'already_registered', false,
    'attendee_count', v_count + 1
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', true, 'already_registered', true);
END;
$$;

REVOKE ALL ON FUNCTION public.register_for_community_event(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_for_community_event(uuid, text, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Storage: event-images (public-read for covers; no user uploads)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'event-images',
  'event-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read of cover objects
DROP POLICY IF EXISTS "Public read event images" ON storage.objects;
CREATE POLICY "Public read event images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'event-images');

-- No authenticated INSERT/UPDATE/DELETE — Retool/service_role only.
-- Path convention: events/<event-id>/cover.<ext>
