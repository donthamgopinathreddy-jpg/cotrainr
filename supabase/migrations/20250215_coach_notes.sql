-- Coach notes: trainers and nutritionists can add notes for their clients.
-- Clients see these notes in their "Notes" quick access tile.

CREATE TABLE IF NOT EXISTS public.coach_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coach_notes_client_id ON public.coach_notes(client_id);
CREATE INDEX IF NOT EXISTS idx_coach_notes_coach_id ON public.coach_notes(coach_id);
CREATE INDEX IF NOT EXISTS idx_coach_notes_created_at ON public.coach_notes(created_at DESC);

ALTER TABLE public.coach_notes ENABLE ROW LEVEL SECURITY;

-- Client can view notes addressed to them
CREATE POLICY "Clients can view own notes"
  ON public.coach_notes FOR SELECT
  USING (auth.uid() = client_id);

-- Coach (trainer/nutritionist) can insert notes for clients they have accepted lead with
CREATE POLICY "Coaches can insert notes for accepted clients"
  ON public.coach_notes FOR INSERT
  WITH CHECK (
    auth.uid() = coach_id
    AND EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.client_id = coach_notes.client_id
        AND l.provider_id = auth.uid()
        AND l.status = 'accepted'
    )
  );

-- Coach can update/delete their own notes
CREATE POLICY "Coaches can update own notes"
  ON public.coach_notes FOR UPDATE
  USING (auth.uid() = coach_id);

CREATE POLICY "Coaches can delete own notes"
  ON public.coach_notes FOR DELETE
  USING (auth.uid() = coach_id);

COMMENT ON TABLE public.coach_notes IS 'Notes from trainers/nutritionists to their clients; shown in client Notes tile';
