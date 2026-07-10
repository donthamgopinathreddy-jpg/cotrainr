# Retool — Admin Actor Resolver (verification FK fix)

## Problem

`verification_submissions.reviewer_id` references **`auth.users(id)`**.

Retool was passing `retoolContext.user.id` (Retool workspace user ID) as `p_actor_id`. That UUID is **not** in `auth.users`, causing:

```
violates foreign key constraint "verification_submissions_reviewer_id_fkey"
```

## Correct actor UUID

| Field | Must be |
|-------|---------|
| `p_actor_id` / `reviewer_id` | `auth.users.id` |
| Source of truth | `admin_users.user_id` (also FK → `auth.users`) |

**Never use** `retoolContext.user.id` directly unless it equals a Supabase `auth.users.id` (it does not by default).

---

## 1. Page load — resolve actor

### Query: `resolveActorId`

| Field | Value |
|-------|-------|
| Resource | Supabase admin (service_role) |
| Type | RPC |
| RPC | `admin_resolve_actor_id` |
| Run on page load | **On** |

**Params:**

```json
{
  "p_email": "{{ current_user.email }}"
}
```

**Expected success:**

```json
{
  "ok": true,
  "actor_id": "uuid-from-auth-users",
  "email": "admin@example.com"
}
```

**Expected failure:**

```json
{
  "ok": false,
  "error": "ADMIN_ACTOR_NOT_MAPPED",
  "detail": "..."
}
```

### State: `adminUserId`

On `resolveActorId` success:

```javascript
// Event: resolveActorId → Success
if (resolveActorId.data?.ok === true) {
  adminUserId.setValue(resolveActorId.data.actor_id);
} else {
  adminUserId.setValue(null);
  utils.showNotification({
    title: 'Admin not mapped',
    description: resolveActorId.data?.detail ?? 'ADMIN_ACTOR_NOT_MAPPED',
    notificationType: 'error',
  });
}
```

**Block approve/reject** when `adminUserId.value` is null:

```javascript
// approveBtn disabled
{{ !adminUserId.value || !getCertificateSignedUrl.data?.signedUrl || !getGovIdSignedUrl.data?.signedUrl }}
```

---

## 2. Backend function (alternative to RPC on load)

If using a Retool **Backend function** instead of a query:

```javascript
async function resolveActorId(req_user) {
  const email = req_user?.email?.trim()?.toLowerCase();
  if (!email) {
    return { ok: false, error: 'ADMIN_ACTOR_NOT_MAPPED', detail: 'Retool user email is empty' };
  }

  const res = await supabaseAdmin.rpc('admin_resolve_actor_id', { p_email: email });
  const data = res?.data ?? res;

  if (!data?.ok || !data?.actor_id) {
    return {
      ok: false,
      error: data?.error ?? 'ADMIN_ACTOR_NOT_MAPPED',
      detail: data?.detail ?? 'No admin_users mapping for this email',
    };
  }

  return { ok: true, actor_id: data.actor_id, email: data.email };
}
```

**Do not** fall back to `req_user.id` or `retoolContext.user.id`.

---

## 3. Approve / Reject RPC params (unchanged shape, fixed UUID)

### `approveVerification`

```json
{
  "p_submission_id": "{{ selectedSubmission.value.id }}",
  "p_actor_id": "{{ adminUserId.value }}"
}
```

RPC: `approve_verification_v2`

### `rejectVerification`

```json
{
  "p_submission_id": "{{ selectedSubmission.value.id }}",
  "p_actor_id": "{{ adminUserId.value }}",
  "p_notes": "{{ rejectionNotes.value }}"
}
```

RPC: `reject_verification_v2`

### Success handler

```javascript
if (approveVerification.data?.ok !== true) {
  utils.showNotification({
    title: 'Approve failed',
    description: approveVerification.data?.detail ?? approveVerification.data?.error ?? 'Unknown error',
    notificationType: 'error',
  });
  return;
}
// refresh list, close drawer, toast success
```

---

## 4. Bootstrap admin (one-time SQL)

Run in Supabase SQL Editor:

```sql
-- 1) Find your Supabase auth user (admin login email)
SELECT id, email FROM auth.users WHERE email = 'your-admin@email.com';

-- 2) Register as admin (replace UUID)
SELECT public.admin_add_admin_user('PASTE-auth-users-uuid-here'::uuid, NULL);

-- 3) Verify mapping
SELECT public.admin_resolve_actor_id('your-admin@email.com');
```

Retool login email **must match** `auth.users.email` for the mapped admin.

---

## 5. Document preview — unchanged

Keep using Edge Function `get-verification-signed-url` for certificate and gov ID previews. This fix does **not** modify that function.

---

## 6. Test checklist

- [ ] `admin_resolve_actor_id` returns `ok: true` for mapped admin email
- [ ] `adminUserId` state holds auth UUID (not Retool user id)
- [ ] Approve pending trainer → `verified=true`, `discoverable=true`, audit log row
- [ ] Approve pending nutritionist → same
- [ ] Reject with notes → `verified=false`, `discoverable=false`, audit log row
- [ ] `reviewer_id` on submission exists in `auth.users`
- [ ] Unmapped email → `ADMIN_ACTOR_NOT_MAPPED`, approve blocked in UI
- [ ] Signed URL previews still load
