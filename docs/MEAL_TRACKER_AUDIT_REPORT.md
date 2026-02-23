# Meal Tracker Feature — Read-Only Audit Report

**Date:** February 15, 2025  
**Scope:** Meal Tracker UI, state management, data model, API integration, navigation, error handling, performance, UX consistency  
**Constraint:** Inspection only — no code changes proposed.

---

## Section A: Findings

### A.1 UI/UX Issues

| # | Observation | Location |
|---|-------------|----------|
| 1 | **No initial loading state** — Main Meal Tracker page shows hardcoded totals (1260 kcal, 92g P, etc.) until `_loadDayData()` completes. Users may briefly see stale or placeholder values. | `meal_tracker_page_v2.dart` L43–48, L116–137 |
| 2 | **"Today's Intake" label** — Summary card always says "Today's Intake" even when viewing a past/future date. Misleading when user selects another day. | `meal_tracker_page_v2.dart` L1179 |
| 3 | **"Verified" badge on all foods** — Every food in the picker shows a "Verified" badge. Common foods are hardcoded, not verified. Misleading. | `meal_tracker_page_v2.dart` L2657–2694 |
| 4 | **Edit affordance hidden** — Edit amount is only via long-press. No visible edit icon or hint. Users may not discover it. | `meal_tracker_page_v2.dart` L3339 |
| 5 | **Add photo button does nothing** — Camera button in meal detail sheet has empty `onTap` (comment: "Add photo functionality"). | `meal_tracker_page_v2.dart` L3307–3311 |
| 6 | **Meal order not persisted** — Reordering meals (touch-hold drag) updates local state only. Order resets on app restart. | `meal_tracker_page_v2.dart` L686–694 |
| 7 | **Common foods calories per 100g** — FoodCard shows `food.calories` (per 100g) without clarifying. User may think it's total. | `meal_tracker_page_v2.dart` L2699 |
| 8 | **No quick-add from home** — Home tile only navigates. No daily calorie preview or "log meal" shortcut. | `quick_access_v3.dart` L114–115 |
| 9 | **Deprecated `withOpacity`** — Several usages of `withOpacity` instead of `withValues(alpha: ...)`. | `meal_tracker_page_v2.dart` L2373, L2629, L3250, L3295, L3335; `weekly_insights_page.dart` L387 |
| 10 | **Weekly Insights week start** — Uses `DateTime.monday` (Mon–Sun). Some locales expect Sun–Sat. No locale awareness. | `meal_tracker_page_v2.dart` L275–276; `weekly_insights_page.dart` L113–114 |

### A.2 Technical Risks

| # | Observation | Location |
|---|-------------|----------|
| 11 | **Dismissible key collision** — `Dismissible(key: Key(food.name))` — duplicate food names (e.g. two "Chicken Breast") cause widget key collision and incorrect delete behavior. | `meal_tracker_page_v2.dart` L3330 |
| 12 | **Division by zero** — `_DailySummaryCard` uses `protein / goalProtein`, `carbs / goalCarbs`, `fats / goalFats`. If goals are 0, division by zero. | `meal_tracker_page_v2.dart` L1151–1153 |
| 13 | **Amount controller desync** — In `_FoodDetailsStep`, +/- buttons call `onAmountChanged` but `amountController` is not updated. User types in TextField, then taps +; TextField still shows old value until rebuild. | `meal_tracker_page_v2.dart` L2792–2835, L2712 |
| 14 | **Race on add food** — `onFoodAdded` does add → getDayMeals → setState → pop. If user taps Add twice quickly, duplicate inserts possible. No loading/disabled state during add. | `meal_tracker_page_v2.dart` L427–478 |
| 15 | **Repository errors swallowed** — `getDayMeals`, `getClientDayMeals`, `getWeeklyAggregates` catch exceptions and return empty. User sees empty day with no error message. | `meal_repository.dart` L176–179, L241–244, L389–392 |
| 16 | **Duplicate logic** — `getDayMeals` and `getClientDayMeals` share nearly identical aggregation logic. Violates DRY. | `meal_repository.dart` L113–179, L183–245 |
| 17 | **Unit normalization assert in release** — `normalizeUnitForStorage` has `assert(quantity == 1.0, ...)`. Asserts are stripped in release; release-safe branch may produce wrong scaling. | `meal_repository.dart` L279–288 |
| 18 | **No offline handling** — Supabase calls fail when offline. No retry, cache, or offline queue. | `meal_repository.dart` (all methods) |
| 19 | **`_recomputeTotals` vs DB totals** — After add/delete/update, UI uses `_recomputeTotals()` from in-memory `_meals`. After add, code also refetches from DB and overwrites. Inconsistent flow. | `meal_tracker_page_v2.dart` L155–174, L444–455 |

