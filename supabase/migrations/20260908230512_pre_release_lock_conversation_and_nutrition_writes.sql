-- Production migration 20260908230512
-- Force new provider-client conversations through vetted RPCs and remove
-- permissive cross-user write paths from meals, meal_items, nutrition_goals.

drop policy if exists "Participants can insert conversations" on public.conversations;

drop policy if exists "Active accounts can insert meals" on public.meals;
drop policy if exists "Active accounts can update meals" on public.meals;
drop policy if exists "Active accounts can delete meals" on public.meals;
drop policy if exists "Users can manage own meals" on public.meals;
drop policy if exists "Users can select own meals" on public.meals;
create policy "Users can select own meals" on public.meals for select to authenticated using (auth.uid() = user_id);
create policy "Active users can insert own meals" on public.meals for insert to authenticated with check (auth.uid() = user_id and public.is_account_active());
create policy "Active users can update own meals" on public.meals for update to authenticated using (auth.uid() = user_id and public.is_account_active()) with check (auth.uid() = user_id and public.is_account_active());
create policy "Active users can delete own meals" on public.meals for delete to authenticated using (auth.uid() = user_id and public.is_account_active());

drop policy if exists "Active accounts can insert meal items" on public.meal_items;
drop policy if exists "Active accounts can update meal items" on public.meal_items;
drop policy if exists "Active accounts can delete meal items" on public.meal_items;
drop policy if exists "Users can manage own meal items" on public.meal_items;
create policy "Users can select own meal items" on public.meal_items for select to authenticated using (exists (select 1 from public.meals m where m.id = meal_items.meal_id and m.user_id = auth.uid()));
create policy "Active users can insert own meal items" on public.meal_items for insert to authenticated with check (public.is_account_active() and exists (select 1 from public.meals m where m.id = meal_items.meal_id and m.user_id = auth.uid()));
create policy "Active users can update own meal items" on public.meal_items for update to authenticated using (public.is_account_active() and exists (select 1 from public.meals m where m.id = meal_items.meal_id and m.user_id = auth.uid())) with check (public.is_account_active() and exists (select 1 from public.meals m where m.id = meal_items.meal_id and m.user_id = auth.uid()));
create policy "Active users can delete own meal items" on public.meal_items for delete to authenticated using (public.is_account_active() and exists (select 1 from public.meals m where m.id = meal_items.meal_id and m.user_id = auth.uid()));

drop policy if exists "Active accounts can insert nutrition goals" on public.nutrition_goals;
drop policy if exists "Active accounts can update nutrition goals" on public.nutrition_goals;
drop policy if exists "Active accounts can delete nutrition goals" on public.nutrition_goals;
drop policy if exists "Users can insert own nutrition goals" on public.nutrition_goals;
drop policy if exists "Users can update own nutrition goals" on public.nutrition_goals;
drop policy if exists "Users can delete own nutrition goals" on public.nutrition_goals;
create policy "Active users can insert own nutrition goals" on public.nutrition_goals for insert to authenticated with check (auth.uid() = user_id and public.is_account_active());
create policy "Active users can update own nutrition goals" on public.nutrition_goals for update to authenticated using (auth.uid() = user_id and public.is_account_active()) with check (auth.uid() = user_id and public.is_account_active());
create policy "Active users can delete own nutrition goals" on public.nutrition_goals for delete to authenticated using (auth.uid() = user_id and public.is_account_active());
