# Retool Admin Panel Blueprint

**App:** Cotrainr Fitness Admin  
**Backend:** Supabase (Postgres + RLS + Storage + RPCs)  
**Auth:** Retool auth + Supabase service_role key

**Constraints:** No rating edits. No auth.users via PostgREST (use RPC or Postgres connection). Idempotent migrations.

**Connection:** Use **Supabase REST (PostgREST) only**—no direct Postgres connection. All data via RPCs. auth.users is not queryable via PostgREST; use `admin_list_users` RPC.

---

## 1. Left Nav

| Item | Screen |
|------|--------|
| Verification → Trainer Verification | `trainer_verification` |
| Verification → Nutritionist Verification | `nutritionist_verification` |
| Users | `users` |
| Providers | `providers` |
| Leads | `leads` |
| Subscriptions | `subscriptions` |
| App Insights | `app_insights` |
| Settings | `settings` |
| Audit Log | `audit_log` |
| (bottom) Logout | Clears auth |

---

## 2. Supabase Resource

**Resource:** `supabase_admin`  
**Base URL:** `https://<project-ref>.supabase.co`  
**Headers:** `apikey`: service_role_key, `Authorization`: Bearer service_role_key

---

## 3. A) Verification (Trainer / Nutritionist)

### CRITICAL: Document previews before approval

Admin **MUST** visually preview **BOTH** uploaded documents (certificate + gov ID) before approving. No blind approve.

- Images are in **private** bucket `verification-docs` → use **signed URLs** to render previews.
- **Approve button must be disabled** until BOTH image previews have loaded successfully.
- Drawer flow: open → fetch signed URLs for certificate_path and gov_id_path → display in Image components → enable Approve only when both loaded.
- **Server-side:** `approve_verification` RPC blocks approval if `certificate_path` or `gov_id_path` is NULL/empty. Do not rely on Retool UI validation alone.

### Data

| Query | Type | Details |
|-------|------|---------|
| listTrainerPending | RPC | `list_pending_verifications` params: `{ "p_provider_type": "trainer" }` |
| listNutritionistPending | RPC | `list_pending_verifications` params: `{ "p_provider_type": "nutritionist" }` |
| approveVerification | RPC | `approve_verification_v2` params: `{ "p_submission_id": "{{ selectedRow.id }}", "p_actor_id": "{{ adminUserId }}" }` (p_actor_id required) |
| rejectVerification | RPC | `reject_verification_v2` params: `{ "p_submission_id": "{{ selectedRow.id }}", "p_notes": "{{ rejectionNotes }}", "p_actor_id": "{{ adminUserId }}" }` (p_actor_id required) |

### Signed URL for document previews (BOTH required)

**Option 1 (preferred):** Supabase Storage REST sign endpoint (if Retool supports it):

```
POST https://<project>.supabase.co/storage/v1/object/sign/verification-docs
Headers: apikey, Authorization (service_role)
Body: { "path": "<certificate_path or gov_id_path>", "expiresIn": 900 }
Response: { "signedUrl": "...", "path": "..." }
```

**Option 2 (implemented):** Edge Function:

```
POST https://<project>.supabase.co/functions/v1/get-verification-signed-url
Headers: Authorization: Bearer <anon_key or service_role>, Content-Type: application/json
Body: { "path": "<certificate_path or gov_id_path>", "expiresIn": 900 }
Response: { "url": "<signed_url>" }
```

**Retool implementation:**
1. Create two REST queries: `getCertSignedUrl`, `getGovIdSignedUrl`. Both POST to Edge Function with `path` from `drawerState.selectedRow.certificate_path` and `drawerState.selectedRow.gov_id_path`.
2. Set both queries to run when drawer opens (e.g. trigger on `drawerState.selectedRow` change).
3. Image 1 `src`: `{{ getCertSignedUrl.data?.url }}` — Image 2 `src`: `{{ getGovIdSignedUrl.data?.url }}`
4. Approve button `disabled`: `{{ !getCertSignedUrl.data?.url || !getGovIdSignedUrl.data?.url || getCertSignedUrl.isLoading || getGovIdSignedUrl.isLoading }}`
5. Show "Loading previews..." or spinners until both queries succeed. If either fails, show error and keep Approve disabled.

TTL: 5–15 min (900s default).

### Components

| Component | Config |
|-----------|--------|
| Table | Data: listTrainerPending / listNutritionistPending. Columns: full_name, email, gov_id_type, submitted_at, Actions |
| Drawer | Row click opens. Content: full_name, email, user_id, provider_type, gov_id_type, submitted_at |
| Image (certificate) | `src`: signed URL from `certificate_path`. Show loading until loaded. `onLoad` → set certLoaded=true |
| Image (gov ID) | `src`: signed URL from `gov_id_path`. Show loading until loaded. `onLoad` → set govIdLoaded=true |
| Approve | **Disabled** until `certLoaded && govIdLoaded`. Then runs approveVerification → refresh list → close drawer |
| Reject | Requires notes. Runs rejectVerification → refresh → close. Can be enabled immediately (no preview required for reject) |
| TextArea | rejectionNotes – required for Reject |

