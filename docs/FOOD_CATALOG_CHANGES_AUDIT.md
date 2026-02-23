# Food Catalog Upgrade — Technical Audit Note

## Summary

Additive upgrade to Meal Tracker: Supabase-backed food catalog with per-100g nutrition, replacing hardcoded common foods. Macros are computed from catalog when user selects food and enters grams.

## Changes Made

### 1. Supabase Migration (`supabase/migrations/20250215_add_food_catalog.sql`)

- **foods** table: id, name, aliases, cuisine, category, is_prepared, source, source_ref, kcal_100g, protein_100g, carbs_100g, fat_100g, fiber_100g, micros, verified, created_at, updated_at
- **food_portions** table: id, food_id, label, grams, is_default
- **meal_items**: added nullable `food_id` column (backward compatible)
- Indexes: lower(name), GIN(aliases), verified
- RLS: SELECT for authenticated on foods and food_portions; no INSERT/UPDATE for authenticated
- Admin RPCs (service_role only): admin_upsert_food, admin_upsert_portion, admin_search_foods
- updated_at trigger on foods

### 2. FoodCatalogRepository (`lib/repositories/food_catalog_repository.dart`)

- `CatalogFood` model with per-100g values and `macrosForGrams(grams)` helper
- `FoodPortion` model
- `searchFoods(query, verifiedOnly)` — Supabase SELECT with ilike on name
- `getFoodPortions(foodId)` — fetch portions for a food

### 3. MealRepository (`lib/repositories/meal_repository.dart`)

- `addFoodItem` now accepts optional `foodId`; stored in meal_items.food_id when provided

### 4. Meal Tracker Add Food UI (`lib/pages/meal_tracker/meal_tracker_page_v2.dart`)

- Replaced hardcoded `_commonFoods` with catalog search
- `_AddFoodSheet` uses `FoodCatalogRepository`; callback extended with `catalogFoodId`
- `_CatalogSearchStep`: debounced search (350ms), recent chips set search text, catalog results with verified badge
- `_CatalogDetailsStep`: grams input (default 100), quick chips (50/100/150/200g), portions from DB, macro preview (kcal/P/C/F/Fi), meal selector, Add button disabled while saving
- Storage: unit='100g', quantity=grams, per-100g values from catalog, food_id when from catalog

### 5. Correctness Fixes

- **Dismissible key**: changed from `Key(food.name)` to `Key(food.id ?? '${food.name}_${food.amount}_${food.totalCalories}')` to avoid collision for duplicate names
- **Division by zero**: `_DailySummaryCard` guards `goalProtein`, `goalCarbs`, `goalFats` with `> 0` before division
- **"Today's Intake" label**: now shows "Intake" when selected date is not today; "Today's Intake" only when viewing today

### 6. Seeding

- `scripts/seed_foods.js`: Node script to import CSV via admin_upsert_food RPC
- `docs/FOOD_CATALOG_SEEDING.md`: CSV format, USDA FDC mapping, verification workflow

## Unchanged

- BMI, signup flows
- Core meal flows: add/edit/delete, goals, weekly insights
- meals, meal_items schema (except additive food_id)
- Aggregation logic in MealRepository (_factorForUnit, getDayMeals, getWeeklyAggregates)
- No barcode scanning

## Risks / Follow-ups

- Empty catalog: if no foods seeded, search returns empty; user sees "Search to find foods" / "No results"
- Recent chips: set search text only; do not add non-catalog foods. For non-catalog foods, a future "Add custom food" flow would be needed
- Weekly Insights: still receives `_commonFoods` (now empty) and `_recentFoods`; common foods section will show "No foods yet" until catalog is seeded
