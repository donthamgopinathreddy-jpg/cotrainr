DROP POLICY IF EXISTS "Active accounts can insert partner applications" ON public.partner_center_applications;
DROP POLICY IF EXISTS "Active accounts can update partner applications" ON public.partner_center_applications;

DROP POLICY IF EXISTS "Users insert own partner applications" ON public.partner_center_applications;
CREATE POLICY "Users insert own active partner applications"
ON public.partner_center_applications FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid())=submitted_by AND status='pending' AND public.is_account_active());

DROP POLICY IF EXISTS "Users withdraw own partner applications" ON public.partner_center_applications;
CREATE POLICY "Users withdraw own active partner applications"
ON public.partner_center_applications FOR UPDATE TO authenticated
USING ((SELECT auth.uid())=submitted_by AND public.is_account_active())
WITH CHECK ((SELECT auth.uid())=submitted_by AND status='withdrawn' AND public.is_account_active());
