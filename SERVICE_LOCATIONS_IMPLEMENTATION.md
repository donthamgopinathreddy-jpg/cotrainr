# Service Locations Implementation Guide

**Date:** 2025-01-27  
**Feature:** Service Locations Management for Trainers & Nutritionists

---

## Overview

This implementation adds complete service location management for trainers and nutritionists, allowing them to add/edit/delete multiple service locations with privacy controls. Locations are integrated with the Discover page for nearby search.

---

## Step-by-Step Implementation

### 1. Database Migration

**File:** `supabase/migrations/20250127_provider_locations.sql`

**What it does:**
- Creates `location_type_enum` (home, gym, studio, park, other)
- Creates `provider_locations` table with all required fields
- Creates indexes for performance (provider_id, geo spatial index, is_active)
- Enforces unique primary location per provider
- Creates triggers:
  - Auto-update `updated_at` timestamp
  - Enforce home location privacy (is_public_exact must be false for home)
  - Handle primary location updates (auto-unset others)
- Creates RLS policies:
  - Providers can CRUD their own locations
  - Authenticated users can read active locations for discovery (with privacy protection)
- Creates `provider_locations_public` view that masks home location geo
- Creates `nearby_providers()` RPC function for efficient spatial queries

**To apply:**
1. Run this SQL in Supabase SQL Editor or via migration tool
2. Verify table and policies are created correctly

---

### 2. Data Model

**File:** `lib/models/provider_location_model.dart`

**What it does:**
- Defines `ProviderLocation` class with all fields
- Defines `LocationType` enum with display names and icons
- Handles Supabase geo field parsing (Point format)
- Provides `fromJson()` and `toJson()` for Supabase integration
- Provides `copyWith()` for immutable updates

**Key features:**
- Parses PostGIS `POINT(lng lat)` format from Supabase
- Handles null geo for private home locations
- Type-safe enum for location types

---

### 3. Repository Layer

**File:** `lib/repositories/provider_locations_repository.dart`

**What it does:**
- Abstracts all Supabase queries
- Provides methods:
  - `fetchMyLocations()` - Get current provider's locations
  - `upsertLocation()` - Insert or update location
  - `deleteLocation()` - Delete a location
  - `setPrimary()` - Set location as primary
  - `setActive()` - Toggle active status
  - `fetchNearbyProviders()` - Public API for discovery (uses RPC)

**Key features:**
- Enforces authentication (checks current user)
- Automatically sets provider_id to current user
- Enforces home location privacy in upsert
- Uses RPC function for efficient spatial queries

---

### 4. Riverpod Provider

**File:** `lib/providers/provider_locations_provider.dart`

**What it does:**
- Provides `ProviderLocationsRepository` instance
- Provides `ProviderLocationsNotifier` (AsyncNotifier) for state management
- Handles async loading, refreshing, and mutations
- Auto-refreshes after mutations

**Usage:**
```dart
// Watch locations
final locationsAsync = ref.watch(providerLocationsProvider);

// Mutate
await ref.read(providerLocationsProvider.notifier).upsertLocation(location);
```

---

### 5. Settings Page Integration

**File:** `lib/pages/profile/settings_page.dart` (MODIFIED)

**Changes:**
- Added `_userRole` getter to read role from Supabase user metadata
- Added `_isProvider` getter to check if user is trainer/nutritionist
- Added "Service Locations" row in Account section (only shown for providers)
- Navigates to `ServiceLocationsPage` when tapped

**Lines modified:**
- Added imports (line 16)
- Added role getters (after line 29)
- Added Service Locations row in Account section (after Edit Profile row)

---

### 6. Service Locations List Page

**File:** `lib/pages/profile/settings/service_locations_page.dart`

**What it does:**
- Displays list of provider's locations
- Shows location cards with:
  - Type icon, display name, type name
  - Primary badge (if primary)
  - Active toggle switch
  - Radius and coordinates
  - Privacy warning for home locations
- Actions:
  - Edit location
  - Set as primary
  - Delete location
  - Toggle active status
- Empty state when no locations
- Error state with retry
- "Add Location" button at bottom

**Key features:**
- Uses Riverpod `AsyncValue` for loading/error states
- Auto-refreshes after mutations
- Shows privacy warning for home locations
- Confirmation dialog for delete

---

### 7. Location Form Page

**File:** `lib/pages/profile/provider_location_form_page.dart`

**What it does:**
- Form for adding/editing locations
- Fields:
  - Display name (text input, required)
  - Location type (pill selector: home, gym, studio, park, other)
  - Service radius (pill selector: 2, 5, 10, 15, 20 km)
  - Coordinates (lat/lng text inputs, required)
  - Show exact location toggle (disabled for home)
- Validation:
  - Display name required
  - Lat/lng required and in valid ranges
  - Home locations force is_public_exact=false
- Saves to Supabase via repository
- Shows loading state during save

**Key features:**
- TODO comment for map picker integration
- Enforces home location privacy (disables toggle, shows warning)
- Validates coordinate ranges
- Handles both insert and update

---

### 8. Discover Page Integration Notes

**File:** `lib/pages/discover/discover_page.dart` (MODIFIED)

**Changes:**
- Added TODO comment in `_loadMockData()` method (line ~61)
- Documents how to integrate with `ProviderLocationsRepository.fetchNearbyProviders()`
- Notes about privacy handling (home locations without is_public_exact)

**Next steps for full integration:**
1. Get user's current location using `geolocator`
2. Call `ProviderLocationsRepository.fetchNearbyProviders()` with:
   - userLat, userLng
   - maxDistanceKm (from filter)
   - locationTypes (optional filter)
