# Food Catalog Seeding

How to seed the 250-item food catalog into Supabase. No external APIs.

## Prerequisites

- Node.js 18+
- `@supabase/supabase-js` installed
- Supabase project with `foods` + `food_portions` tables
- Migration `20250215_add_food_catalog.sql` applied
- Migration `20250220_food_catalog_hardening_v4_1.sql` applied
- Migration `20250229_food_catalog_portion_dedupe.sql` applied (for portion upsert-by-label)

## How to Run

```bash
SUPABASE_URL=https://your-project.supabase.co SUPABASE_SERVICE_ROLE_KEY=your-service-role-key node scripts/seed_food_catalog.js
```

Optional custom paths:

```bash
node scripts/seed_food_catalog.js path/to/foods.csv path/to/portions.csv
```

## CSV Format

### foods_catalog_250.csv

| Column | Description |
|--------|-------------|
| `name` | Food name (unique after normalization) |
| `aliases_pipe` | Pipe-separated aliases (e.g. `rice\|chawal\|chaval`) |
| `cuisine` | `indian` / `international` / `mixed` |
| `category` | `grains`, `legumes`, `vegetables`, `fruits`, `dairy`, `meat`, `eggs`, `nuts_seeds`, `oils_fats`, `beverages`, `snacks`, `sweets`, `dishes` |
| `is_prepared` | `false` for raw ingredients, `true` for dishes |
| `source` | `manual_seed` |
| `source_ref` | `cotrainr_v1` |
| `kcal_100g`, `protein_100g`, `carbs_100g`, `fat_100g`, `fiber_100g` | Per-100g macros (≥ 0) |
| `micros_json` | `{}` for now |
| `verified` | `true` for seeded items |

### food_portions.csv

| Column | Description |
|--------|-------------|
| `food_name` | Must match exactly a `name` in foods CSV |
| `label` | e.g. "1 cup cooked", "1 roti", "1 egg", "1 tbsp" |
| `grams` | Realistic weight in grams |
| `is_default` | `true` for the most common portion per food (only one per food) |

## Behavior

1. Reads both CSVs
2. Validates: no duplicate names, non-negative macros, fiber ≤ carbs, kcal ≈ 4×(p+c)+9×f ±15%
3. Upserts foods via `admin_upsert_food` (upserts by `lower(trim(name))`)
4. Builds name → id map; upserts portions via `admin_upsert_portion`
5. **Fails fast** on invalid rows (negative macros, missing food for portion, etc.)

## How to Extend Safely

### Adding Foods

1. Add rows to `data/foods_catalog_250.csv`
2. Ensure no duplicate `name` (case-insensitive, trimmed)
3. Ensure macros: `kcal ≈ 4×(protein+carbs) + 9×fat` (±15%), `fiber ≤ carbs`
4. Re-run the seed script

### Adding Portions

1. Add rows to `data/food_portions.csv`
2. `food_name` must match exactly a `name` in the foods CSV
3. Only one `is_default=true` per food
4. Re-run the seed script

### Re-running

- Foods: **upserted** by name (same row updated)
- Portions: **upserted** by (food_id, label); repeated runs update existing portions, no duplicates
- To reset: truncate `food_portions` then `foods`, then re-run

## Verification Queries

Run in Supabase SQL Editor to confirm health:

**Duplicate portions** (should return 0 rows after migration `20250229`):

```sql
SELECT food_id, lower(regexp_replace(trim(label), '\s+', ' ', 'g')) AS label_norm, count(*)
FROM public.food_portions
GROUP BY food_id, lower(regexp_replace(trim(label), '\s+', ' ', 'g'))
HAVING count(*) > 1;
```
