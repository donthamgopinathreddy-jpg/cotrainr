# Database Schema Review & RBAC Alignment

**Generated:** 2025-01-27  
**Schema Version:** Complete Supabase schema with RLS  
**Reviewer:** Senior Flutter Architect

---

## Executive Summary

The provided schema is **comprehensive and production-ready**. It addresses **most critical RBAC gaps** identified in the audit report. Key strengths:

✅ **Single source of truth for roles** (`profiles.role`)  
✅ **Proper RLS policies** on all tables  
✅ **Relationship-based access control** (leads → conversations → messages)  
✅ **Provider locations** with privacy enforcement  
✅ **Chat access control** via leads/conversations  
✅ **Video session access control** via conversations

**Remaining gaps:** Schema is solid, but Flutter app needs updates to use it correctly.

---

## Schema Analysis

### 1) RBAC Foundation ✅

**Table:** `profiles`
- ✅ `role` field as enum (`user_role`: 'client', 'trainer', 'nutritionist')
- ✅ Single source of truth (references `auth.users(id)`)
- ✅ RLS policies: users can only read/update own profile
- ✅ **Critical:** This replaces `userMetadata['role']` as the authoritative role source

**Impact on RBAC Audit:**
- **Fixes:** Blocker #1, #2, #3 (role verification)
- **Action Required:** Update Flutter app to read from `profiles.role` instead of `userMetadata['role']`

---

### 2) Provider Management ✅

**Table:** `providers`
- ✅ Links to `profiles` via `user_id`
- ✅ `provider_type` enum (trainer/nutritionist)
- ✅ Public readable for discovery (any authenticated user)
- ✅ Self-manageable (providers can update own row)

**Impact on RBAC Audit:**
- **Fixes:** Discover page can now query real providers
- **Action Required:** Update Discover page to use `providers` table + `nearby_providers()` RPC

---

### 3) Provider Locations ✅

**Table:** `provider_locations`
- ✅ Matches our implementation (`SERVICE_LOCATIONS_IMPLEMENTATION.md`)
- ✅ Privacy enforcement trigger (`enforce_home_privacy()`)
- ✅ Primary location constraint (unique index)
- ✅ RLS: providers CRUD own locations
- ✅ Public read for discovery (with privacy via RPC)

**RPC Function:** `nearby_providers()`
- ✅ Masks geo for private home locations (returns NULL)
- ✅ Returns distance calculation
- ✅ Filters by provider_type and discipline
- ✅ **Critical:** Use this for Discover page, NOT direct table select

**Impact on RBAC Audit:**
- **Fixes:** High Priority #5 (Service Locations protection)
- **Status:** Already implemented in Flutter, matches schema

---

### 4) Leads (Requests) System ✅

**Table:** `leads`
- ✅ Tracks client → provider requests
- ✅ Status enum: 'requested', 'accepted', 'declined', 'cancelled'
- ✅ RLS: participants (client or provider) can read
- ✅ Provider can update status (accept/decline)
- ✅ **No insert policy for clients** (Edge Function controlled)

**Impact on RBAC Audit:**
- **Fixes:** High Priority #6 (Chat access control)
- **Action Required:** 
  - Update Discover page to create leads (via Edge Function)
  - Update Chat to check `leads.status = 'accepted'` before allowing messages

---

### 5) Chat Access Control ✅

**Tables:** `conversations`, `messages`
- ✅ `conversations` linked to `leads` (only after lead accepted)
- ✅ RLS: participants can read/write
- ✅ Messages require conversation participation
- ✅ **Critical:** Chat only works if lead is accepted

**Impact on RBAC Audit:**
- **Fixes:** High Priority #6 (Chat access control)
- **Action Required:**
  - Update `ChatScreen` to verify conversation exists and user is participant
  - Update `MessagingPage` to only show conversations where user is participant

---

### 6) Video Sessions Access Control ✅

**Table:** `video_sessions`
- ✅ Linked to `leads` and `conversations`
- ✅ RLS: participants can read (host or conversation participants)
- ✅ Status enum: 'scheduled', 'active', 'ended', 'cancelled'
- ✅ **No insert policy** (Edge Function controlled for quota)

