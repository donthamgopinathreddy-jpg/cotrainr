# Provider Location Map Picker — Audit

## 1. Current Files & Logic

| File | Purpose |
|------|---------|
| `lib/pages/profile/settings/service_locations_page.dart` | List of provider locations; Add/Edit/Delete; Set primary; Toggle active |
| `lib/pages/profile/provider_location_form_page.dart` | Add/Edit form: display name, location type, radius, **Pick on Map** (opens MapLocationPickerPage), read-only lat/lng |
| `lib/pages/profile/map_location_picker_page.dart` | Full-screen map (flutter_map + OSM); tap to place pin; Confirm returns LatLng |
| `lib/repositories/provider_locations_repository.dart` | CRUD via Supabase; `upsertLocation`, `fetchMyLocations`, `fetchNearbyProviders` (RPC) |
| `lib/models/provider_location_model.dart` | `ProviderLocation` model; `toJson()` sends `geo: 'POINT($longitude $latitude)'` |

## 2. Geo Write (Current)

- **Model** (`provider_location_model.dart:79`): `'geo': 'POINT($longitude $latitude)'` — plain WKT, no SRID
- **Flow**: Form → `ProviderLocation` → `toJson()` → repo `upsertLocation` → `.insert(json)` / `.update(json)`
- **DB**: `provider_locations.geo` is `GEOGRAPHY(Point, 4326) NOT NULL`
- **Issue**: Plain `POINT(lng lat)` may work; `SRID=4326;POINT(lng lat)` is more explicit and safer

## 3. Edit Flow

- **ServiceLocationsPage** → tap row → `_openLocationForm(context, ref, location)` → `ProviderLocationFormPage(location: location, onSaved: ...)`
- **onSaved**: `ref.invalidate(providerLocationsProvider)` then `Navigator.pop`
- **ProviderLocationsNotifier.upsertLocation** calls `repo.upsertLocation` then `refresh()` — list refreshes
- **Edit**: Form `initState` populates controllers from `widget.location` (lat, lng, display name, etc.)
- **Update**: Repo uses `.update(json).eq('id', location.id).eq('provider_id', ...)` — correct upsert behavior

## 4. Issues

1. **Geo format**: No SRID in WKT; prefer `SRID=4326;POINT(lng lat)` for consistency
2. **Map picker**: No "Use my current location" button; does not center on user GPS when available
3. **Form**: No "Use my current location" shortcut; Save enabled even when coords empty (validation runs on submit)
4. **Discover**: Uses `nearby_providers` RPC ✓; empty state could be clearer
5. **Permission handling**: Map picker does not request location for "Use my location"

## 5. What We Will Change

| Area | Change |
|------|--------|
| **Repository** | Add `_toPointWkt(lat, lng)` → `'SRID=4326;POINT($lng $lat)'`; override `json['geo']` in upsert |
| **Map picker** | Add "Use my current location" button; center on GPS if available, else existing location, else Hyderabad |
| **Form** | Add "Use my current location" shortcut; disable Save until form valid (display name + coords set) |
| **Discover / Nearby** | Add clearer empty state message; confirm RPC usage (no changes) |
| **Service locations** | Already refreshes; no change |

## 6. Exact Functions

| Function | File | Behavior |
|----------|------|----------|
| `fetchMyLocations()` | `provider_locations_repository.dart:16` | `from('provider_locations').select().eq('provider_id', uid)` |
| `upsertLocation()` | `provider_locations_repository.dart:39` | Builds json from `location.toJson()`, insert or update |
| `toJson()` | `provider_location_model.dart:73` | `'geo': 'POINT($longitude $latitude)'` |
| `_saveLocation()` | `provider_location_form_page.dart:59` | Validates, builds `ProviderLocation`, calls `upsertLocation` |
| `_openLocationForm()` | `service_locations_page.dart:207` | Pushes `ProviderLocationFormPage`, onSaved invalidates + pop |
| `fetchNearbyProviders()` | `provider_locations_repository.dart:134` | RPC `nearby_providers` |
| `_loadRealData()` | `discover_page.dart:67` | Geolocator + `fetchNearbyProviders` for trainers/nutritionists |
| `_loadNearbyPlaces()` | `nearby_preview_v3.dart:38` | Geolocator + `fetchNearbyProviders` |
