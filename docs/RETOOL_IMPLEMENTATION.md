# Retool Admin Panel — Implementation Guide

**Source of truth:** `docs/RETOOL_ADMIN_BLUEPRINT.md`

**Connection mode:** This guide assumes **Supabase REST (PostgREST) only**—no direct Postgres connection. All data access uses RPCs and REST. If you add a Postgres connection, you can replace RPCs with raw SQL where noted.

---

## 1. Connection: Supabase REST Only

| Data | Method |
|------|--------|
| Verification list, approve, reject | RPC |
| Users (with email) | RPC `admin_list_users` |
| Providers, Leads, Subscriptions | RPC (see §7) |
| App Insights | RPC `admin_app_insights` |
| App Settings | RPC `admin_get_app_settings` |
| Signed URLs | REST → Edge Function |

**auth.users:** Never queried via PostgREST. Email comes from `admin_list_users` RPC.

---

## 2. Retool Resource Setup

**Resource name:** `supabase_admin`

| Setting | Value |
|---------|-------|
| Type | Supabase |
| Base URL | `https://<project-ref>.supabase.co` |
| API Key | `<service_role_key>` |
| Authorization | Bearer `<service_role_key>` |

**REST resource** (for Edge Function):

| Setting | Value |
|---------|-------|
| Name | `supabase_edge_functions` |
| Base URL | `https://<project-ref>.supabase.co/functions/v1` |
| Headers | `Authorization: Bearer <anon_key or service_role>`, `Content-Type: application/json` |

---

## 3. Screen 1: Verification (Trainer)

### Component tree

