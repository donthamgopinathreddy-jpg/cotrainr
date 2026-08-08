-- Chat user safety: reports, blocks, account moderation (Retool-compatible).
-- Extends admin_audit_log; does not modify historical migrations.
-- Paste-safe: prefer single-line DDL where indentation caused prior editor issues.

-- ---------------------------------------------------------------------------
-- 1) Profile moderation fields (separate from provider verification)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS suspended_until timestamptz,
  ADD COLUMN IF NOT EXISTS moderation_reason text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_account_status_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_account_status_check
      CHECK (account_status IN ('active', 'suspended', 'banned'));
  END IF;
END $$;

COMMENT ON COLUMN public.profiles.account_status IS
  'User moderation status: active | suspended | banned (not provider verification)';
COMMENT ON COLUMN public.profiles.suspended_until IS
  'When set and in the future with status=suspended, access restricted until this time';

-- ---------------------------------------------------------------------------
-- 2) User blocks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_blocks_no_self CHECK (blocker_user_id <> blocked_user_id),
  CONSTRAINT user_blocks_unique_pair UNIQUE (blocker_user_id, blocked_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks (blocker_user_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks (blocked_user_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own blocks" ON public.user_blocks;
CREATE POLICY "Users can view own blocks" ON public.user_blocks FOR SELECT
  USING (auth.uid() = blocker_user_id);

DROP POLICY IF EXISTS "Users can create own blocks" ON public.user_blocks;
CREATE POLICY "Users can create own blocks" ON public.user_blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_user_id AND blocker_user_id <> blocked_user_id);

DROP POLICY IF EXISTS "Users can delete own blocks" ON public.user_blocks;
CREATE POLICY "Users can delete own blocks" ON public.user_blocks FOR DELETE
  USING (auth.uid() = blocker_user_id);

-- ---------------------------------------------------------------------------
-- 3) User reports (chat / peer reports — separate from post_reports)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE SET NULL,
  reason text NOT NULL,
  details text,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  moderation_notes text,
  resolution text,
  CONSTRAINT user_reports_no_self CHECK (reporter_user_id <> reported_user_id),
  CONSTRAINT user_reports_reason_check CHECK (reason IN (
    'harassment',
    'inappropriate_content',
    'spam',
    'fraud',
    'sexual_content',
    'hate_abuse',
    'impersonation',
    'unsafe_coaching',
    'other'
  )),
  CONSTRAINT user_reports_status_check CHECK (status IN (
    'pending',
    'under_review',
    'resolved',
    'dismissed'
  )),
  CONSTRAINT user_reports_details_len CHECK (details IS NULL OR char_length(details) <= 500)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_status_created
  ON public.user_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported
  ON public.user_reports (reported_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_reports_reporter
  ON public.user_reports (reporter_user_id, created_at DESC);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Reporters may INSERT only (reporter forced by RPC). No SELECT for normal users.
DROP POLICY IF EXISTS "Users cannot select user reports" ON public.user_reports;
-- No authenticated SELECT policy on purpose.

DROP POLICY IF EXISTS "Service role manages user reports" ON public.user_reports;
CREATE POLICY "Service role manages user reports" ON public.user_reports FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 4) Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.users_are_blocked(p_a uuid, p_b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_user_id = p_a AND blocked_user_id = p_b)
       OR (blocker_user_id = p_b AND blocked_user_id = p_a)
  );
$$;