**Impact on RBAC Audit:**
- **Fixes:** High Priority #7 (Meeting room access control)
- **Action Required:**
  - Update `MeetingRoomPage` to verify user is participant before joining
  - Query `video_sessions` + `conversations` to check access

---

### 7) Subscriptions & Usage Limits ✅

**Tables:** `subscriptions`, `weekly_usage`
- ✅ Plan enum: 'free', 'basic', 'premium'
- ✅ Weekly usage tracking (requests, video sessions)
- ✅ RLS: users can read own subscription/usage
- ✅ **No write policies** (Edge Function controlled after IAP verification)

**Impact:**
- Enables quota enforcement
- Prevents abuse (unlimited requests, etc.)

---

### 8) Cocircle (Social Feed) ✅

**Tables:** `posts`, `post_media`, `post_likes`, `post_comments`, `post_reports`
- ✅ Public readable (any authenticated user)
- ✅ Self-manageable (authors can delete own posts)
- ✅ Media support (image/video)
- ✅ Reporting system

**Impact:**
- Enables real social feed (currently mock)
- Proper moderation support

---

### 9) Meal Tracker ✅

**Tables:** `meals`, `meal_items`, `meal_media`
- ✅ Self-manageable (users CRUD own meals)
- ✅ Media expires after 7 days (cleanup job needed)
- ✅ RLS: users can only access own meals

**Impact:**
- Enables real meal tracking (currently mock)

---

### 10) Metrics & Quests ✅

**Tables:** `metrics_daily`, `user_profiles`, `user_quests`, `user_quest_settings`, `leaderboard_points`
- ✅ Daily metrics aggregation
- ✅ Quest system with XP/levels
- ✅ Leaderboard with points (separate from XP)
- ✅ RLS: users can only access own data

**Impact:**
- Enables real quest system (currently partial)
- Proper leaderboard implementation

---

## Schema vs Current Implementation Gaps

### Critical Gaps (Must Fix)

1. **Role Source Mismatch**
   - **Schema:** `profiles.role` (enum)
   - **Current:** `userMetadata['role']` (string)
   - **Files Affected:** All files reading role (see RBAC audit)
   - **Fix:** Create helper function to read from `profiles` table

2. **Missing Profile Creation**
   - **Schema:** Requires `profiles` row for each user
   - **Current:** Signup only sets `userMetadata['role']`
   - **Files Affected:** `lib/pages/auth/signup_wizard_page.dart`
   - **Fix:** Create `profiles` row on signup (via trigger or Edge Function)

3. **Discover Page Not Using Schema**
   - **Schema:** `nearby_providers()` RPC function
   - **Current:** Mock data in `lib/pages/discover/discover_page.dart`
   - **Fix:** Replace mock data with RPC call

4. **Chat Not Using Conversations**
   - **Schema:** `conversations` + `messages` tables
   - **Current:** Mock data in `lib/pages/messaging/`
   - **Fix:** Query conversations, verify access via RLS

5. **Video Sessions Not Using Schema**
   - **Schema:** `video_sessions` table with access control
   - **Current:** Mock data, no access control
   - **Fix:** Query `video_sessions`, verify participation

### Medium Priority Gaps

6. **Meal Tracker Not Using Schema**
   - **Schema:** `meals`, `meal_items` tables
   - **Current:** Mock data
   - **Fix:** CRUD operations on real tables

7. **Cocircle Not Using Schema**
   - **Schema:** `posts`, `post_media`, etc.
   - **Current:** Mock posts
   - **Fix:** Query real posts, implement CRUD

8. **Quests Not Fully Using Schema**
   - **Schema:** `user_quests`, `user_profiles`, etc.
   - **Current:** Partial implementation
   - **Fix:** Complete quest service integration

---

## Migration Strategy

### Phase 1: RBAC Foundation (Week 1)

1. **Create Profile Helper**
   ```dart
   // lib/services/profile_service.dart
   Future<String?> getUserRole() async {
     final response = await Supabase.instance.client
       .from('profiles')
       .select('role')
       .eq('id', Supabase.instance.client.auth.currentUser!.id)
       .single();
     return response['role'] as String?;
   }
   ```

