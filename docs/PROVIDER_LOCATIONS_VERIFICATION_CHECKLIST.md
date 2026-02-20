# Provider Locations — Verification Checklist

After applying the migration and Dart changes, verify the following.

## 1. Geo Storage (non-null)

- [ ] **Insert a location** via the map picker (Settings → Service Locations → Add Location → Pick on Map).
- [ ] Confirm the location saves without error.
- [ ] In Supabase SQL Editor, run (replace `YOUR_USER_ID` with your provider's UUID):
  ```sql
  SELECT id, provider_id, display_name, geo IS NOT NULL AS geo_set, ST_AsText(geo) AS geo_wkt
  FROM provider_locations
  WHERE provider_id = 'YOUR_USER_ID'
  ORDER BY updated_at DESC
  LIMIT 5;
  ```
- [ ] `geo_set` is `true` and `geo_wkt` shows `POINT(lng lat)`.

## 2. nearby_providers RPC

- [ ] Call the RPC with valid params:
  ```sql
  SELECT * FROM nearby_providers(17.3850, 78.4867, 50.0, NULL, NULL)
  LIMIT 5;
  ```
- [ ] Rows return with `provider_id`, `full_name`, `avatar_url`, `distance_km`, etc.
- [ ] With `provider_types := ARRAY['trainer']::provider_type[]`, only trainers are returned.
- [ ] With `location_types := ARRAY['gym']::location_type[]`, only gym locations are returned.

## 3. Privacy (home + !is_public_exact masked)

- [ ] Create a **home** location with "Show Exact Location" OFF (default).
- [ ] Call `nearby_providers` and confirm the row for that location has `geo = NULL`.
- [ ] Create a **gym** location with "Show Exact Location" ON.
- [ ] Call `nearby_providers` and confirm the row has non-null `geo`.

## 4. Trainer update reflects in Discover

- [ ] As a trainer, add or edit a service location via map picker.
- [ ] Save and return to the Service Locations list.
- [ ] As a client (or another device), open the Discover tab.
- [ ] Confirm the trainer appears in the list with correct distance.
- [ ] Pull-to-refresh on Discover; results should update.

## 5. Map Picker UX

- [ ] Add Location → Pick on Map: map opens, tap to place pin, Confirm.
- [ ] Lat/lng fields populate and are read-only.
- [ ] Edit Location → Pick on Map: map centers on existing location.
- [ ] Save succeeds and list refreshes.

## 6. Permission & Empty States

- [ ] With location permission denied: error shows "Enable location to discover nearby providers" with Retry + Settings buttons.
- [ ] With permission granted but no providers nearby: "No providers near you" with hint to expand radius.
- [ ] Discover empty state: "No providers nearby" with hint about service locations.

## Files Changed

| File | Change |
|------|--------|
| `supabase/migrations/20250228_provider_locations_canonical.sql` | Canonical `nearby_providers` RPC |
| `lib/pages/profile/map_location_picker_page.dart` | New map picker page |
| `lib/pages/profile/provider_location_form_page.dart` | Map picker integration, read-only coords |
| `lib/widgets/home_v3/nearby_preview_v3.dart` | Use repo, UX hardening |
| `lib/pages/discover/discover_page.dart` | Empty state copy |
| `pubspec.yaml` | `flutter_map`, `latlong2` |

## RPC Signature (canonical)

```
nearby_providers(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance_km DOUBLE PRECISION DEFAULT 50.0,
  provider_types provider_type[] DEFAULT NULL,
  location_types location_type[] DEFAULT NULL
)
```

## Geo Write Format (Dart)

```dart
// provider_location_model.dart toJson()
'geo': 'POINT($longitude $latitude)'  // WKT: lng then lat
```

PostGIS accepts this; column is `GEOGRAPHY(Point, 4326) NOT NULL`.
