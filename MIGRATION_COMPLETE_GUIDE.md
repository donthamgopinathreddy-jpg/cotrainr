# Complete Migration Guide: Mock → Real Supabase

**Status:** Edge Functions + Flutter Services Generated  
**Next Steps:** Review, test, integrate

---

## Files Generated

### Edge Functions (TypeScript)
1. `supabase/functions/create-lead/index.ts` - Creates leads with quota enforcement
2. `supabase/functions/update-lead-status/index.ts` - Accept/decline leads, creates conversations
3. `supabase/functions/get-entitlements/index.ts` - Returns quota info

### Flutter Services
1. `lib/services/entitlement_service.dart` - Calls get-entitlements
2. `lib/services/leads_service.dart` - Calls create-lead, update-lead-status, queries leads
3. `lib/services/profile_role_service.dart` - Reads profiles.role

### Flutter Providers
1. `lib/providers/profile_role_provider.dart` - CurrentUser provider with role
2. `lib/providers/entitlements_provider.dart` - Entitlements provider
3. `lib/providers/leads_provider.dart` - Leads providers

### Router Updates
- `lib/router/app_router.dart` - Updated to use profiles.role, protect routes

---

## Critical Fixes Needed

### 1. Router Implementation Issue
The router redirect function cannot be async in GoRouter. Need to:
- Use synchronous role check OR
- Move role check to page level

**Fix:** Update `app_router.dart` redirect to be synchronous, check role in page initState instead.

### 2. VideoSessionsPage & CreateMeetingPage
These pages currently require `role` parameter. Need to:
- Remove role parameter
- Read role from `currentUserProvider` inside page

### 3. Discover Page Integration
Replace `_loadMockData()` with:
- Get user location (geolocator)
- Call `nearby_providers()` RPC
- Map results to `DiscoverItem`

### 4. Request Button Integration
In Discover page, replace mock request with:
- Call `LeadsService.createLead()`
- Show quota remaining
- Update UI based on lead status

### 5. Create Requests Page
New page for providers:
- List incoming leads
- Accept/decline buttons
- Call `LeadsService.updateLeadStatus()`

### 6. Messaging Integration
Update messaging pages to:
- Query `conversations` table
- Query `messages` by conversation_id
- Insert messages via Supabase

---

## Testing Checklist

1. ✅ Run SQL migration
2. ⚠️ Deploy Edge Functions
3. ⚠️ Test create-lead (quota enforcement)
4. ⚠️ Test update-lead-status (creates conversation)
5. ⚠️ Test get-entitlements
6. ⚠️ Test router guards (wrong role → redirect)
7. ⚠️ Test discover page (real providers)
8. ⚠️ Test request flow (client → provider → accept → chat)

---

## Next: Complete Integration

The Edge Functions and services are ready. Now integrate into UI:
1. Fix router (synchronous role check)
2. Update Discover page
3. Create Requests page
4. Update Messaging pages
5. Remove all `userMetadata['role']` references