3. Join results with provider profiles table to get name, avatar, rating
4. Display in discover cards:
   - For home locations (is_public_exact=false): show display_name only, no exact pin
   - For other types or is_public_exact=true: show exact coordinates
5. Calculate and display distance

---

## File Summary

### New Files Created:
1. `supabase/migrations/20250127_provider_locations.sql` - Database schema
2. `lib/models/provider_location_model.dart` - Data model
3. `lib/repositories/provider_locations_repository.dart` - Repository layer
4. `lib/providers/provider_locations_provider.dart` - Riverpod provider
5. `lib/pages/profile/settings/service_locations_page.dart` - List page
6. `lib/pages/profile/provider_location_form_page.dart` - Form page

### Modified Files:
1. `lib/pages/profile/settings_page.dart` - Added Service Locations row
2. `lib/pages/discover/discover_page.dart` - Added integration TODO

---

## Testing Checklist

### Database:
- [ ] Run migration SQL in Supabase
- [ ] Verify table exists with correct schema
- [ ] Verify RLS policies are active
- [ ] Test RPC function `nearby_providers()` with sample data
- [ ] Verify triggers work (home privacy, primary location)

### Flutter:
- [ ] Settings page shows "Service Locations" for trainer/nutritionist
- [ ] Settings page hides "Service Locations" for client
- [ ] Can add new location
- [ ] Can edit existing location
- [ ] Can delete location (with confirmation)
- [ ] Can toggle active status
- [ ] Can set primary location (only one primary)
- [ ] Home locations enforce is_public_exact=false
- [ ] Form validation works (required fields, coordinate ranges)
- [ ] Error handling works (network errors, auth errors)

---

## Known Limitations & TODOs

1. **Map Picker:** Currently uses manual lat/lng input. To add map picker:
   - Add `google_maps_flutter` or `flutter_map` package
   - Replace coordinate text fields with map widget
   - Allow user to tap on map to set location

2. **Discover Integration:** Currently uses mock data. To complete:
   - Implement `fetchNearbyProviders()` call in Discover page
   - Join with provider profiles table
   - Handle privacy (home locations)
   - Calculate and display distances

3. **Location Validation:** Could add:
   - Reverse geocoding to auto-fill display_name
   - Address lookup
   - Map preview in form

---

## Security Notes

✅ **Implemented:**
- RLS policies enforce provider can only modify own locations
- Home locations always have is_public_exact=false (enforced by trigger)
- Public discovery policy hides exact geo for private home locations
- Authentication required for all operations

⚠️ **Consider:**
- Rate limiting on location creation (prevent abuse)
- Validation of coordinate ranges (already done in form)
- Audit log for location changes (optional)

---

## Usage Examples

### Adding a Location (Provider):
1. Go to Settings → Service Locations
2. Tap "Add Location"
3. Enter display name (e.g., "Gachibowli")
4. Select location type (e.g., "Gym")
5. Select radius (e.g., "5 km")
6. Enter coordinates (or use map picker when implemented)
7. Toggle "Show Exact Location" if desired (disabled for home)
8. Tap "Add Location"

### Setting Primary Location:
1. Go to Settings → Service Locations
2. Find location to set as primary
3. Tap "Set Primary" button
4. Other primary locations are automatically unset

### Discovery (Future):
1. User opens Discover page
2. App gets user's current location
3. Calls `fetchNearbyProviders()` with user location
4. Results show providers within radius
5. Home locations show display_name only (no exact pin)

---

## Dependencies

**No new dependencies required** - Uses existing:
- `supabase_flutter` (already in pubspec.yaml)
- `flutter_riverpod` (already in pubspec.yaml)
- `geolocator` (already in pubspec.yaml for location)

**Optional for future:**
- `google_maps_flutter` or `flutter_map` for map picker
- `geocoding` for reverse geocoding (address lookup)

---

## Database Schema Reference

```sql
provider_locations:
  - id: uuid (PK)
  - provider_id: uuid (FK to auth.users)
  - location_type: enum (home/gym/studio/park/other)
  - display_name: text
  - geo: geography(Point, 4326)
  - radius_km: numeric(5,2)
  - is_public_exact: boolean (default false)
  - is_active: boolean (default true)
  - is_primary: boolean (default false)
  - created_at: timestamptz
  - updated_at: timestamptz
```

---

## RPC Function Usage

```dart
// Example: Find providers within 50km
final repo = ProviderLocationsRepository();
final nearby = await repo.fetchNearbyProviders(
  userLat: 17.3850,
  userLng: 78.4867,
  maxDistanceKm: 50.0,
  locationTypes: [LocationType.gym, LocationType.studio],
);

// Results include:
// - provider_id
// - location_id
// - location_type
// - display_name
// - geo (null for private home locations)
// - radius_km
// - distance_km (calculated)
// - is_primary
```

---

## Error Handling

All repository methods throw `Exception` with descriptive messages:
- "User not authenticated" - No current user
- "Failed to fetch locations: ..." - Query error
- "Failed to save location: ..." - Insert/update error
- "Failed to delete location: ..." - Delete error

UI catches and displays errors via SnackBar.

---

## Next Steps

1. **Run migration** in Supabase dashboard
2. **Test in Flutter** - Settings page should show "Service Locations" for trainers/nutritionists
3. **Add test data** - Create a few locations via the form
4. **Test RLS** - Verify providers can only see/edit their own locations
5. **Integrate Discover** - Replace mock data with real `fetchNearbyProviders()` call
6. **Add map picker** (optional) - Replace manual coordinate input

---

## Support

For issues:
- Check Supabase logs for RLS policy violations
- Verify user role is set correctly in user metadata
- Check that migration was applied successfully
- Verify geo field format in Supabase (should be PostGIS Point)