---

## 4. B) Users

**Do NOT query auth.users via PostgREST.** Use `admin_list_users` RPC.

### Query: listUsers

**Type:** Supabase RPC  
**RPC:** `admin_list_users`  
**Params:** `{ "p_search_email": "{{ searchEmail }}", "p_search_name": "{{ searchName }}", "p_search_user_id": "{{ searchUserId }}" }`  
Pass `null` for unused filters.

**Returns:** user_id, email, role, full_name, created_at, provider_type, verified

**Actions:** View user details, View subscriptions (read-only). **NO rating changes.**

---

## 5. C) Providers

### Query: listProviders

**Type:** Supabase / SQL (profiles + providers, no auth.users)

```sql
SELECT
  pr.user_id,
  pr.provider_type,
  pr.verified,
  pr.specialization,
  pr.experience_years,
  pr.hourly_rate,
  pr.created_at,
  p.full_name
FROM public.providers pr
LEFT JOIN public.profiles p ON p.id = pr.user_id
ORDER BY pr.created_at DESC;
```

**Actions:** View provider profile (read-only), Link to verification history (filter verification_submissions by user_id), **Force re-verification** (RPC `admin_force_reverification` sets providers.verified = false; user can submit new verification).

---

## 6. D) Leads

### Query: listLeads

```sql
SELECT
  l.id,
  l.client_id,
  l.provider_id,
  l.provider_type,
  l.status,
  l.created_at,
  pc.full_name AS client_name,
  pp.full_name AS provider_name
FROM public.leads l
LEFT JOIN public.profiles pc ON pc.id = l.client_id
LEFT JOIN public.profiles pp ON pp.id = l.provider_id
WHERE 1=1
  -- Filters: AND l.status = {{ statusFilter }}
  --          AND l.provider_type = {{ providerTypeFilter }}
  --          AND l.created_at >= {{ dateFrom }} AND l.created_at <= {{ dateTo }}
ORDER BY l.created_at DESC;
```

**Filters:** status, provider_type, date range. **Read-only details.**

---

## 7. E) Subscriptions

### Query: listSubscriptions

```sql
SELECT
  s.user_id,
  p.full_name,
  p.role,
  COALESCE(s.plan::text, 'free') AS plan,
  COALESCE(s.status::text, 'inactive') AS status,
  COALESCE(s.provider::text, 'manual') AS provider,
  s.current_period_end,
  s.expires_at,
  s.comp_until,
  GREATEST(COALESCE(s.current_period_end, s.expires_at, '1970-01-01'::timestamptz), COALESCE(s.comp_until, '1970-01-01'::timestamptz)) AS effective_until,
  s.updated_at
FROM public.subscriptions s
LEFT JOIN public.profiles p ON p.id = s.user_id
ORDER BY s.updated_at DESC;
```

**Note:** Use `::text` if plan/status/provider are enums.

**Actions:** Use v2 RPCs (audit logged, actor validated):
- **Grant comp:** RPC `admin_grant_comp_v2` params: `{ "p_user_id": "{{ user_id }}", "p_comp_until": "{{ date }}", "p_actor_id": "{{ adminUserId }}" }`
- **Remove comp:** RPC `admin_remove_comp_v2` params: `{ "p_user_id": "{{ user_id }}", "p_actor_id": "{{ adminUserId }}" }`

**Read-only:** plan, status, provider, current_period_end, customer_id, subscription_id.

---

## 8. F) App Insights

**No auth.users.** Use `public.profiles` for user counts.

### Query: appInsights

```sql
SELECT
  (SELECT COUNT(*) FROM public.profiles) AS total_users,
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'client') AS total_clients,
  (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'trainer') AS total_trainers,
  (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'nutritionist') AS total_nutritionists,
  (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'trainer' AND verified) AS verified_trainers,
  (SELECT COUNT(*) FROM public.providers WHERE provider_type = 'nutritionist' AND verified) AS verified_nutritionists,
  (SELECT COUNT(*) FROM public.verification_submissions WHERE status = 'pending') AS pending_verifications_count,
  (SELECT COUNT(*) FROM public.leads WHERE status = 'requested' AND created_at >= NOW() - ({{ daysFilter }} || ' days')::interval) AS leads_requested_count,
  (SELECT COUNT(*) FROM public.leads WHERE status = 'accepted' AND created_at >= NOW() - ({{ daysFilter }} || ' days')::interval) AS accepted_leads_count,
  (SELECT COUNT(*) FROM public.subscriptions WHERE plan::text = 'basic' AND status::text IN ('active','trialing')) AS subscriptions_active_basic_count,
  (SELECT COUNT(*) FROM public.subscriptions WHERE plan::text = 'premium' AND status::text IN ('active','trialing')) AS subscriptions_active_premium_count,
  (SELECT COUNT(*) FROM public.subscriptions WHERE status::text = 'trialing') AS subscriptions_trialing_count,
  (SELECT COUNT(*) FROM public.subscriptions WHERE status::text = 'past_due') AS subscriptions_past_due_count;
```

