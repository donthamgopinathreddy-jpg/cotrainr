# Trainer–Nutritionist–Client Working Model

## 1. What Already Exists in Repo

### Files & Routes

| File | Route / Usage | Current Behavior |
|------|---------------|------------------|
| **Trainer** | | |
| `lib/pages/trainer/trainer_dashboard_page.dart` | `/trainer/dashboard` | Bottom nav: Home, My Clients, Quest, Cocircle, Profile |
| `lib/pages/trainer/trainer_home_page.dart` | Tab 0 of dashboard | Trainer home (placeholder) |
| `lib/pages/trainer/trainer_my_clients_page.dart` | Tab 1 "My Clients" | **Mock data only** – `_myClients`, `_pendingRequests` from `_loadMockData()` |
| `lib/pages/trainer/client_detail_page.dart` | `/clients/:id` | Tabs: Overview, Metrics, Workouts, Meals, Sessions, Notes. **All mock** – steps, calories, water, BMI, notes. Actions: Message, Assign Plan, Book Session, Send Reminder |
| `lib/pages/trainer/create_client_page.dart` | Not routed | Add-client UI with mock data; imported for `ClientItem` model |
| `lib/pages/trainer/become_trainer_page.dart` | `/trainer/become` | Onboarding flow |
| `lib/pages/trainer/verification_submission_page.dart` | `/verification` | Verification flow |
| **Nutritionist** | | |
| `lib/pages/nutritionist/nutritionist_dashboard_page.dart` | `/nutritionist/dashboard` | Similar structure to trainer |
| `lib/pages/nutritionist/nutritionist_my_clients_page.dart` | Tab 1 | **Mock data only** – same pattern as trainer |
| `lib/pages/nutritionist/nutritionist_client_detail_page.dart` | `/nutritionist/clients/:id` | Tabs: Profile, Diet Plans, Sessions, Notes. **Mock** – diet plans, sessions, notes. Message button → `MessagesRepository.createOrFindConversation` |
| **Client / Discover** | | |
| `lib/pages/discover/discover_page.dart` | Tab 1 of home (clients) or Discover (clients) | Real: `nearby_providers` RPC, trainers/nutritionists. **Request button does NOT call LeadsService** – only sets `_requestStatus[item.id] = 'pending'` locally (TODO) |
| `lib/pages/home/home_shell_page.dart` | `/home` | Clients: Discover, Quest, Cocircle, Profile. Providers: My Clients (TrainerMyClientsPage/NutritionistMyClientsPage), Quest, Cocircle, Profile |
| **Leads & Messaging** | | |
| `lib/services/leads_service.dart` | — | `createLead(providerId, message)` → Edge `create-lead`, `updateLeadStatus(leadId, status)` → Edge `update-lead-status`, `getMyLeads()`, `getIncomingLeads()` |
| `lib/providers/leads_provider.dart` | — | `leadsProvider`, `incomingLeadsProvider` – **not used anywhere in UI** |
| `lib/repositories/messages_repository.dart` | — | `createOrFindConversation(otherUserId)` – creates cocircle conv (client_id + other_user_id) or finds client-provider. Used by ClientDetailPage, NutritionistClientDetailPage |
| **Data** | | |
| `lib/repositories/metrics_repository.dart` | — | Direct RLS: `metrics_daily` by `user_id`, `date` |
| `lib/repositories/meal_repository.dart` | — | Direct RLS: `meals`, `meal_items`, `nutrition_goals` by `user_id`, `consumed_date` |
| `lib/services/profile_role_service.dart` | — | Fetches `profiles` (role: client/trainer/nutritionist) |

### Supabase Tables (Existing)