### A.3 Performance Concerns

| # | Observation | Location |
|---|-------------|----------|
| 20 | **Full rebuild on any state change** — `MealTrackerPageV2` uses a single `setState` for meals, goals, date, etc. Entire `CustomScrollView` rebuilds. | `meal_tracker_page_v2.dart` (build method) |
| 21 | **Search listener rebuilds** — `_searchController.addListener(() => setState(() {}))` triggers full `_AddFoodSheet` rebuild on every keystroke. | `meal_tracker_page_v2.dart` L2292 |
| 22 | **Heavy page file** — `meal_tracker_page_v2.dart` is ~3,500+ lines. Many private widgets in one file. Hard to maintain, may affect hot reload. | `meal_tracker_page_v2.dart` |
| 23 | **Weekly Insights mock fallback** — When `mealRepository == null`, uses hardcoded mock data. No loading state in that path; `_loading` stays false. | `weekly_insights_page.dart` L74–91 |
| 24 | **Two sequential Supabase calls on add** — Add flow: `addFoodItem` then `getDayMeals`. Could be optimized with a single refetch or optimistic update. | `meal_tracker_page_v2.dart` L429–442 |

### A.4 Data Model & Schema

| # | Observation | Location |
|---|-------------|----------|
| 25 | **`consumed_date` vs `consumed_at`** — `_ensureMeal` sets `consumed_at` to noon local. `consumed_date` is the source of truth for day bucketing. Migration notes: no backfill for legacy rows; NULL `consumed_date` rows excluded from queries. | `meal_repository.dart` L363–365; `20250215_meal_tracker_supabase.sql` L39–48 |
| 26 | **Fiber in NutritionGoals** — Default 30g. UI shows fiber in summary but no ring/progress. | `meal_tracker_page_v2.dart` L565–566; `meal_repository.dart` L74 |
| 27 | **Meal photos not persisted** — `_mealPhotoPath` is in-memory only. Photos lost on navigation/restart. | `meal_tracker_page_v2.dart` L29–34, L733–738 |
| 28 | **Recent foods in memory only** — `_recentFoods` capped at 5, not persisted. Resets on app restart. | `meal_tracker_page_v2.dart` L64–65, L455–458 |

---

## Section B: Root Causes (Ranked)

1. **Logic embedded in widgets** — Business logic (totals, unit factor, normalization) lives in UI layer or repository without clear separation. Increases risk of bugs when UI changes.
2. **No shared state layer** — All state in `_MealTrackerPageV2State`. No provider/store. Hard to test, reuse, or keep UI and data in sync.
3. **Duplicated aggregation logic** — `getDayMeals` and `getClientDayMeals` repeat the same loop. `_recomputeTotals` duplicates aggregation that DB already does.
4. **Missing abstractions** — No `MealTrackerController` or service. Repository does both data access and computation (e.g. `_factorForUnit`).
5. **Inconsistent error handling** — Repository returns empty on error; some callers show SnackBar, others show nothing. No unified strategy.
6. **Tight coupling** — `_AddFoodSheet` receives `onFoodAdded` callback that does add + refetch + setState + pop. Hard to unit test or reuse.
7. **No loading/optimistic states** — Add, delete, update lack loading indicators. User cannot tell if action succeeded or is in progress.
8. **Hardcoded defaults** — Initial totals (1260, 92, etc.) and common foods are literals. Makes it unclear what "empty" state looks like.

---

## Section C: Gaps vs Best Practices

### C.1 Typical Fitness App Patterns — Missing or Partial

| Feature | Current State | Gap |
|---------|---------------|-----|
| **Daily totals visibility** | Shown in summary card. | ✅ Present. |
| **Macro breakdown clarity** | P/C/F chips and rings. Fiber shown but no ring. | Partial — fiber underemphasized. |
| **Quick add** | Must open sheet → search → select → amount → add. | No one-tap "log 100g chicken" from recent. |
| **Edit/delete affordances** | Delete: swipe. Edit: long-press only. | Edit not discoverable; no explicit edit icon. |
| **Barcode scan** | Not implemented. | Common in MyFitnessPal, Lose It, etc. |
| **Custom food creation** | Not implemented. User can only pick from common/recent. | Major gap for personal recipes/foods. |
| **Meal templates** | Not implemented. | Cannot save "typical breakfast" and log in one tap. |
| **Daily calorie goal vs remaining** | Shows consumed / goal. | No "X kcal remaining" or progress bar. |
| **Weekly average** | Weekly Insights has it. | ✅ Present. |
| **Export / share** | Not implemented. | No CSV, PDF, or share with coach. |
| **Coach view** | `getClientDayMeals` exists. | Coach must navigate from client detail; no dedicated coach meal view. |
| **Bulk delete** | Not implemented. | Cannot clear a day or meal at once. |