**Time filter:** Dropdown daysFilter = 7, 30, 90.

**KPI cards:** total_users, total_clients, total_trainers, total_nutritionists, verified_trainers, verified_nutritionists, pending_verifications_count, leads_requested_count, accepted_leads_count, subscriptions_active_basic_count, subscriptions_active_premium_count, subscriptions_trialing_count, subscriptions_past_due_count.

---

## 9. G) Settings

**Query:** RPC `admin_get_app_settings` (returns key, value, updated_at)

**Update:** RPC `admin_update_app_setting` with whitelist validation:
- **Keys:** support_email, terms_url, privacy_url only
- **support_email:** validated as email format if non-empty
- **terms_url, privacy_url:** validated as http(s) URL if non-empty
- **p_actor_id:** required when admin_users has rows (use 3-arg: p_key, p_value, p_actor_id)

**Admin users:** Read-only placeholder if no admin table exists.

**Danger zone:** Read-only.

**Logout:** Button at bottom of nav.

---

## 10. H) Audit Log

**Query:** RPC `admin_list_audit_log` params: `{ "p_action": null, "p_limit": 100, "p_offset": 0, "p_from": null, "p_to": null }`

**Filters:** p_action (approve_verification, reject_verification, admin_grant_comp, admin_remove_comp, admin_force_reverification), p_from/p_to (date range), p_limit, p_offset

**Columns:** id, action, actor_id, target_type, target_id, details (JSONB), created_at. Most recent first.

**Read-only.** All admin actions are logged server-side. Refresh after verification/subscription actions.

**admin_users:** Add Retool admin UUIDs via `admin_add_admin_user` RPC. When populated, p_actor_id must exist in admin_users.

---

---

## 11. Connection: Supabase REST Only

| Approach | auth.users | RPCs | Raw SQL |
|----------|------------|------|---------|
| **Supabase REST (PostgREST)** | Not queryable directly | Yes | No (use RPCs) |

**Use Supabase REST only.** All screens use RPCs. Do not query auth.users via PostgREST; use `admin_list_users` RPC.

---

## 12. Migrations (idempotent)

**Order:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11

| # | File | Purpose |
|---|------|---------|
| 1 | `20250216_verification_workflow.sql` | verification_submissions, RPCs, storage policies |
| 2 | `20250216_verification_gov_id_type.sql` | gov_id_type column + CHECK |
| 3 | `20250219_verification_audit_fixes.sql` | Storage UPDATE policy, list_pending returns gov_id_type, RPC hardening |
| 4 | `20250220_subscriptions_admin_comp.sql` | subscriptions table (create if missing), comp_until, RLS |
| 5 | `20250221_admin_rpc_and_subscriptions.sql` | admin_list_users RPC, app_settings table |
| 6 | `20250222_admin_retool_rpcs.sql` | admin_list_providers, admin_list_leads, admin_list_subscriptions, admin_app_insights, admin_get_app_settings, admin_update_app_setting, admin_grant_comp, admin_remove_comp |
| 7 | `20250223_admin_production_hardening.sql` | admin_audit_log table, approve_verification path validation, admin_update_app_setting whitelist/validation, admin_force_reverification, audit logging for all admin actions |
| 8 | `20250224_admin_qa_hardening.sql` | admin_users table, admin_list_audit_log filters (p_offset, p_from, p_to), v2 RPCs (admin_grant_comp_v2, admin_remove_comp_v2, admin_force_reverification_v2), actor validation |
| 9 | `20250225_admin_actor_final_hardening.sql` | Tighten admin_validate_actor (NULL only when admin_users empty), all admin RPCs fail fast on invalid actor, admin_update_app_setting adds p_actor_id, admin_list_audit_log 2-arg wrapper |
| 10 | `20250226_admin_rpc_naming_and_wrapper_hardening.sql` | approve_verification_v2, reject_verification_v2 (p_actor_id canonical); old approve/reject as thin wrappers; identical security on all; validation first |
| 11 | `20250227_admin_rpc_v2_nonnull_actor.sql` | Remove DEFAULT NULL from p_actor_id in v2; wrappers pure delegation only |

---

## 13. Assumptions

| Item | Assumption |
|------|------------|
| auth.users | Not queryable via PostgREST; use admin_list_users RPC |
| list_pending_verifications | Returns gov_id_type, email (joins auth.users in RPC) |
| profiles | Has role, full_name, created_at |
| Signed URLs | Edge Function get-verification-signed-url with path, expiresIn |
| Ratings | NO edit features anywhere |
