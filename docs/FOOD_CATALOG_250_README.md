# Food Catalog 250 – MVP Catalog

MVP food catalog of 250 items (Indian + international) for the Meal Tracker. Stored in Supabase Postgres. No external APIs.

## Scope

- **250 foods** total: ~150 Indian (raw staples + cooked dishes) + ~100 international/common
- **Per-100g macros**: `kcal_100g`, `protein_100g`, `carbs_100g`, `fat_100g`, `fiber_100g`
- **Portions** for 120+ foods (e.g. "1 cup cooked", "1 roti", "1 egg", "1 banana medium")
- **Edible portions only**; no brand-specific packaged foods
- **Raw vs cooked** as separate foods (e.g. "Rice white cooked" vs "Rice white raw")

## Assumptions

- Nutrition values are **approximate** and conservative
- `kcal ≈ 4×(protein+carbs) + 9×fat` (±15%) for internal consistency
- `fiber ≤ carbs` for all items
- `source = "manual_seed"`, `source_ref = "cotrainr_v1"`
- `verified = true` for all seeded items
- `micros` is empty `{}` (no micronutrients stored)

## Files

| File | Description |
|------|-------------|
| `data/foods_catalog_250.csv` | 250 foods with name, aliases (pipe-separated), cuisine, category, is_prepared, macros, verified |
| `data/food_portions.csv` | Portions for 120+ foods: food_name, label, grams, is_default |
| `scripts/seed_food_catalog.js` | Seed script that reads both CSVs and upserts via admin RPCs |

## How to Run the Seed Script

### Prerequisites

- Node.js 18+
- `@supabase/supabase-js` installed
- Supabase project with `foods` + `food_portions` tables and `admin_upsert_food` / `admin_upsert_portion` RPCs

### Run

```bash
# From project root
SUPABASE_URL=https://your-project.supabase.co SUPABASE_SERVICE_ROLE_KEY=your-service-role-key node scripts/seed_food_catalog.js
```

Optional custom paths:

```bash
node scripts/seed_food_catalog.js path/to/foods.csv path/to/portions.csv
```

### Behavior

1. Reads `data/foods_catalog_250.csv` and `data/food_portions.csv`
2. Validates: no duplicate names, non-negative macros, fiber ≤ carbs, kcal consistency
3. Upserts foods via `admin_upsert_food` (service_role only)
4. Builds name → id map; upserts portions via `admin_upsert_portion`
5. Logs progress and any skipped portions (e.g. food_name not in catalog)

### Re-running

Re-running the script will **upsert** foods (update existing by name) but **insert** new portions. Portions are not deduplicated by (food_id, label), so repeated runs may create duplicate portions. To reset, truncate `food_portions` and `foods` before re-seeding.

## How to Extend

### Adding Foods

1. Add rows to `data/foods_catalog_250.csv` with columns:
   - `name`, `aliases` (pipe-separated), `cuisine`, `category`, `is_prepared`
   - `source`, `source_ref`, `kcal_100g`, `protein_100g`, `carbs_100g`, `fat_100g`, `fiber_100g`
   - `micros_json` (use `{}`), `verified` (true)

2. Ensure:
   - No duplicate `name`
   - `kcal ≈ 4×(protein+carbs) + 9×fat` (±15%)
   - `fiber ≤ carbs`

### Adding Portions

1. Add rows to `data/food_portions.csv`:
   - `food_name` must match exactly a `name` in the foods CSV
   - `label` (e.g. "1 cup cooked", "1 roti")
   - `grams` (realistic)
   - `is_default` true for the most common portion per food

2. Re-run the seed script.

### Optional SQL Seed

For a direct SQL approach, you can:

1. Export from Supabase after running the JS seed, or
2. Generate `INSERT` statements from the CSVs (e.g. with a small script).

The JS script is the recommended approach for seeding and updates.

## Categories Used

- `grains`, `legumes`, `vegetables`, `fruits`, `dairy`, `meat`, `eggs`, `nuts_seeds`, `oils_fats`, `beverages`, `snacks`, `sweets`, `dishes`

## Cuisines Used

- `indian`, `international`, `mixed`
