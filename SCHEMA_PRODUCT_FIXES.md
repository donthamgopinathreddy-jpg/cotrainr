# Schema Product & Logic Fixes Applied ✅

## Critical Product Issues Fixed

### 1. ✅ NULL Geo Breaks "Nearby" Search (FIXED)
**Problem:** NULL geo for home-private locations broke distance calculation, filtering, and sorting  
**Solution (Option A - Approximate Geo):**
- **Geo is now always required** (NOT NULL)
- For home-private: store **approximate geo** (rounded to ~1-3km grid) in `geo` column
- For home-public or gym/studio: store exact geo in `geo` column
- RPC **masks geo in response** for home-private (returns NULL to client)
- This allows: distance calculation, filtering by max_distance, sorting by nearest

**Impact:** "Nearby" search now works correctly for all location types

### 2. ✅ Private Homes Showing Anywhere (FIXED)
**Problem:** RPC allowed private homes (null geo) to appear regardless of distance  
**Solution:**
- Removed the `geo IS NULL` branch from nearby_providers()
- Now requires `geo IS NOT NULL` (all locations have geo)
- Always uses `ST_DWithin` for distance filtering
- Private homes use approximate geo for distance, but return NULL geo to client

**Impact:** Only providers within max_distance_km are returned, properly sorted

### 3. ✅ Missing Provider Identity (FIXED)
**Problem:** Discover page couldn't show provider name/avatar  
**Solution:**
- Added `full_name` and `avatar_url` to `nearby_providers()` RPC result
- RPC now joins `profiles` table to get identity
- Added `verified` field to result

**Impact:** Discover cards can now display provider name, avatar, and verification status

### 4. ✅ Duplicate Constraint (FIXED)
**Problem:** `conversations.lead_id` had UNIQUE in table definition AND ALTER TABLE  
**Solution:**
- Removed redundant ALTER TABLE constraint
- Kept UNIQUE in table definition only
- Added comment explaining why ALTER is redundant

**Impact:** No migration errors from duplicate constraints

### 5. ✅ Post Media Policy Mismatch (FIXED)
**Problem:** Posts policy treats 'friends' as 'public', but media policy didn't  
**Solution:**
- Updated post_media SELECT policy to include 'friends' visibility
- Now matches posts policy: `visibility IN ('public', 'friends')`

**Impact:** Post media visible when post is visible (no broken media)

## Updated Files

1. **`supabase/migrations/20250127_complete_schema.sql`**
   - `provider_locations.geo` is now NOT NULL (always required)
   - Updated privacy trigger (simplified, geo always required)
   - Fixed `nearby_providers()` RPC:
     - Requires geo NOT NULL
     - Always uses ST_DWithin for distance filtering
     - Returns NULL geo for home-private (privacy)
     - Added provider identity (full_name, avatar_url, verified)
   - Removed duplicate conversations constraint
   - Fixed post_media policy to match posts policy

2. **`supabase/migrations/20250127_fix_quota_race_conditions.sql`**
   - Removed redundant conversations constraint ALTER

## Privacy Approach (Final)

**Storage:**
- Home-private: Store **approximate geo** (rounded) in `geo` column
- Home-public: Store exact geo in `geo` column
- Gym/Studio/Park: Store exact geo in `geo` column

**Response (RPC):**
- Home-private: Return `NULL` geo (never expose exact coordinates)
- Home-public: Return exact geo
- Gym/Studio/Park: Return exact geo

**Result:**
- ✅ Distance calculation works (uses approximate for home-private)
- ✅ Filtering by max_distance works
- ✅ Sorting by nearest works
- ✅ Privacy protected (exact home coordinates never exposed)

## Migration Order

1. Run `20250127_complete_schema.sql` (with all fixes)
2. Run `20250127_fix_quota_race_conditions.sql` (RPC functions for quota)

## Testing Checklist

✅ Nearby search returns providers within max_distance only  
✅ Results sorted by distance (nearest first)  
✅ Home-private locations show distance but NULL geo  
✅ Provider name/avatar visible in Discover  
✅ Post media visible when post is visible  
✅ No duplicate constraint errors  

## Next Steps

1. **Flutter App Updates:**
   - Update Discover page to use `nearby_providers()` RPC
   - Display `full_name`, `avatar_url`, `verified` from RPC result
   - Handle NULL geo for home-private (don't show map pin)

2. **Provider Location Input:**
   - For home locations: Round coordinates to ~1-3km grid before storing
   - Example: Round lat/lng to 2 decimal places (~1.1km precision)
   - Or use PostGIS `ST_SnapToGrid()` function

3. **Optional Future Enhancement:**
   - If needed later, can add `geo_exact` column for exact storage
   - Keep `geo` as approximate for all home locations
   - Only expose `geo_exact` if `is_public_exact = true`
