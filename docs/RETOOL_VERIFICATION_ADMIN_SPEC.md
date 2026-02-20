# Retool Verification Admin Panel Spec

## Overview

Retool app for reviewing and approving/rejecting trainer and nutritionist verification submissions.

---

## 1. App Structure

### Left Sidebar Navigation

| Item | Screen/Resource |
|------|-----------------|
| **Trainer Verification** | `trainer_verification` screen |
| **Nutritionist Verification** | `nutritionist_verification` screen |
| **App Insights** | `app_insights` screen (placeholder) |
| **Settings** | `settings` screen (placeholder) |
| **Logout** | Bottom of sidebar – clears auth, redirects to login |

---

## 2. Supabase Resource Setup

### Resource: `supabase_admin`

- **Type:** REST API (or Supabase resource if available)
- **Base URL:** `https://<project-ref>.supabase.co`
- **Authentication:** API Key (use **service_role** key from Supabase Dashboard → Settings → API)
- **Headers:**
  - `apikey`: `<service_role_key>`
  - `Authorization`: `Bearer <service_role_key>`

**Important:** Service role bypasses RLS. Use only for admin operations.

---

## 3. Trainer Verification Screen

### 3.1 Data Source: Pending Submissions Table

**Query:** `listTrainerPending`

- **Type:** Supabase / PostgreSQL
- **Method:** RPC
- **RPC name:** `list_pending_verifications`
- **Parameters:** `{ "p_provider_type": "trainer" }`
- **Or** raw SQL:
  ```sql
  SELECT * FROM list_pending_verifications('trainer');
  ```

**Returns:**

| Column | Type |
|--------|------|
| id | uuid |
| user_id | uuid |
| provider_type | text |
| status | text |
| certificate_path | text |
| gov_id_path | text |
| submitted_at | timestamptz |
| full_name | text |
| email | text |

### 3.2 Table Component

- **Data source:** `listTrainerPending`
- **Columns:** full_name, email, provider_type, submitted_at, Actions (button)
- **Row click / Actions:** Open detail drawer

### 3.3 Detail Drawer

**Trigger:** Row click or "View" button.

**Content:**

1. **Provider info:** full_name, email, user_id, submitted_at
2. **Document previews:**
   - **Certificate:** Image from signed URL
   - **Gov ID:** Image from signed URL

**Signed URL generation:**

Supabase Storage `createSignedUrl` is not available via REST. Use one of:

**Option A – Edge Function (recommended):**

Create `supabase/functions/get-verification-signed-url/index.ts`:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const { path } = await req.json();
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
  const { data, error } = await supabase.storage
    .from('verification-docs')
    .createSignedUrl(path, 3600);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400 });
  return new Response(JSON.stringify({ url: data.signedUrl }));
});
```

Retool query to fetch signed URL:

- **URL:** `https://<project-ref>.supabase.co/functions/v1/get-verification-signed-url`
- **Method:** POST
- **Body:** `{{ JSON.stringify({ path: currentRow.certificate_path }) }}`
- **Headers:** `Authorization: Bearer <anon_key>` (or service role if function allows)

**Option B – Retool JavaScript + Supabase JS:**

If Retool supports running Node/JS with `@supabase/supabase-js`, call `createSignedUrl` in a transformer or custom query.

**Option C – Public temporary URLs (less secure):**

If acceptable for internal admin only, create a short-lived public URL via a one-off policy or Edge Function that returns the file bytes as base64.

3. **Approve button:**
   - **Query:** `approveVerification`
   - **Type:** RPC
   - **RPC:** `approve_verification`
   - **Params:** `{ "p_submission_id": "{{ drawerState.selectedRow.id }}" }`
   - **On success:** Refresh `listTrainerPending`, close drawer, show success toast

4. **Reject button:**
   - Opens modal/drawer section for **Rejection notes** (required)
   - **Query:** `rejectVerification`
   - **RPC:** `reject_verification`
   - **Params:** `{ "p_submission_id": "{{ drawerState.selectedRow.id }}", "p_notes": "{{ rejectionNotesInput.value }}" }`
   - **Validation:** Reject disabled if notes empty
   - **On success:** Refresh, close, toast

---

## 4. Nutritionist Verification Screen

Same structure as Trainer Verification, but:

- **Query:** `list_pending_verifications('nutritionist')`
- **RPC params:** `{ "p_provider_type": "nutritionist" }`

Reuse the same drawer component; only the data source changes.

---

## 5. RPC Call Examples

### Approve

```json
POST /rest/v1/rpc/approve_verification
Headers: apikey, Authorization, Content-Type: application/json
Body: {
  "p_submission_id": "uuid-here",
  "p_reviewer_id": "admin-user-uuid-here"
}
```

**Note:** `p_reviewer_id` is the admin user's UUID (from Retool auth or a stored admin list). Pass it explicitly because `auth.uid()` is NULL when using the service_role key.

### Reject

```json
POST /rest/v1/rpc/reject_verification
Body: {
  "p_submission_id": "uuid-here",
  "p_notes": "Document unclear, please resubmit.",
  "p_reviewer_id": "admin-user-uuid-here"
}
```

### List Pending

```json
POST /rest/v1/rpc/list_pending_verifications
Body: { "p_provider_type": "trainer" }
// or { "p_provider_type": "nutritionist" }
// or {} for all
```

---

## 6. Component Outline

### Screen: `trainer_verification`

| Component | Type | Config |
|-----------|------|--------|
| Table | Table | Data: `listTrainerPending`, columns: full_name, email, submitted_at, Actions |
| Drawer | Drawer | Triggered by row click, contains detail view |
| Image (cert) | Image | `src`: result of signed URL query for `certificate_path` |
| Image (gov) | Image | `src`: result of signed URL query for `gov_id_path` |
| Approve | Button | Runs `approveVerification`, then refresh + close |
| Reject | Button | Opens notes input, runs `rejectVerification` when notes provided |
| TextInput | TextArea | `rejectionNotesInput` – required for Reject |

### Screen: `nutritionist_verification`

Same as `trainer_verification` with data source `listNutritionistPending`.

---

## 7. Queries Summary

| Name | Type | Details |
|------|------|---------|
| listTrainerPending | Supabase RPC | `list_pending_verifications` with `p_provider_type: 'trainer'` |
| listNutritionistPending | Supabase RPC | `list_pending_verifications` with `p_provider_type: 'nutritionist'` |
| approveVerification | Supabase RPC | `approve_verification` with `p_submission_id`, `p_reviewer_id` |
| rejectVerification | Supabase RPC | `reject_verification` with `p_submission_id`, `p_notes`, `p_reviewer_id` |
| getSignedUrl | REST / Edge Function | POST to Edge Function with `path`, returns `{ url }` |

---

## 8. Edge Function for Signed URLs (Optional)

Create `supabase/functions/get-verification-signed-url/index.ts`:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  try {
    const { path } = await req.json();
    if (!path || typeof path !== 'string') {
      return new Response(JSON.stringify({ error: 'path required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );
    const { data, error } = await supabase.storage.from('verification-docs').createSignedUrl(path, 3600);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    return new Response(JSON.stringify({ url: data.signedUrl }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
```

Deploy: `supabase functions deploy get-verification-signed-url`

---

## 9. Security Checklist

- [ ] Retool app uses **service_role** key only in a secure backend/private resource
- [ ] Retool app is not publicly accessible; use Retool auth or SSO
- [ ] Edge Function `get-verification-signed-url` validates admin/session if needed (e.g. custom header)
- [ ] RPCs `approve_verification` and `reject_verification` are restricted to `service_role`