REVOKE ALL ON FUNCTION public.users_are_blocked(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.users_are_blocked(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.users_are_blocked(uuid, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.effective_account_status(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
  v_until timestamptz;
BEGIN
  SELECT account_status, suspended_until
  INTO v_status, v_until
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_status IS NULL THEN
    RETURN 'active';
  END IF;

  IF v_status = 'banned' THEN
    RETURN 'banned';
  END IF;

  IF v_status = 'suspended' THEN
    IF v_until IS NOT NULL AND v_until <= now() THEN
      RETURN 'active';
    END IF;
    RETURN 'suspended';
  END IF;

  RETURN 'active';
END;
$$;

REVOKE ALL ON FUNCTION public.effective_account_status(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.effective_account_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.effective_account_status(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.account_may_use_messaging(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.effective_account_status(p_user_id) = 'active';
$$;

REVOKE ALL ON FUNCTION public.account_may_use_messaging(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.account_may_use_messaging(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.account_may_use_messaging(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 5) Authenticated RPCs: report / block / unblock / state
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_user_report(
  p_reported_user_id uuid,
  p_reason text,
  p_details text DEFAULT NULL,
  p_conversation_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reporter uuid := auth.uid();
  v_details text;
  v_id uuid;
BEGIN
  IF v_reporter IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;
  IF p_reported_user_id IS NULL OR p_reported_user_id = v_reporter THEN
    RETURN jsonb_build_object('error', 'Invalid reported user');
  END IF;
  IF p_reason IS NULL OR p_reason NOT IN (
    'harassment','inappropriate_content','spam','fraud','sexual_content',
    'hate_abuse','impersonation','unsafe_coaching','other'
  ) THEN
    RETURN jsonb_build_object('error', 'Invalid reason');
  END IF;

  v_details := nullif(trim(coalesce(p_details, '')), '');
  IF v_details IS NOT NULL AND char_length(v_details) > 500 THEN
    RETURN jsonb_build_object('error', 'Details too long');
  END IF;
  IF p_reason = 'other' AND v_details IS NULL THEN
    RETURN jsonb_build_object('error', 'Details required for Other');
  END IF;

  IF p_conversation_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = p_conversation_id
      AND (c.client_id = v_reporter OR c.provider_id = v_reporter OR c.other_user_id = v_reporter)
  ) THEN
    RETURN jsonb_build_object('error', 'Invalid conversation');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_reported_user_id) THEN
    RETURN jsonb_build_object('error', 'User not found');
  END IF;

  INSERT INTO public.user_reports (
    reporter_user_id, reported_user_id, conversation_id, reason, details, status
  ) VALUES (
    v_reporter, p_reported_user_id, p_conversation_id, p_reason, v_details, 'pending'
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'report_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_user_report(uuid, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_user_report(uuid, text, text, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.block_user_tx(p_blocked_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocker uuid := auth.uid();
BEGIN
  IF v_blocker IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;
  IF p_blocked_user_id IS NULL OR p_blocked_user_id = v_blocker THEN
    RETURN jsonb_build_object('error', 'Invalid user');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_blocked_user_id) THEN
    RETURN jsonb_build_object('error', 'User not found');
  END IF;

  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
  VALUES (v_blocker, p_blocked_user_id)
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'blocked', true);
END;
$$;

REVOKE ALL ON FUNCTION public.block_user_tx(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.block_user_tx(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.unblock_user_tx(p_blocked_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocker uuid := auth.uid();
BEGIN
  IF v_blocker IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  DELETE FROM public.user_blocks
  WHERE blocker_user_id = v_blocker
    AND blocked_user_id = p_blocked_user_id;

  RETURN jsonb_build_object('ok', true, 'blocked', false);
END;
$$;

REVOKE ALL ON FUNCTION public.unblock_user_tx(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.unblock_user_tx(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_block_state(p_other_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_i_blocked boolean;
  v_they_blocked boolean;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE blocker_user_id = v_me AND blocked_user_id = p_other_user_id
  ) INTO v_i_blocked;
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE blocker_user_id = p_other_user_id AND blocked_user_id = v_me
  ) INTO v_they_blocked;

  RETURN jsonb_build_object(
    'i_blocked', v_i_blocked,
    'they_blocked', v_they_blocked,
    'either_blocked', (v_i_blocked OR v_they_blocked)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_block_state(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_block_state(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Harden message INSERT against blocks + suspended/banned accounts
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can send messages" ON public.messages;
CREATE POLICY "Participants can send messages" ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND public.account_may_use_messaging(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (
          c.client_id = auth.uid()
          OR c.provider_id = auth.uid()
          OR c.other_user_id = auth.uid()
        )
        AND NOT public.users_are_blocked(
          auth.uid(),
          CASE
            WHEN c.client_id = auth.uid() THEN coalesce(c.provider_id, c.other_user_id)
            WHEN c.provider_id = auth.uid() THEN coalesce(c.client_id, c.other_user_id)
            ELSE coalesce(c.client_id, c.provider_id)
          END
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 7) Admin / Retool RPCs (service_role + admin_validate_actor)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_user_reports(
  p_actor_id uuid,
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  reporter_user_id uuid,
  reported_user_id uuid,
  conversation_id uuid,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid,
  moderation_notes text,
  resolution text,
  reported_role text,
  reported_account_status text,
  previous_report_count bigint,
  reporter_blocked_reported boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RAISE EXCEPTION 'Unauthorized admin actor';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.reporter_user_id,
    r.reported_user_id,
    r.conversation_id,
    r.reason,
    r.details,
    r.status,
    r.created_at,
    r.reviewed_at,
    r.reviewed_by,
    r.moderation_notes,
    r.resolution,
    p.role::text,
    public.effective_account_status(r.reported_user_id),
    (
      SELECT count(*)::bigint FROM public.user_reports x
      WHERE x.reported_user_id = r.reported_user_id AND x.id <> r.id
    ),
    EXISTS (
      SELECT 1 FROM public.user_blocks b
      WHERE b.blocker_user_id = r.reporter_user_id
        AND b.blocked_user_id = r.reported_user_id
    )
  FROM public.user_reports r
  LEFT JOIN public.profiles p ON p.id = r.reported_user_id
  WHERE (p_status IS NULL OR r.status = p_status)
  ORDER BY r.created_at DESC
  LIMIT least(greatest(coalesce(p_limit, 100), 1), 500);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_user_reports(uuid, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_user_reports(uuid, text, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_user_reports(uuid, text, integer) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_update_user_report(
  p_actor_id uuid,
  p_report_id uuid,
  p_status text,
  p_moderation_notes text DEFAULT NULL,
  p_resolution text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;
  IF p_status NOT IN ('pending', 'under_review', 'resolved', 'dismissed') THEN
    RETURN jsonb_build_object('error', 'Invalid status');
  END IF;

  SELECT status INTO v_prev FROM public.user_reports WHERE id = p_report_id;
  IF v_prev IS NULL THEN
    RETURN jsonb_build_object('error', 'Report not found');
  END IF;

  UPDATE public.user_reports SET
    status = p_status,
    moderation_notes = coalesce(p_moderation_notes, moderation_notes),
    resolution = coalesce(p_resolution, resolution),
    reviewed_at = now(),
    reviewed_by = p_actor_id
  WHERE id = p_report_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES (
    CASE p_status
      WHEN 'under_review' THEN 'REPORT_UNDER_REVIEW'
      WHEN 'dismissed' THEN 'REPORT_DISMISSED'
      WHEN 'resolved' THEN 'REPORT_RESOLVED'
      ELSE 'REPORT_STATUS_UPDATE'
    END,
    p_actor_id,
    'user_report',
    p_report_id,
    jsonb_build_object('previous_status', v_prev, 'new_status', p_status)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_user_report(uuid, uuid, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_user_report(uuid, uuid, text, text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_report(uuid, uuid, text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_warn_user(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_reason text,
  p_report_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES (
    'WARN',
    p_actor_id,
    'user',
    p_target_user_id,
    jsonb_build_object('reason', p_reason, 'report_id', p_report_id)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_warn_user(uuid, uuid, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_warn_user(uuid, uuid, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_warn_user(uuid, uuid, text, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_suspend_user(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_reason text,
  p_duration text DEFAULT '7d',
  p_report_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev text;
  v_until timestamptz;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  SELECT account_status INTO v_prev FROM public.profiles WHERE id = p_target_user_id;
  IF v_prev IS NULL THEN
    RETURN jsonb_build_object('error', 'User not found');
  END IF;

  v_until := CASE p_duration
    WHEN '24h' THEN now() + interval '24 hours'
    WHEN '7d' THEN now() + interval '7 days'
    WHEN '30d' THEN now() + interval '30 days'
    WHEN 'indefinite' THEN NULL
    ELSE now() + interval '7 days'
  END;

  UPDATE public.profiles SET
    account_status = 'suspended',
    suspended_until = v_until,
    moderation_reason = p_reason
  WHERE id = p_target_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES (
    'SUSPEND',
    p_actor_id,
    'user',
    p_target_user_id,
    jsonb_build_object(
      'reason', p_reason,
      'duration', p_duration,
      'suspended_until', v_until,
      'previous_status', v_prev,
      'new_status', 'suspended',
      'report_id', p_report_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'suspended_until', v_until);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_suspend_user(uuid, uuid, text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_suspend_user(uuid, uuid, text, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_suspend_user(uuid, uuid, text, text, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_unsuspend_user(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  SELECT account_status INTO v_prev FROM public.profiles WHERE id = p_target_user_id;
  UPDATE public.profiles SET
    account_status = 'active',
    suspended_until = NULL,
    moderation_reason = NULL
  WHERE id = p_target_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES (
    'UNSUSPEND',
    p_actor_id,
    'user',
    p_target_user_id,
    jsonb_build_object('reason', p_reason, 'previous_status', v_prev, 'new_status', 'active')
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_unsuspend_user(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_unsuspend_user(uuid, uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unsuspend_user(uuid, uuid, text) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_ban_user(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_reason text,
  p_report_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  SELECT account_status INTO v_prev FROM public.profiles WHERE id = p_target_user_id;
  IF v_prev IS NULL THEN
    RETURN jsonb_build_object('error', 'User not found');
  END IF;

  UPDATE public.profiles SET
    account_status = 'banned',
    suspended_until = NULL,
    moderation_reason = p_reason
  WHERE id = p_target_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES (
    'BAN',
    p_actor_id,
    'user',
    p_target_user_id,
    jsonb_build_object(
      'reason', p_reason,
      'previous_status', v_prev,
      'new_status', 'banned',
      'report_id', p_report_id
    )
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_ban_user(uuid, uuid, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_ban_user(uuid, uuid, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_ban_user(uuid, uuid, text, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_unban_user(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT public.admin_validate_actor(p_actor_id) THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  SELECT account_status INTO v_prev FROM public.profiles WHERE id = p_target_user_id;
  UPDATE public.profiles SET
    account_status = 'active',
    suspended_until = NULL,
    moderation_reason = NULL
  WHERE id = p_target_user_id;

  INSERT INTO public.admin_audit_log (action, actor_id, target_type, target_id, details)
  VALUES (
    'UNBAN',
    p_actor_id,
    'user',
    p_target_user_id,
    jsonb_build_object('reason', p_reason, 'previous_status', v_prev, 'new_status', 'active')
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_unban_user(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_unban_user(uuid, uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unban_user(uuid, uuid, text) TO service_role;

COMMENT ON TABLE public.user_blocks IS 'Peer blocks for messaging protection; both directions block messaging';
COMMENT ON TABLE public.user_reports IS 'User-submitted peer reports for Retool moderation triage';
