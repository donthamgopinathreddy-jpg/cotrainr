-- Mirrors live production migration 20260908231648.
-- Areas 4-5 backend hardening: provider authority and verification-owned writes.

DROP POLICY IF EXISTS "Active accounts can delete provider locations" ON public.provider_locations;
DROP POLICY IF EXISTS "Active accounts can insert provider locations" ON public.provider_locations;
DROP POLICY IF EXISTS "Active accounts can update provider locations" ON public.provider_locations;
DROP POLICY IF EXISTS "Providers can manage own locations" ON public.provider_locations;
CREATE POLICY "Providers can select own locations" ON public.provider_locations FOR SELECT TO authenticated USING ((select auth.uid()) = provider_id);
CREATE POLICY "Active providers can insert own locations" ON public.provider_locations FOR INSERT TO authenticated WITH CHECK ((select auth.uid()) = provider_id AND public.is_account_active());
CREATE POLICY "Active providers can update own locations" ON public.provider_locations FOR UPDATE TO authenticated USING ((select auth.uid()) = provider_id AND public.is_account_active()) WITH CHECK ((select auth.uid()) = provider_id AND public.is_account_active());
CREATE POLICY "Active providers can delete own locations" ON public.provider_locations FOR DELETE TO authenticated USING ((select auth.uid()) = provider_id AND public.is_account_active());

DROP POLICY IF EXISTS "Active accounts can delete provider certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Active accounts can insert provider certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Active accounts can update provider certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers delete own certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers insert own certifications" ON public.provider_certifications;
DROP POLICY IF EXISTS "Providers update own certifications" ON public.provider_certifications;
CREATE POLICY "Active providers can insert own certifications" ON public.provider_certifications FOR INSERT TO authenticated WITH CHECK ((select auth.uid()) = provider_id AND public.is_account_active() AND verification_status IN ('unverified','pending'));
CREATE POLICY "Active providers can update own certifications" ON public.provider_certifications FOR UPDATE TO authenticated USING ((select auth.uid()) = provider_id AND public.is_account_active()) WITH CHECK ((select auth.uid()) = provider_id AND public.is_account_active());
CREATE POLICY "Active providers can delete own certifications" ON public.provider_certifications FOR DELETE TO authenticated USING ((select auth.uid()) = provider_id AND public.is_account_active());

DROP POLICY IF EXISTS "Active accounts can submit verification" ON public.verification_submissions;
DROP POLICY IF EXISTS "Providers can insert own pending" ON public.verification_submissions;
CREATE POLICY "Active providers can insert own pending verification" ON public.verification_submissions FOR INSERT TO authenticated WITH CHECK (
  (select auth.uid()) = user_id AND public.is_account_active() AND COALESCE(status, 'pending') = 'pending'
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (select auth.uid()) AND p.role::text IN ('trainer','nutritionist') AND p.role::text = provider_type::text)
);

DROP POLICY IF EXISTS "Anyone can view providers" ON public.providers;
DROP POLICY IF EXISTS "Providers can insert own active provider" ON public.providers;
DROP POLICY IF EXISTS "Providers can update own active provider" ON public.providers;
CREATE POLICY "Providers and eligible clients can view provider rows" ON public.providers FOR SELECT TO authenticated USING (
  (select auth.uid()) = user_id OR (verified IS TRUE AND discoverable IS TRUE)
  OR EXISTS (SELECT 1 FROM public.leads l WHERE l.provider_id = providers.user_id AND l.client_id = (select auth.uid()) AND l.status IN ('requested','accepted'))
);
CREATE POLICY "Providers can insert own active provider" ON public.providers FOR INSERT TO authenticated WITH CHECK (
  (select auth.uid()) = user_id AND public.is_account_active() AND verified IS FALSE AND COALESCE(rating, 0) = 0 AND COALESCE(total_reviews, 0) = 0
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (select auth.uid()) AND p.role::text IN ('trainer','nutritionist') AND p.role::text = provider_type::text)
);
CREATE POLICY "Providers can update own active provider" ON public.providers FOR UPDATE TO authenticated USING ((select auth.uid()) = user_id AND public.is_account_active()) WITH CHECK (
  (select auth.uid()) = user_id AND public.is_account_active()
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = (select auth.uid()) AND p.role::text IN ('trainer','nutritionist') AND p.role::text = provider_type::text)
);