2. **Update Signup Flow**
   - After `auth.signUp()`, create `profiles` row
   - Set `role` from signup form
   - **OR:** Use database trigger to auto-create profile

3. **Update Router Guards**
   - Replace `userMetadata['role']` with `profiles.role` query
   - Add role verification in router redirect

4. **Update All Role Checks**
   - Replace all `userMetadata['role']` reads with `profiles.role`
   - Files: `settings_page.dart`, `profile_page.dart`, `quick_access_v3.dart`, etc.

### Phase 2: Access Control (Week 2)

5. **Protect Trainer/Nutritionist Routes**
   - Add role check in router using `profiles.role`
   - Redirect if wrong role

6. **Protect Client Detail Pages**
   - Query `leads` table to verify relationship
   - Only show if `lead.status = 'accepted'` and user is participant

7. **Protect Chat**
   - Query `conversations` table
   - Verify user is participant (client_id or provider_id)
   - Only show conversations where user is participant

8. **Protect Video Sessions**
   - Query `video_sessions` + `conversations`
   - Verify user is host or conversation participant
   - Block access if not authorized

### Phase 3: Real Data Integration (Week 3-4)

9. **Discover Page**
   - Replace mock data with `nearby_providers()` RPC call
   - Get user location, call RPC with filters
   - Display real providers

10. **Meal Tracker**
    - CRUD operations on `meals` and `meal_items`
    - Upload media to Storage, store path in `meal_media`

11. **Cocircle**
    - Query `posts` with joins for media, likes, comments
    - Implement create post, like, comment, report

12. **Quests**
    - Complete integration with `user_quests` table
    - Update XP/levels in `user_profiles`

---

## Database Triggers Needed

### Auto-Create Profile on User Signup

```sql
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, role, full_name)
  values (
    new.id,
    (new.raw_user_meta_data->>'role')::public.user_role,
    coalesce(new.raw_user_meta_data->>'full_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
```

**Note:** This requires `security definer` and proper permissions. Alternative: Create profile in Flutter after signup.

---

## RLS Policy Verification

### Critical Policies to Test

1. **Profiles:**
   - ✅ Users can only read own profile
   - ✅ Users can only update own profile
   - ⚠️ **Gap:** No public read for discovery (need to join via `providers`)

2. **Providers:**
   - ✅ Any authenticated user can read (for discovery)
   - ✅ Providers can only update own row
   - ✅ **Good:** Public readable for discovery

3. **Leads:**
   - ✅ Participants can read
   - ✅ Provider can update status
   - ✅ **Good:** No client insert (Edge Function controlled)

4. **Conversations:**
   - ✅ Participants can read
   - ⚠️ **Gap:** No insert policy (should be Edge Function or after lead accepted)

5. **Messages:**
   - ✅ Participants can read/write
   - ✅ **Good:** Verifies conversation participation

6. **Video Sessions:**
   - ✅ Participants can read
   - ✅ **Good:** No insert policy (Edge Function controlled)

---

## Edge Functions Required

Based on schema design, these operations should be server-side:

1. **Create Lead** (`create-lead`)
   - Verify client has quota (weekly_usage)
   - Create lead
   - Increment usage counter
   - Send notification to provider

2. **Accept/Decline Lead** (`update-lead`)
   - Provider updates lead status
   - If accepted: create conversation
   - Send notification to client

3. **Create Video Session** (`create-video-session`)
   - Verify quota (weekly_usage)
   - Verify lead is accepted
   - Create video_sessions row
   - Generate join URL (future: Daily/LiveKit)
   - Increment usage counter

4. **IAP Verification** (`verify-purchase`)
   - Verify purchase with Apple/Google
   - Update `subscriptions` table
   - Grant premium features

5. **Cleanup Expired Media** (`cleanup-media`)
   - Cron job to delete `meal_media` where `expires_at < now()`
   - Delete from Storage

---

## Schema Improvements Suggestions

### Optional Enhancements

