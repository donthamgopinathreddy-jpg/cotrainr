# Trainer Service Locations — End-to-End Audit & Patch Plan

## AUDIT RESULTS

### TASK A — Flutter Repo Audit

#### 1) Files and Screens

| File | Purpose |
|------|---------|
| `lib/pages/profile/settings_page.dart` | Settings screen; shows "Service Locations" row only when `_isProvider == true` (lines 261–277); navigates to `ServiceLocationsPage` |
| `lib/pages/profile/settings/service_locations_page.dart` | Service Locations list: add/edit/delete, set primary, toggle active |
| `lib/pages/profile/provider_location_form_page.dart` | Add/edit form: display name, location type, radius, **manual lat/lng text fields** (no map picker) |
| `lib/repositories/provider_locations_repository.dart` | Supabase CRUD + `fetchNearbyProviders` RPC |
| `lib/providers/provider_locations_provider.dart` | Riverpod `providerLocationsProvider`, `ProviderLocationsNotifier` |
| `lib/models/provider_location_model.dart` | `ProviderLocation` model, `LocationType` enum |
| `lib/pages/discover/discover_page.dart` | Discover page: uses `ProviderLocationsRepository.fetchNearbyProviders`, Geolocator for user location |
| `lib/widgets/home_v3/nearby_preview_v3.dart` | Home preview: calls `nearby_providers` RPC directly |

#### 2) Key Functions

| Function | File | Behavior |
|----------|------|----------|
| `fetchMyLocations()` | `provider_locations_repository.dart:16` | `from('provider_locations').select().eq('provider_id', uid)` |
| `upsertLocation()` | `provider_locations_repository.dart:39` | Insert or update `provider_locations`; sends `geo: 'POINT(lng lat)'` |
| `deleteLocation()` | `provider_locations_repository.dart:80` | Delete from `provider_locations` |
| `setPrimary()` | `provider_locations_repository.dart:97` | Update `is_primary` |
| `setActive()` | `provider_locations_repository.dart:114` | Update `is_active` |
| `fetchNearbyProviders()` | `provider_locations_repository.dart:134` | RPC `nearby_providers` with `user_lat`, `user_lng`, `max_distance_km`, `provider_types`, `location_types` |
| `_saveLocation()` | `provider_location_form_page.dart:57` | Validates lat/lng, builds `ProviderLocation`, calls `upsertLocation` |
| `_loadRealData()` | `discover_page.dart:67` | Gets `Geolocator.getCurrentPosition`, calls `fetchNearbyProviders` for trainers and nutritionists |

#### 3) Persistence

- **Persisted in Supabase** via `provider_locations` table.
- Repository uses `.from('provider_locations')` for CRUD.
- Discover uses `nearby_providers` RPC for discovery.

---

### TASK B — Supabase Audit

#### 1) Schema

| Table/Column | Migration | Details |
|--------------|-----------|---------|
| `provider_locations` | `20250127_provider_locations.sql`, `20250127_add_missing_tables_safe.sql` | id, provider_id, location_type, display_name, geo GEOGRAPHY(Point,4326), radius_km, is_public_exact, is_active, is_primary, created_at, updated_at |
| `location_type` enum | `20250127_provider_locations.sql` | home, gym, studio, park, other |
| `nearby_providers` RPC | `20250127_provider_locations.sql`, `20250127_add_missing_tables_safe.sql` | user_lat, user_lng, max_distance_km, provider_types, location_types |

#### 2) PostGIS

- **Enabled** in `20250127_complete_wipe_and_recreate.sql` and `20250127_complete_safe_migration.sql`: `CREATE EXTENSION IF NOT EXISTS "postgis"`.

#### 3) Indexes

| Index | Purpose |
|-------|---------|
| `idx_provider_locations_provider_id` | Lookup by provider |
| `idx_provider_locations_geo` | GIST on geo for `ST_DWithin` |
| `idx_provider_locations_is_active` | Filter active (partial) |
| `idx_provider_locations_unique_primary` | One primary per provider |

#### 4) RLS