```
Screen: trainer_verification
├── Container (main)
│   ├── Text (title): "Trainer Verification"
│   ├── Table (verificationTable)
│   │   └── Columns: full_name, email, gov_id_type, submitted_at, Actions
│   └── Drawer (verificationDrawer)
│       ├── Container (drawerContent)
│       │   ├── Text: "Provider Info"
│       │   ├── Text: full_name, email, user_id, provider_type, gov_id_type, submitted_at
│       │   ├── Text: "Certificate"
│       │   ├── Image (certImage) OR Spinner (certLoading)
│       │   ├── Text: "Government ID"
│       │   ├── Image (govIdImage) OR Spinner (govIdLoading)
│       │   ├── TextArea (rejectionNotes)
│       │   ├── Button (approveBtn) — DISABLED until both previews loaded
│       │   └── Button (rejectBtn)
│       └── (drawer closes on success)
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| listTrainerPending | Supabase RPC | Page load, Manual, After approveVerification/rejectVerification | RPC: `list_pending_verifications`, Params: `{ "p_provider_type": "trainer" }` |
| getCertSignedUrl | REST | When `verificationDrawer.selectedRow` changes | POST `get-verification-signed-url`, Body: `{ "path": {{ verificationDrawer.selectedRow.certificate_path }}, "expiresIn": 900 }` |
| getGovIdSignedUrl | REST | When `verificationDrawer.selectedRow` changes | POST `get-verification-signed-url`, Body: `{ "path": {{ verificationDrawer.selectedRow.gov_id_path }}, "expiresIn": 900 }` |
| approveVerification | Supabase RPC | approveBtn click | RPC: `approve_verification_v2`, Params: `{ "p_submission_id": {{ verificationDrawer.selectedRow.id }}, "p_actor_id": {{ adminUserId }} }` |
| rejectVerification | Supabase RPC | rejectBtn click | RPC: `reject_verification_v2`, Params: `{ "p_submission_id": {{ verificationDrawer.selectedRow.id }}, "p_notes": {{ rejectionNotes.value }}, "p_actor_id": {{ adminUserId }} }` |

### Triggers

| Event | Action |
|-------|--------|
| Table row click | Set `verificationDrawer.selectedRow` = row, open drawer |
| Drawer opens | Run getCertSignedUrl, getGovIdSignedUrl (both use selectedRow) |
| approveVerification success | Run listTrainerPending, listAuditLog (refresh audit), close drawer, show success toast |
| rejectVerification success | Run listTrainerPending, listAuditLog (refresh audit), close drawer, show success toast |

**Use v2 RPCs:** `approve_verification_v2` and `reject_verification_v2` with `p_actor_id` (required, no default). Wrappers `approve_verification`/`reject_verification` with `p_reviewer_id` delegate to v2; they fail when admin_users has rows and actor is NULL.

### Component bindings

| Component | Binding |
|-----------|---------|
| Table data | `{{ listTrainerPending.data }}` |
| certImage src | `{{ getCertSignedUrl.data?.url }}` |
| certImage visible | `{{ getCertSignedUrl.data?.url }}` |
| certLoading visible | `{{ getCertSignedUrl.isLoading \|\| !getCertSignedUrl.data?.url }}` |
| govIdImage src | `{{ getGovIdSignedUrl.data?.url }}` |
| govIdImage visible | `{{ getGovIdSignedUrl.data?.url }}` |
| govIdLoading visible | `{{ getGovIdSignedUrl.isLoading \|\| !getGovIdSignedUrl.data?.url }}` |
| approveBtn disabled | `{{ !getCertSignedUrl.data?.url \|\| !getGovIdSignedUrl.data?.url \|\| getCertSignedUrl.isLoading \|\| getGovIdSignedUrl.isLoading }}` |
| rejectBtn disabled | `{{ !rejectionNotes.value \|\| rejectionNotes.value.trim() === '' }}` (or require notes in modal) |

**Note:** Reject can open a modal for notes, then call rejectVerification. Approve must stay disabled until both images load. **Server-side:** approve_verification_v2 RPC blocks approval if certificate_path or gov_id_path is NULL/empty.

**adminUserId:** Set via a Retool state variable bound to the logged-in admin's user UUID from Retool auth context (e.g. `{{ retoolContext.user.id }}`). **Required:** Add admin UUIDs to `admin_users` table via `admin_add_admin_user` RPC or SQL; when populated, `p_actor_id` must exist in `admin_users`.

---

## 4. Screen 2: Verification (Nutritionist)

Same as Trainer. Replace:
- `listTrainerPending` → `listNutritionistPending` with `{ "p_provider_type": "nutritionist" }`
- Title: "Nutritionist Verification"

---

## 5. Screen 3: Users

### Component tree

```
Screen: users
├── Container
│   ├── TextInput (searchEmail)
│   ├── TextInput (searchName)
│   ├── TextInput (searchUserId) — optional
│   ├── Button (searchBtn) — triggers listUsers
│   └── Table (usersTable)
│       └── Columns: user_id, email, role, full_name, created_at, provider_type, verified
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| listUsers | Supabase RPC | Page load, searchBtn click | RPC: `admin_list_users`, Params: `{ "p_search_email": {{ searchEmail.value || null }}, "p_search_name": {{ searchName.value || null }}, "p_search_user_id": {{ searchUserId.value || null }} }` |

**NO rating edits.**

---

## 6. Screen 4: Providers

### Component tree

```
Screen: providers
├── Container
│   ├── Table (providersTable)
│   │   └── Columns: user_id, provider_type, verified, specialization, experience_years, hourly_rate, created_at, full_name
│   └── (optional) Link/Button to filter verification_submissions by user_id
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| listProviders | Supabase RPC | Page load | RPC: `admin_list_providers` (see §7) |

**Read-only.** Link to verification history: navigate to a view of verification_submissions filtered by user_id.

---

## 7. Screen 5: Leads

### Component tree

```
Screen: leads
├── Container
│   ├── Select (statusFilter): requested, accepted, declined, cancelled
│   ├── Select (providerTypeFilter): trainer, nutritionist
│   ├── DatePicker (dateFrom), DatePicker (dateTo)
│   ├── Button (applyFilters)
│   └── Table (leadsTable)
│       └── Columns: id, client_id, provider_id, provider_type, status, created_at, client_name, provider_name
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| listLeads | Supabase RPC | Page load, applyFilters | RPC: `admin_list_leads`, Params: `{ "p_status": {{ statusFilter.value }}, "p_provider_type": {{ providerTypeFilter.value }}, "p_date_from": {{ dateFrom.value }}, "p_date_to": {{ dateTo.value }} }` |

