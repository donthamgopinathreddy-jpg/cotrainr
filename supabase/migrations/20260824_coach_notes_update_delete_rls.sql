-- Tighten coach_notes UPDATE/DELETE to require an accepted relationship.
-- Client SELECT (notes addressed to them) is unchanged.

DROP POLICY IF EXISTS "Coaches can update own notes" ON public.coach_notes;
CREATE POLICY "Coaches can update own notes"
  ON public.coach_notes FOR UPDATE
  USING (
    auth.uid() = coach_id
    AND EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.client_id = coach_notes.client_id
        AND l.provider_id = auth.uid()
        AND l.status = 'accepted'
    )
  );

DROP POLICY IF EXISTS "Coaches can delete own notes" ON public.coach_notes;
CREATE POLICY "Coaches can delete own notes"
  ON public.coach_notes FOR DELETE
  USING (
    auth.uid() = coach_id
    AND EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.client_id = coach_notes.client_id
        AND l.provider_id = auth.uid()
        AND l.status = 'accepted'
    )
  );