| Policy | Table | Effect |
|--------|-------|--------|
| "Providers can insert their own locations" | provider_locations | INSERT where auth.uid() = provider_id |
| "Providers can update their own locations" | provider_locations | UPDATE where auth.uid() = provider_id |
| "Providers can delete their own locations" | provider_locations | DELETE where auth.uid() = provider_id |
| "Providers can select their own locations" | provider_locations | SELECT where auth.uid() = provider_id |

**Per SCHEMA_SECURITY_FIXES.md:** The policy "Users can select locations for discovery" was **dropped**. Clients have **no direct SELECT** on `provider_locations`. Discovery is only via `nearby_providers` RPC.

#### 5) Security

- **RPC:** `nearby_providers` is SECURITY DEFINER, masks geo for home+!is_public_exact.
- **Direct table:** Clients cannot SELECT `provider_locations`; RLS blocks it.
- **Coordinates:** RPC returns geo only when not home-private; otherwise NULL.

---

### TASK C — Data Model Choice

**Chosen: Model 2 — "Service locations" (multiple rows per trainer)**

**Reason:** The UI already supports multiple locations per trainer (add/edit/delete, primary, active). The schema and RPC are built for multiple locations. Model 1 would require a redesign of the list and form.

**Current schema matches Model 2.** No migration needed for the table structure. Optional improvements:

- Add `address` column (optional) for display.
- Ensure `nearby_providers` RPC signature matches Flutter (provider_types, location_types).

---

## ERRORS / RISKS

| # | Issue | Severity | Location |
|---|-------|----------|----------|
| 1 | **Manual lat/lng entry** — No map picker; users must type coordinates | High | `provider_location_form_page.dart:354` — TODO comment |
| 2 | **RPC param mismatch** — `20250127_provider_locations.sql` defines `nearby_providers(user_lat, user_lng, max_distance_km, location_types)` but Flutter/repo use `provider_types` | Medium | `provider_locations_repository.dart:147` vs `20250127_provider_locations.sql:167` |
| 3 | **Profiles join** — `add_missing_tables_safe` uses `COALESCE(pr.display_name, pr.first_name \|\| ' ' \|\| pr.last_name)` but profiles may only have `full_name` | Medium | `20250127_add_missing_tables_safe.sql:522` |
| 4 | **Centers tab empty** — Discover "Centers" tab uses `_centers` which is never populated | Low | `discover_page.dart:38, 222` |
| 5 | **Location permission denied** — Error message shown but no fallback (e.g. manual city/zip) | Medium | `discover_page.dart:86–104` |
| 6 | **Trainer with no location** — Empty Discover list; no explicit "no providers in area" vs "no locations set" | Low | discover_page.dart |

---

## PATCH PLAN

### Phase 1: Map Picker (Flutter)

1. Add `google_maps_flutter` or `flutter_map` + `latlong2` to `pubspec.yaml`.
2. Create `MapLocationPickerPage`:
   - Full-screen map
   - Tap to place pin
   - Confirm → return `(lat, lng, label?)`
   - Optional: reverse geocode for address
3. In `ProviderLocationFormPage`:
   - Replace manual lat/lng fields with "Pick on Map" button.
   - Open `MapLocationPickerPage`; on result, set `_latitudeController` and `_longitudeController`.
   - For edit: center map on existing lat/lng, show pin.

### Phase 2: Repository (no change needed)

- `ProviderLocationsRepository` already uses Supabase correctly.
- Ensure `fetchNearbyProviders` params match RPC: `user_lat`, `user_lng`, `max_distance_km`, `provider_types`, `location_types`.

### Phase 3: RPC Alignment (Supabase)

- Confirm `nearby_providers` has `provider_types` and `location_types` (as in `add_missing_tables_safe`).
- If an older migration defines a different signature, add a migration that creates/replaces the 5-arg version.

### Phase 4: Discover UX

- Add fallback when location permission denied: "Enter city or use current location" (manual lat/lng or geocoding).
- Add empty state: "No trainers in your area. Try expanding the search radius."

### Phase 5: Route Protection (optional)

- Protect `ServiceLocationsPage` so only providers can open it (e.g. redirect if `!isProvider`).

---

## DELIVERABLES

### 1) SQL Migration (RPC alignment)