**Read-only.**

---

## 8. Screen 6: Subscriptions

### Component tree

```
Screen: subscriptions
├── Container
│   ├── TextInput (searchEmail), TextInput (searchName)
│   ├── Table (subscriptionsTable)
│   │   └── Columns: user_id, full_name, role, plan, status, provider, current_period_end, comp_until, effective_until, updated_at
│   └── Drawer (subscriptionDrawer) — row click
│       ├── Display: full subscription record (read-only for plan, status, provider)
│       ├── DatePicker (compUntilDate)
│       ├── Button (grantCompBtn)
│       └── Button (removeCompBtn)
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| listSubscriptions | Supabase RPC | Page load | RPC: `admin_list_subscriptions` |
| grantComp | Supabase RPC | grantCompBtn click | RPC: `admin_grant_comp_v2`, Params: `{ "p_user_id": {{ selectedRow.user_id }}, "p_comp_until": {{ compUntilDate.value }}, "p_actor_id": {{ adminUserId }} }` |
| removeComp | Supabase RPC | removeCompBtn click | RPC: `admin_remove_comp_v2`, Params: `{ "p_user_id": {{ selectedRow.user_id }}, "p_actor_id": {{ adminUserId }} }` |

**Read-only:** plan, status, provider, current_period_end.

**Triggers:** On grantComp/removeComp success, run listAuditLog to refresh Audit Log screen.

---

## 9. Screen 7: App Insights

### Component tree

```
Screen: app_insights
├── Container
│   ├── Select (daysFilter): 7, 30, 90
│   └── Grid of KPI cards:
│       ├── total_users, total_clients, total_trainers, total_nutritionists
│       ├── verified_trainers, verified_nutritionists
│       ├── pending_verifications_count
│       ├── leads_requested_count, accepted_leads_count
│       └── subscriptions_active_basic_count, subscriptions_active_premium_count, subscriptions_trialing_count, subscriptions_past_due_count
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| appInsights | Supabase RPC | Page load, daysFilter change | RPC: `admin_app_insights`, Params: `{ "p_days": {{ daysFilter.value || 7 }} }` |

---

## 10. Screen 8: Settings

### Component tree

