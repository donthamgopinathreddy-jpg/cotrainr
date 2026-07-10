# Retool — Verification Document Preview (Production)

Use the **existing** REST API resource for Supabase Edge Functions only.  
Do **not** create another resource. Do **not** use the SQL/Postgres resource for previews.

**Unchanged (keep as-is):**
- `list_pending_verifications` (Supabase RPC resource)
- `approve_verification_v2` (Supabase RPC resource)
- `reject_verification_v2` (Supabase RPC resource)

---

## 1. State variables

| Name | Type | Purpose |
|------|------|---------|
| `selectedSubmission` | Object | Current row under review (set on table row click) |
| `rejectionNotes` | String | Bound to rejection `TextArea` |
| `adminUserId` | String | **Supabase `auth.users.id`** from `admin_resolve_actor_id` RPC — see `docs/RETOOL_ACTOR_RESOLVER.md` |

**Never** bind `adminUserId` to `retoolContext.user.id` (Retool ID ≠ `auth.users` UUID → FK failure on approve).

**Never** display `certificate_path` or `gov_id_path` in the UI. Paths are only sent in the signed-URL request body.

---

## 2. REST queries (Edge Functions resource)

Create **two** queries on the **same** Edge Functions REST resource.

### `getCertificateSignedUrl`

| Field | Value |
|-------|-------|
| Resource | Existing Supabase Edge Functions REST resource |
| Method | `POST` |
| URL path | `/get-verification-signed-url` |
| Run query on page load | Off |
| Automatically run when inputs change | Off |

**Body (JSON):**

```json
{
  "path": "{{ selectedSubmission.value.certificate_path }}"
}
```

### `getGovIdSignedUrl`

| Field | Value |
|-------|-------|
| Resource | Same Edge Functions REST resource |
| Method | `POST` |
| URL path | `/get-verification-signed-url` |
| Run query on page load | Off |
| Automatically run when inputs change | Off |

**Body (JSON):**

```json
{
  "path": "{{ selectedSubmission.value.gov_id_path }}"
}
```

**Expected response (both):**

```json
{
  "signedUrl": "https://..."
}
```

---

## 3. Open review drawer (table row click)

**Do not** open the drawer on row click alone. Run previews first, then open.

### Table → Event handler → Click row

```javascript
// 1) Save selection (no path fields shown in UI)
selectedSubmission.setValue(verificationTable.selectedRow.data);

// 2) Start signed URL fetches
getCertificateSignedUrl.trigger();
getGovIdSignedUrl.trigger();

// 3) Open drawer after requests are triggered
verificationDrawer.open();
```

Replace `verificationTable` with your table component name if different.

**Optional:** Clear previous preview state before opening:

```javascript
getCertificateSignedUrl.reset();
getGovIdSignedUrl.reset();
selectedSubmission.setValue(verificationTable.selectedRow.data);
getCertificateSignedUrl.trigger();
getGovIdSignedUrl.trigger();
verificationDrawer.open();
```

---

## 4. Image bindings

| Component | `src` / source |
|-----------|----------------|
| Certificate image | `{{ getCertificateSignedUrl.data.signedUrl }}` |
| Government ID image | `{{ getGovIdSignedUrl.data.signedUrl }}` |

**Loading spinners**

| Component | Visible when |
|-----------|----------------|
| Certificate spinner | `{{ getCertificateSignedUrl.isFetching }}` |
| Gov ID spinner | `{{ getGovIdSignedUrl.isFetching }}` |

**Hide image while loading or on error**

| Component | Hidden when |
|-----------|-------------|
| Certificate image | `{{ getCertificateSignedUrl.isFetching \|\| getCertificateSignedUrl.error \|\| !getCertificateSignedUrl.data?.signedUrl }}` |
| Gov ID image | `{{ getGovIdSignedUrl.isFetching \|\| getGovIdSignedUrl.error \|\| !getGovIdSignedUrl.data?.signedUrl }}` |

---

## 5. Error messages (no storage paths)

Show generic copy only. **Do not** bind `error.message` if it might echo the path.

### Certificate error text

**Visible when:**

```javascript
{{ getCertificateSignedUrl.error && !getCertificateSignedUrl.isFetching }}
```

**Text (static):**

```
Unable to load the certificate preview. Please close and reopen this request, or try again later.
```

### Government ID error text

**Visible when:**

```javascript
{{ getGovIdSignedUrl.error && !getGovIdSignedUrl.isFetching }}
```

**Text (static):**

```
Unable to load the government ID preview. Please close and reopen this request, or try again later.
```

---

## 6. Approve button

**Disabled when** (any true → disabled):

```javascript
{{
  getCertificateSignedUrl.isFetching
  || getGovIdSignedUrl.isFetching
  || getCertificateSignedUrl.error
  || getGovIdSignedUrl.error
  || !getCertificateSignedUrl.data?.signedUrl
  || !getGovIdSignedUrl.data?.signedUrl
}}
```

**On click:** existing `approveVerification` query (unchanged):

```json
{
  "p_submission_id": "{{ selectedSubmission.value.id }}",
  "p_actor_id": "{{ adminUserId.value }}"
}
```

RPC: `approve_verification_v2` on the Supabase admin resource.

---

## 7. Reject button

**Disabled when:**

```javascript
{{
  !rejectionNotes.value
  || rejectionNotes.value.trim() === ''
}}
```

Rejection notes are required before reject is enabled (independent of preview success — admin may reject bad/unreadable docs).

**On click:** existing `rejectVerification` query (unchanged):

```json
{
  "p_submission_id": "{{ selectedSubmission.value.id }}",
  "p_actor_id": "{{ adminUserId.value }}",
  "p_notes": "{{ rejectionNotes.value }}"
}
```

RPC: `reject_verification_v2` on the Supabase admin resource.

---

## 8. Drawer content (safe fields only)

Display only:

- `selectedSubmission.value.full_name`
- `selectedSubmission.value.email`
- `selectedSubmission.value.provider_type`
- `selectedSubmission.value.submitted_at`
- `selectedSubmission.value.gov_id_type` (if returned by `list_pending_verifications`)

**Do not display:** `certificate_path`, `gov_id_path`, `user_id` in the drawer unless you have a strict admin need (user_id is optional for support).

---

## 9. Pending list (unchanged)

| Query | RPC | Params |
|-------|-----|--------|
| `listTrainerPending` | `list_pending_verifications` | `{ "p_provider_type": "trainer" }` |
| `listNutritionistPending` | `list_pending_verifications` | `{ "p_provider_type": "nutritionist" }` |

Table data: `{{ listTrainerPending.data }}` (or nutritionist variant).

---

## 10. Success handlers (unchanged)

After `approveVerification` or `rejectVerification` success:

1. `listTrainerPending.trigger()` (or nutritionist list)
2. `verificationDrawer.close()`
3. `rejectionNotes.setValue('')`
4. `selectedSubmission.setValue(null)`
5. Success toast

---

## 11. Checklist

- [ ] Both preview queries use the **Edge Functions REST** resource only
- [ ] URL path is `POST /get-verification-signed-url`
- [ ] Images bind to `.data.signedUrl` (not `.data.url`)
- [ ] Approve disabled until **both** signed URLs succeed
- [ ] Reject disabled until notes are non-empty
- [ ] No storage paths visible in the UI
- [ ] No placeholder images
- [ ] `approve_verification_v2` / `reject_verification_v2` unchanged
- [ ] Edge function deployed: `supabase functions deploy get-verification-signed-url`