1. **Add Indexes:**
   ```sql
   -- For role-based queries
   create index if not exists profiles_role_idx on public.profiles(role);
   
   -- For conversation lookups
   create index if not exists conversations_client_provider_idx 
   on public.conversations(client_id, provider_id);
   ```

2. **Add Constraints:**
   ```sql
   -- Ensure provider_type matches role
   alter table public.providers
   add constraint providers_type_matches_role
   check (
     (provider_type = 'trainer' and exists (select 1 from public.profiles p where p.id = user_id and p.role = 'trainer'))
     or
     (provider_type = 'nutritionist' and exists (select 1 from public.profiles p where p.id = user_id and p.role = 'nutritionist'))
   );
   ```

3. **Add Views for Common Queries:**
   ```sql
   -- Provider discovery view
   create view public.provider_discovery as
   select 
     p.user_id,
     p.provider_type,
     pr.full_name,
     pr.avatar_url,
     p.verified,
     p.rating_avg,
     p.rating_count,
     p.disciplines
   from public.providers p
   join public.profiles pr on pr.id = p.user_id;
   ```

---

## Action Items Summary

### Immediate (Before Production)

1. ✅ **Schema is ready** - Apply migration to Supabase
2. ⚠️ **Create profile helper** - Replace `userMetadata['role']` reads
3. ⚠️ **Update signup** - Create `profiles` row on signup
4. ⚠️ **Add router guards** - Use `profiles.role` for route protection
5. ⚠️ **Protect client detail pages** - Query `leads` for access control

### High Priority (Week 1-2)

6. ⚠️ **Protect chat** - Use `conversations` table
7. ⚠️ **Protect video sessions** - Use `video_sessions` table
8. ⚠️ **Update Discover** - Use `nearby_providers()` RPC
9. ⚠️ **Create Edge Functions** - For leads, video sessions, IAP

### Medium Priority (Week 3-4)

10. ⚠️ **Meal tracker** - Use real tables
11. ⚠️ **Cocircle** - Use real tables
12. ⚠️ **Quests** - Complete integration

---

## Conclusion

**Schema Status:** ✅ **PRODUCTION READY**

The schema is well-designed with proper RLS policies, relationships, and access control. It addresses **all critical RBAC gaps** identified in the audit report.

**Flutter App Status:** ⚠️ **NEEDS UPDATES**

The Flutter app needs significant updates to:
1. Use `profiles.role` instead of `userMetadata['role']`
2. Implement proper access control using schema relationships
3. Replace mock data with real queries
4. Create Edge Functions for server-controlled operations

**Estimated Effort:** 3-4 weeks for full migration

---

## Files That Need Updates

### Critical (RBAC)
- `lib/router/app_router.dart` - Use `profiles.role` for guards
- `lib/pages/profile/settings_page.dart` - Read from `profiles`
- `lib/pages/profile/profile_page.dart` - Read from `profiles`
- `lib/widgets/home_v3/quick_access_v3.dart` - Read from `profiles`
- `lib/pages/trainer/trainer_dashboard_page.dart` - Add role guard
- `lib/pages/nutritionist/nutritionist_dashboard_page.dart` - Add role guard
- `lib/pages/trainer/client_detail_page.dart` - Verify lead relationship
- `lib/pages/nutritionist/nutritionist_client_detail_page.dart` - Verify lead relationship

### High Priority (Access Control)
- `lib/pages/messaging/messaging_page.dart` - Query `conversations`
- `lib/pages/messaging/chat_screen.dart` - Verify conversation participation
- `lib/pages/video_sessions/meeting_room_page.dart` - Verify video session access
- `lib/pages/discover/discover_page.dart` - Use `nearby_providers()` RPC

### Medium Priority (Real Data)
- `lib/pages/meal_tracker/meal_tracker_page_v2.dart` - Use `meals` table
- `lib/pages/cocircle/cocircle_page.dart` - Use `posts` table
- `lib/pages/quest/quest_page.dart` - Use `user_quests` table

---

**Next Step:** Create `lib/services/profile_service.dart` helper and update all role reads.