If `nearby_providers` lacks `provider_types`, add migration `20250228_nearby_providers_align.sql`:

```sql
-- Ensure nearby_providers has provider_types param (align with Flutter)
CREATE OR REPLACE FUNCTION public.nearby_providers(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance_km DOUBLE PRECISION DEFAULT 50.0,
  provider_types provider_type[] DEFAULT NULL,
  location_types location_type[] DEFAULT NULL
)
RETURNS TABLE (
  provider_id UUID,
  location_id UUID,
  location_type location_type,
  display_name TEXT,
  geo GEOGRAPHY,
  radius_km NUMERIC,
  distance_km DOUBLE PRECISION,
  is_primary BOOLEAN,
  provider_type provider_type,
  specialization TEXT[],
  experience_years INTEGER,
  rating NUMERIC,
  total_reviews INTEGER,
  full_name TEXT,
  avatar_url TEXT,
  verified BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pl.provider_id,
    pl.id AS location_id,
    pl.location_type,
    pl.display_name,
    CASE WHEN pl.location_type = 'home' AND pl.is_public_exact = false THEN NULL ELSE pl.geo END,
    pl.radius_km,
    ST_Distance(pl.geo::geography, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography) / 1000.0,
    pl.is_primary,
    p.provider_type,
    p.specialization,
    p.experience_years,
    p.rating,
    p.total_reviews,
    pr.full_name,
    pr.avatar_path AS avatar_url,
    p.verified
  FROM public.provider_locations pl
  JOIN public.providers p ON p.user_id = pl.provider_id
  JOIN public.profiles pr ON pr.id = p.user_id
  WHERE pl.is_active = true
    AND pl.geo IS NOT NULL
    AND (provider_types IS NULL OR p.provider_type = ANY(provider_types))
    AND (location_types IS NULL OR pl.location_type = ANY(location_types))
    AND ST_DWithin(pl.geo::geography, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, (max_distance_km * 1000)::DOUBLE PRECISION)
  ORDER BY distance_km ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_providers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, provider_type[], location_type[]) TO authenticated;
```

### 2) Dart Repository (unchanged)

```dart
// provider_locations_repository.dart - fetchNearbyProviders (already correct)
Future<List<Map<String, dynamic>>> fetchNearbyProviders({
  required double userLat,
  required double userLng,
  double maxDistanceKm = 50.0,
  List<String>? providerTypes,
  List<LocationType>? locationTypes,
}) async {
  final response = await _supabase.rpc('nearby_providers', params: {
    'user_lat': userLat,
    'user_lng': userLng,
    'max_distance_km': maxDistanceKm,
    'provider_types': providerTypes,
    'location_types': locationTypes?.map((e) => e.value).toList(),
  });
  return (response as List).cast<Map<String, dynamic>>();
}
```

### 3) Map Picker Integration (snippet)

```dart
// In ProviderLocationFormPage - add button and callback
ElevatedButton.icon(
  onPressed: () async {
    final result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(builder: (_) => MapLocationPickerPage(
        initialLat: lat,
        initialLng: lng,
      )),
    );
    if (result != null && mounted) {
      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);
      });
    }
  },
  icon: Icon(Icons.map),
  label: Text('Pick on Map'),
)
```

### 4) UI Wiring

| Location | Change |
|----------|--------|
| `lib/pages/profile/provider_location_form_page.dart` | Replace Coordinates section with "Pick on Map" + optional manual override |
| `lib/pages/discover/discover_page.dart` | Add fallback UX when permission denied; refine empty state message |
| New: `lib/pages/profile/map_location_picker_page.dart` | Map picker screen |

---

## Summary

| Item | Status |
|------|--------|
| Persistence | ✅ Supabase `provider_locations` |
| RLS | ✅ Provider-only write; no client direct SELECT |
| Discovery | ✅ `nearby_providers` RPC with geo masking |
| PostGIS | ✅ Enabled |
| GIST index | ✅ On geo |
| Map picker | ❌ Manual lat/lng only |
| RPC params | ⚠️ Verify provider_types in DB |
| Location permission fallback | ❌ None |
| Empty state | ⚠️ Generic "No results" |