| Table | Purpose | RLS |
|-------|---------|-----|
| `leads` | client_id, provider_id, provider_type, status (requested/accepted/declined/cancelled) | Participants view; providers update |
| `conversations` | lead_id (nullable), client_id, provider_id (nullable), other_user_id (cocircle) | Participants view; insert for cocircle |
| `messages` | conversation_id, sender_id, content | Participants only |
| `providers` | user_id, provider_type (trainer/nutritionist), verified, rating | RLS |
| `profiles` | id, role, full_name, avatar_url, etc. | RLS |
| `metrics_daily` | user_id, date, steps, calories_burned, distance_km, water_intake_liters | Own row only |
| `meals` | user_id, meal_type, consumed_at, consumed_date | Own rows only |
| `meal_items` | meal_id, food_name, quantity, unit, calories, protein, carbs, fat, fiber | Via meals RLS |
| `meal_media` | meal_id, media_url, media_kind | Via meals RLS (no expires_at) |

### Edge Functions

| Function | Purpose |
|----------|---------|
| `create-lead` | Calls `create_lead_tx` RPC (quota, inserts lead) |
| `update-lead-status` | Calls `update_lead_status_tx` RPC (accept/decline, creates conversation) |

### Gaps

1. **Discover Request** – Does not call `LeadsService.createLead()`; only local state.
2. **Trainer/Nutritionist My Clients** – Mock data; not wired to `leads` (accepted) or `incomingLeadsProvider`.
3. **Client Detail** – Metrics, Meals, Workouts, Notes all mock; no coach access to client data.
4. **No coach–client link table** – `leads` with status=accepted is the only link; no explicit `coach_clients` for access control.
5. **meal_media** – No `expires_at`; no storage bucket; UI stores local paths only.
6. **No diet_plans, workout_plans, workout_sessions, consultation_notes** tables.

---

## 2. Recommended Working Model

### A) Relationship Lifecycle

```
CLIENT REQUEST FLOW (client-initiated):
  Discover → tap "Request" on trainer/nutritionist
    → LeadsService.createLead(providerId) [Edge: create-lead]
    → lead created with status=requested

  Trainer/Nutritionist sees incoming lead
    → Accept → updateLeadStatus(leadId, 'accepted') [Edge: update-lead-status]
    → Conversation created; client appears in "My Clients"
    → Decline → status=declined
    → Cancel (client) → status=cancelled

STATE MACHINE:
  requested → accepted | declined | cancelled
  accepted  → (active; no explicit "ended" yet – can add later)
```

| State | Client | Trainer | Nutritionist |
|-------|--------|---------|---------------|
| **requested** | Cancel request | Accept, Decline | Accept, Decline |
| **accepted** | View coach, chat, log data | View client metrics/meals/workouts, assign plans, message | View client logs, add notes, message (no plan assign) |
| **declined/cancelled** | — | — | — |

**Trainer invite (optional):** Trainer could "Invite client" by email/link → client signs up with code → lead created with client_id. Same lifecycle.

### B) UI Screens Required

#### Trainer

| Screen | Data Shown | Actions |
|--------|------------|---------|
| **Client list** | Accepted leads as clients; pending (requested) as separate tab | Tap client → detail; Accept/Decline pending |
| **Client detail (overview)** | Profile, last check-in, adherence, alerts | Message, Assign Plan, Book Session, Send Reminder |
| **Meals view** | Client meals + items + photos (last 7 days) | View only |
| **Metrics view** | Steps, calories burned, water, distance by day | View only |
| **Workout logs view** | Completed workouts (from workout_sessions) | View only |
| **Plan assignment** | Assign diet plan, workout plan to client | Select plan, assign |

#### Client

| Screen | Data Shown | Actions |
|--------|------------|---------|
| **My coaches** | Accepted trainers + nutritionists | Tap → chat or view |
| **My plans** | Assigned diet/workout plans | View, (future: mark complete) |
| **Log screens** | Meal tracker, metrics (existing) | Log meals, steps, water, workouts |

#### Nutritionist

| Screen | Data Shown | Actions |
|--------|------------|---------|
| **Assigned clients** | Accepted leads (nutritionist) | Tap → consultation view |
| **Consultation view** | Client profile, meals, steps, water, calories, workouts (read-only) | Add note, Message |
| **Add note** | Consultation notes form | Save note |

