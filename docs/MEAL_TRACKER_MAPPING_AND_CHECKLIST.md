# Meal Tracker → Supabase: Mapping Table & Test Checklist

## UI Element → DB Field / API Call

| UI Element | DB Table/Column | API Call |
|------------|-----------------|----------|
| **Date picker / week strip** | `meals.consumed_date` | `MealRepository.getDayMeals(selectedDate)` |
| **Daily summary (totals)** | Aggregated from `meal_items` | Computed in `getDayMeals()` → `DayMealsData.totalCalories`, etc. |
| **Edit goals** | `nutrition_goals` | `getNutritionGoals()`, `upsertNutritionGoals()` |
| **Meal tiles** | `meals` + `meal_items` | `getDayMeals()` → `mealsByType` |
| **Add food** | `meals`, `meal_items` | `addFoodItem()` (ensures meal via `_ensureMeal`) |
| **Edit food (amount)** | `meal_items.quantity` | `updateFoodItemAmount(mealItemId, quantity)` |
| **Delete food** | `meal_items` | `deleteFoodItem(mealItemId)` |
| **Add custom meal** | No DB table | Creates meal row on first food add via `meal_type` string |
| **Weekly insights** | Aggregated from `meals` + `meal_items` | `getWeeklyAggregates(weekEndDate)` |
| **Meal photos** | `meal_media` (optional) | Not wired yet – UI stores local path |

## Unit representation (factor calculation)

- **Gram-based:** `"100g"`, `"50 g"` — quantity = grams consumed. factor = quantity / base.
- **Serving/multiplier:** `"1 medium"`, `"1x"` — quantity = count (0.5, 1, 2). factor = quantity.
- **Important:** Unit must be the base unit (e.g. `"1 medium"` not `"0.5x"`). For half serving, use quantity=0.5.

## Field Mapping (UI ↔ DB)

| UI (FoodItem) | DB (meal_items) |
|---------------|-----------------|
| `id` | `meal_items.id` |
| `name` | `food_name` |
| `calories` | `calories` (per unit) |
| `protein` | `protein` |
| `carbs` | `carbs` |
| `fats` | `fat` |
| `fiber` | `fiber` |
| `unit` | `unit` |
| `amount` | `quantity` |

## Manual Test Checklist

### Prerequisites
- [ ] Supabase project running
- [ ] Migration `20250215_meal_tracker_supabase.sql` applied
- [ ] User authenticated in app

### Day Selection
- [ ] Open Meal Tracker, verify today’s date loads
- [ ] Tap week strip day → data updates for that day
- [ ] Open calendar, pick another date → data updates
- [ ] Switch between days with/without data → totals correct

### Goals
- [ ] Tap "Edit goals" → sheet opens with current values
- [ ] Change values, tap Save → goals persist
- [ ] Reload app → goals still correct
- [ ] Summary ring reflects goal vs actual

### Add Food
- [ ] Tap + on Breakfast → Add Food sheet opens
- [ ] Select food, set amount, tap Add → item appears in meal
- [ ] Add to Lunch, Dinner, Snacks → each works
- [ ] Add custom meal type (e.g. "Pre-workout") → tile appears
- [ ] Add food to custom meal → persists

### Edit / Delete Food
- [ ] Open meal detail, long-press food → edit amount dialog
- [ ] Change amount, save → totals update
- [ ] Swipe to delete food → item removed, totals update

### Weekly Insights
- [ ] Tap summary card "Insights" → Weekly Insights opens
- [ ] Bar chart shows 7 days (real data when repo provided)
- [ ] Switch metric (Calories/Protein/Carbs/Fat) → chart updates
- [ ] Use week arrows → data refetches for new week

### Edge Cases
- [ ] Add food when offline → error shown (or graceful fallback)
- [ ] Log food for yesterday → appears under yesterday’s date
- [ ] Multiple meals same type same day → only one row (unique constraint)

### Timezone
- [ ] User in different timezone: selected date matches local calendar day
- [ ] No "breakfast disappeared" or "yesterday meals showing today"
