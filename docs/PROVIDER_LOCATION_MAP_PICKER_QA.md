# Provider Location Map Picker — QA Checklist

## Prerequisites

- App built and running (Android emulator or device)
- User logged in as trainer or nutritionist (provider role)
- Supabase backend with `provider_locations` table and `nearby_providers` RPC

---

## 1. Add New Location via Map Pick

- [ ] Navigate: Profile → Settings → Service Locations → Add Location
- [ ] Enter display name (e.g. "Downtown Gym")
- [ ] Select location type (e.g. Gym)
- [ ] Select service radius
- [ ] Tap **Pick on Map**
- [ ] Map opens; tap anywhere to place pin
- [ ] Tap **Confirm Location**
- [ ] Coordinates appear in form (read-only)
- [ ] Save button becomes enabled
- [ ] Tap **Add Location** (or **Save Changes**)
- [ ] Location appears in list; no errors

---

## 2. Use My Current Location

- [ ] Add Location → Tap **Use my location** (on form)
- [ ] Permission prompt appears (if not yet granted)
- [ ] Coordinates populate after permission granted
- [ ] Or: Pick on Map → Tap **Use my current location** in bottom sheet
- [ ] Map centers on user position; pin moves
- [ ] Confirm → coordinates appear in form
- [ ] Save succeeds

---

## 3. Edit Existing Location

- [ ] From Service Locations list, tap **Edit** on a location
- [ ] Form opens with existing data (name, type, radius, coords)
- [ ] Change display name or tap **Pick on Map**
- [ ] Map opens centered on existing location with pin
- [ ] Move pin or tap **Use my current location**
- [ ] Confirm → form updates
- [ ] Save → list refreshes with updated data
- [ ] Discover (as another user) shows updated location after refresh

---

## 4. Toggle Active → Disappears from Discover

- [ ] Add a location, ensure it is active (toggle ON)
- [ ] As client, open Discover; provider appears
- [ ] As provider, toggle location **Active** OFF
- [ ] As client, pull-to-refresh Discover
- [ ] Provider no longer appears

---

## 5. Home + is_public_exact=false → Still Discoverable

- [ ] Add location with type **Home**
- [ ] Confirm "Show Exact Location" is OFF (disabled for home)
- [ ] Save
- [ ] As client, open Discover
- [ ] Provider appears (by distance, geo masked in RPC response)
- [ ] Location string shows display name, not exact coordinates

---

## 6. Permission Denied Flow

- [ ] With location permission denied: Add Location → tap **Use my location**
- [ ] SnackBar or error message shown (e.g. "Location permission denied")
- [ ] In map picker: tap **Use my current location** → error shown
- [ ] User can still tap on map to pick manually
- [ ] No crash; graceful fallback

---

## 7. Android Emulator

- [ ] Run on Android emulator
- [ ] Set emulator location (Extended controls → Location)
- [ ] Add location via map pick
- [ ] Use my location works (uses emulator location)
- [ ] Save and list refresh work

---

## 8. Edge Cases

- [ ] New location: Save disabled until display name + coordinates set
- [ ] Loading states: spinner during "Use my location" and during save
- [ ] Error SnackBar on save failure
- [ ] Set primary / Delete / Toggle active still work from list