#### Admin (optional)

| Screen | Data Shown | Actions |
|--------|------------|---------|
| **Link/unlink** | All coach–client links | Fix access, manual link |

### C) Data Model

#### New / Modified Tables

| Table | Exists? | Columns | Purpose |
|-------|---------|---------|---------|
| **coach_clients** | **NEW** | id, coach_id (provider user_id), client_id, coach_type (trainer/nutritionist), lead_id (FK), status (active/ended), created_at, ended_at | Explicit link for RLS; created when lead accepted |
| **diet_plans** | **NEW** | id, coach_id, client_id, title, content (JSON or text), assigned_at, created_at | Assigned diet plans |
| **workout_plans** | **NEW** | id, coach_id, client_id, title, content (JSON), assigned_at, created_at | Assigned workout plans |
| **workout_sessions** | **NEW** | id, user_id, plan_id (nullable), completed_at, notes, created_at | Client workout completion logs |
| **consultation_notes** | **NEW** | id, nutritionist_id, client_id, content, created_at | Nutritionist notes (consultation-only) |
| **meal_media** | **EXISTS** | Add `expires_at timestamptz` | 7-day expiry for storage cleanup |

#### RLS Permission Matrix

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| **coach_clients** | Own rows (coach or client) | Via RPC on lead accept | Coach (status) | — |
| **metrics_daily** | Own OR coach's clients | Own | Own | — |
| **meals** | Own OR coach's clients | Own | Own | Own |
| **meal_items** | Via meals | Own (via meal) | Own | Own |
| **meal_media** | Via meals (coach sees client's) | Own | — | Own |
| **diet_plans** | Coach + assigned client | Coach (for own clients) | Coach | Coach |
| **workout_plans** | Coach + assigned client | Coach | Coach | Coach |
| **workout_sessions** | Own OR coach's clients | Own | Own | — |
| **consultation_notes** | Nutritionist + client | Nutritionist | Nutritionist | Nutritionist |

**Coach access rule:** Coach can SELECT client data iff `EXISTS (SELECT 1 FROM coach_clients WHERE coach_id = auth.uid() AND client_id = <target> AND status = 'active')`.

### D) API Layer

**Recommendation: Direct RLS + targeted RPCs**

- **Existing pattern:** `MetricsRepository`, `MealRepository` use direct `.from().select()` with RLS. `LeadsService` uses Edge Functions → RPC.
- **For coach–client reads:** Add RLS policies that allow coach to read client's `metrics_daily`, `meals`, `meal_items`, `meal_media` when `coach_clients` link exists. Use direct selects (no RPC) for simplicity.
- **For coach-only writes:** Use RPCs where needed (e.g. `assign_diet_plan`, `add_consultation_note`) to enforce coach_type (trainer vs nutritionist) and avoid policy complexity.
- **Rationale:** Matches current repo style; RLS handles most reads; RPCs for writes that need role checks.

### E) Meal Photos Expiry

#### Current `meal_media` Usage

- **UI:** Meal tracker stores **local file paths** only (`_mealPhotoPath` map). No `meal_media` inserts from app yet.
- **Schema:** `meal_media` has `media_url`, `media_kind`; no `expires_at`.

#### Recommended Storage Strategy

1. **Private bucket:** `meal-photos` (private).
2. **Path:** `{user_id}/{meal_id}/{uuid}.jpg`.
3. **DB:** `meal_media.media_url` = path (or full `storage/meal-photos/...`); add `expires_at timestamptz DEFAULT (now() + interval '7 days')`.
4. **Signed URLs:** Trainer dashboard fetches `createSignedUrl(path, 3600)` for display (valid 1h).
5. **Cleanup:** Edge Function + cron (daily): delete objects where `expires_at < now()` and remove DB rows.

#### Cleanup Logic (Edge Function)

```typescript
// supabase/functions/cleanup-meal-media/index.ts
// Run via cron: 0 3 * * * (3am daily)

const { data: expired } = await supabaseAdmin
  .from('meal_media')
  .select('id, media_url')
  .lt('expires_at', new Date().toISOString());

for (const row of expired || []) {
  const path = row.media_url; // e.g. user_id/meal_id/uuid.jpg
  await supabaseAdmin.storage.from('meal-photos').remove([path]);
  await supabaseAdmin.from('meal_media').delete().eq('id', row.id);
}
```

**Where to run:** Supabase Edge Function + `pg_cron` or external cron calling the function URL.

---

## 3. DB + RLS Plan

### New Migration Outline

```sql
-- 1. coach_clients (from lead accept)
CREATE TABLE coach_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES auth.users(id),
  client_id uuid NOT NULL REFERENCES auth.users(id),
  coach_type text NOT NULL CHECK (coach_type IN ('trainer', 'nutritionist')),
  lead_id uuid REFERENCES leads(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
  created_at timestamptz DEFAULT now(),
  ended_at timestamptz,
  UNIQUE(coach_id, client_id)
);

-- 2. diet_plans, workout_plans, workout_sessions, consultation_notes
-- 3. meal_media.expires_at
-- 4. RLS policies for coach access to metrics_daily, meals, meal_items, meal_media
-- 5. Trigger or update update_lead_status_tx to insert coach_clients on accept
```

### RLS Policies (Summary)

| Table | Policy |
|-------|--------|
| metrics_daily | Own OR (coach_clients coach_id=auth.uid() AND client_id=user_id) |
| meals | Own OR coach_clients (same) |
| meal_items | Via meals join |
| meal_media | Via meals join; add expires_at check for signed URL |
| diet_plans | Coach inserts for own clients; client+coach select |
| workout_plans | Same |
| workout_sessions | Own insert; coach select for clients |
| consultation_notes | Nutritionist only; client select |

---

## 4. Implementation Plan (Smallest Deployable Slices)

### Step 1: Wire Discover Request + Coach Client List (MVP)
- Discover: Call `LeadsService.createLead(providerId)` on Request; load `leadsProvider` for status.
- Trainer/Nutritionist My Clients: Replace mock with `leads` where status=accepted (and optionally incoming requested).
- Add `coach_clients` table + populate on lead accept (modify `update_lead_status_tx` or migration).
- Route to ClientDetailPage/NutritionistClientDetailPage with real clientId from lead.

### Step 2: Coach Access to Client Metrics & Meals
- RLS: Coach can SELECT `metrics_daily`, `meals`, `meal_items` for linked clients.
- ClientDetailPage: Fetch real `metrics_daily` for client; fetch real meals via MealRepository (new method `getClientDayMeals(clientId, date)` with RLS).
- Wire Meals tab to real data.

### Step 3: Meal Photos (Storage + Expiry)
- Add `meal_media.expires_at`; create `meal-photos` bucket.
- Meal tracker: Upload photo on add → insert `meal_media`; store path.
- Trainer dashboard: Use signed URLs for client meal photos.
- Edge Function `cleanup-meal-media` + cron.

### Step 4: Diet & Workout Plans (Trainer Assign)
- Create `diet_plans`, `workout_plans` tables.
- Trainer: Assign plan screen; insert with coach_id, client_id.
- Client: "My plans" screen; fetch assigned plans.

### Step 5: Workout Logs
- Create `workout_sessions` table.
- Client: Log workout completion (from quest or dedicated flow).
- Trainer: View client workout logs in Workouts tab.

### Step 6: Nutritionist Consultation Notes
- Create `consultation_notes` table.
- Nutritionist: Add note in client detail; fetch notes.
- Restrict nutritionist from assigning diet plans (or make configurable).

### Step 7: Admin (Optional)
- Service role or admin RPC to link/unlink coach–client manually.