```
Screen: settings
├── Container
│   ├── Text: "App Config"
│   ├── TextInput (supportEmail) — bound to app_settings.support_email
│   ├── TextInput (termsUrl), TextInput (privacyUrl)
│   ├── Text: "Admin users" (placeholder, read-only)
│   ├── Text: "Danger zone" (read-only)
│   └── (Logout in left nav)
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| getAppSettings | Supabase RPC | Page load | RPC: `admin_get_app_settings` |
| updateAppSetting | Supabase RPC | Save button click | RPC: `admin_update_app_setting`, Params: `{ "p_key": "support_email", "p_value": {{ supportEmail.value }}, "p_actor_id": {{ adminUserId }} }` (repeat for terms_url, privacy_url) |

**Data binding:** getAppSettings returns `[{ key, value }, ...]`. Use transformers or `getAppSettings.data.find(x => x.key === 'support_email')?.value` to populate inputs. On save, call updateAppSetting for each changed key. **Actor:** When admin_users has rows, p_actor_id is required. Use 2-arg `(p_key, p_value)` only when admin_users is empty (bootstrap). **Validation:** admin_update_app_setting whitelists keys (support_email, terms_url, privacy_url) and validates email/URL format server-side.

---

## 11. Screen 9: Audit Log

### Component tree

```
Screen: audit_log
├── Container
│   ├── Select (actionFilter): All, approve_verification, reject_verification, admin_grant_comp, admin_remove_comp, admin_force_reverification
│   ├── DatePicker (dateFrom), DatePicker (dateTo) — optional
│   ├── NumberInput (limitInput): default 100
│   ├── Button (refreshBtn)
│   └── Table (auditTable)
│       └── Columns: action, actor_id, target_type, target_id, created_at, details (JSON)
```

### Queries

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| listAuditLog | Supabase RPC | Page load, actionFilter/dateFrom/dateTo/limit change, refreshBtn, after approve/reject/grant/remove success | RPC: `admin_list_audit_log`, Params: `{ "p_action": {{ actionFilter.value || null }}, "p_limit": {{ limitInput.value || 100 }}, "p_offset": 0, "p_from": {{ dateFrom.value || null }}, "p_to": {{ dateTo.value || null }} }` (5-arg). Or use 2-arg `{ "p_action": {{ actionFilter.value || null }}, "p_limit": {{ limitInput.value || 100 }} }` for backward compat. |

**Read-only.** Link from Verification and Subscriptions success handlers: run listAuditLog after approveVerification, rejectVerification, grantComp, removeComp success so Audit Log shows fresh data.

---

## 12. Providers: Force Re-verification

On the Providers screen, add optional action:

| Name | Type | Trigger | Config |
|------|------|---------|--------|
| forceReverification | Supabase RPC | Button click (with confirmation) | RPC: `admin_force_reverification_v2`, Params: `{ "p_user_id": {{ selectedRow.user_id }}, "p_actor_id": {{ adminUserId }} }` |

Sets `providers.verified = false`. User can submit new verification_submissions (unique constraint only on pending).

---

## 13. Left Nav + Logout

- Left nav items: Verification (sub: Trainer, Nutritionist), Users, Providers, Leads, Subscriptions, App Insights, Settings, Audit Log
- Logout: Button at bottom, clears Retool auth, redirects to login

---

## 14. Required RPCs (SQL Migration)

The following RPCs must exist for **Supabase REST-only** mode. Add to migration `20250222_admin_retool_rpcs.sql`:

| RPC | Purpose |
|-----|---------|
| admin_list_users | Users with email (already exists in 20250221) |
| admin_list_providers | Providers + full_name |
| admin_list_leads | Leads + client_name, provider_name, filters |
| admin_list_subscriptions | Subscriptions + profile join, effective_until |
| admin_app_insights | KPI counts with days filter |
| admin_get_app_settings | Key-value app settings |
| admin_grant_comp_v2 | Set comp_until for user (single signature, audit logged, actor validation) |
| admin_remove_comp_v2 | Clear comp_until (single signature, audit logged, actor validation) |
| admin_list_audit_log | List admin audit log (p_action, p_limit, p_offset, p_from, p_to) |
| admin_force_reverification_v2 | Set providers.verified=false (single signature, actor validation) |
| approve_verification_v2 | Approve verification (canonical p_actor_id) |
| reject_verification_v2 | Reject verification (canonical p_actor_id) |
| admin_add_admin_user | Add user to admin_users (bootstrap Retool admins) |

---

## 15. Edge Function Usage

**Name:** `get-verification-signed-url`

**URL:** `POST https://<project>.supabase.co/functions/v1/get-verification-signed-url`

**Body:** `{ "path": "<certificate_path or gov_id_path>", "expiresIn": 900 }`

**Response:** `{ "url": "<signed_url>" }`

**Retool:** Create REST resource pointing to Edge Function base URL. Two queries (getCertSignedUrl, getGovIdSignedUrl) POST with different path values.

---

## 16. Summary: Connection Mode

| Mode | Queries | auth.users |
|------|---------|------------|
| **Supabase REST only** (this guide) | All via RPCs + REST (Edge Function) | Use admin_list_users RPC |
| **Postgres DB connection** | Can replace RPCs with raw SQL; RPCs still work | Can query directly in SQL |

**This implementation uses Supabase REST only.** No direct Postgres connection required. All table access goes through RPCs. Signed URLs via Edge Function.
