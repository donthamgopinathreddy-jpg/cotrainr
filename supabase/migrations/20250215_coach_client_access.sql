-- Coach access: trainers/nutritionists can view client metrics and meals when they have an accepted lead.

-- metrics_daily: add SELECT for coaches
DROP POLICY IF EXISTS "Coaches can view client metrics" ON public.metrics_daily;
CREATE POLICY "Coaches can view client metrics"
  ON public.metrics_daily FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.provider_id = auth.uid()
        AND l.client_id = metrics_daily.user_id
        AND l.status = 'accepted'
    )
  );

-- meals: add SELECT for coaches (existing policy is FOR ALL with user_id check)
DROP POLICY IF EXISTS "Coaches can view client meals" ON public.meals;
CREATE POLICY "Coaches can view client meals"
  ON public.meals FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.leads l
      WHERE l.provider_id = auth.uid()
        AND l.client_id = meals.user_id
        AND l.status = 'accepted'
    )
  );

-- meal_items: coaches view via meals join - need policy
DROP POLICY IF EXISTS "Coaches can view client meal items" ON public.meal_items;
CREATE POLICY "Coaches can view client meal items"
  ON public.meal_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.meals m
      JOIN public.leads l ON l.client_id = m.user_id AND l.provider_id = auth.uid() AND l.status = 'accepted'
      WHERE m.id = meal_items.meal_id
    )
  );