### C.2 Design System Consistency

| Aspect | Meal Tracker | Rest of App |
|--------|--------------|-------------|
| **Theme** | `MealTrackerTokens` (green accent, custom light/dark) | `DesignTokens`, `AppColors` |
| **Typography** | Custom font weights/sizes in tokens | `DesignTokens.fontSize*` |
| **Spacing** | Mixed (16, 18, 20, 24) | 8pt grid in DesignTokens |
| **Animations** | Fade, ring animation, press scale | Similar patterns |
| **Navigation** | `Navigator.push` for Weekly Insights | `context.push` (go_router) elsewhere |

Meal Tracker uses a separate design system (`MealTrackerTokens`), which can cause visual inconsistency if app theme changes.

---

## Section D: Risks

### D.1 Data Integrity

| Risk | Description |
|------|-------------|
| **Wrong totals** | `_factorForUnit` regex may not match all unit formats (e.g. "1 cup", "1 slice"). Mismatch → wrong calorie/macro totals. |
| **Double scaling** | `normalizeUnitForStorage` handles "0.5x", "2x". If UI sends quantity ≠ 1 with multiplier unit, assert fails in debug; release path may double or under-scale. |
| **Timezone / day boundaries** | App uses local `DateTime` for `consumed_date`. User traveling across midnight may see meals on "wrong" day if device timezone changes. Migration explicitly avoids backfilling from UTC. |
| **Unique constraint** | `(user_id, consumed_date, meal_type)` unique. Two rapid adds to same meal type could hit race; `_ensureMeal` uses upsert + conflict handling to mitigate. |

### D.2 UX Risks

| Risk | Description |
|------|-------------|
| **Calorie misunderstanding** | Common foods show per-100g or per-serving. User may log "1" for chicken thinking 1 piece, not 100g. |
| **Friction in logging** | 4-step flow (open sheet → search → amount → add). No quick-add from recent. May reduce compliance. |
| **Empty state confusion** | New user sees "0 / 2000" and empty meals. No onboarding or "Add your first meal" CTA. |
| **Date confusion** | "Today's Intake" when viewing yesterday. Users may think totals are wrong. |

---

## Section E: Verification Checklist

### E.1 Manual Test Cases

| # | Test | Expected |
|---|------|----------|
| 1 | Open Meal Tracker from Quick Access | Navigate to `/meal-tracker`, see day strip and summary |
| 2 | Select today | Summary shows today's meals and totals |
| 3 | Select yesterday (no meals) | Summary shows 0/2000, empty meal tiles |
| 4 | Add food to Breakfast | Sheet opens, select food, set amount, Add → item appears, totals update |
| 5 | Edit food amount (long-press) | Dialog opens, change amount, Save → totals update |
| 6 | Swipe to delete food | Item removed, totals update |
| 7 | Add duplicate food name | Both appear; swipe delete may target wrong one (key collision) |
| 8 | Open Weekly Insights | Chart loads, metric chips work, week arrows work |
| 9 | Edit goals | Sheet opens, change values, Save → goals persist, rings update |
| 10 | Add custom meal | Dialog "Add Meal", enter name → new tile appears |
| 11 | Reorder meals (drag) | Order changes; restart app → order resets |
| 12 | Go offline, add food | Error SnackBar or silent failure |
| 13 | Open meal detail, tap camera | No visible action (stub) |

### E.2 Edge Cases

| # | Scenario | What to Verify |
|----|----------|----------------|
| 14 | No meals for selected day | Empty tiles, 0 totals, no crash |
| 15 | Goals = 0 | No division-by-zero crash in summary rings |
| 16 | Timezone change mid-session | Selected date and meals still consistent |
| 17 | Unit "1 cup" or "1 slice" | Factor calculation correct (regex may not match) |
| 18 | Quantity 0 for food | Handled (clamped or rejected) |
| 19 | Very long food name | Truncation, no layout overflow |
| 20 | 100+ foods in one meal | Scroll performance, no jank |
| 21 | Rapid add (double-tap Add) | No duplicate items or crash |
| 22 | Log for future date | Allowed? Behavior? |
| 23 | Coach opens client meal view | `getClientDayMeals` used; RLS allows |

---

## Summary

The Meal Tracker is functionally complete for core flows (add, edit, delete, goals, weekly insights) and integrated with Supabase. Main concerns are: **no loading states** on the main page, **hidden edit affordance**, **Dismissible key collision** for duplicate names, **division-by-zero** risk with zero goals, **repository errors returning empty** without user feedback, and **no custom food creation**. Architecture is widget-centric with no provider/store, which increases maintenance and testing cost. Design uses a separate token system (`MealTrackerTokens`) that may diverge from the rest of the app.
