# Trainer/Nutritionist Verification Audit Report

**Date:** 2025-02-15  
**Scope:** UI flow, upload destination, database schema, approval mechanism, RLS, admin UI, gaps

---

## 1. UI Flow

### Verification Screens

| Screen | File Path | Route | Role |
|--------|-----------|-------|------|
| **Verification Submission** | `lib/pages/trainer/verification_submission_page.dart` | `/verification` | Trainer & Nutritionist (shared) |
| **Become Trainer** | `lib/pages/trainer/become_trainer_page.dart` | `/trainer/become` | Client → Trainer onboarding |

**Note:** There is no separate nutritionist verification screen. The same `VerificationSubmissionPage` is used for both; role is inferred from `user_metadata['role']` (defaults to `'trainer'`).

### Document Selection & Upload Flow

| Step | Widget/Method | File Path |
|------|---------------|-----------|
| Certificate image pick | `_pickCertificateImage()` → `ImagePicker.pickImage(source: gallery)` | `verification_submission_page.dart:68-81` |
| Government ID image pick | `_pickGovIdImage()` → `ImagePicker.pickImage(source: gallery)` | `verification_submission_page.dart:84-96` |
| Image display | `_buildImageUpload()` → `Image.file()` | `verification_submission_page.dart:414-477` |
| Submit | `_submitVerification()` | `verification_submission_page.dart:99-214` |

**Critical finding:** `_submitVerification()` does **NOT** upload to Supabase. It simulates an API call:

```dart
// Simulate API call - in real app, upload to Supabase
await Future.delayed(const Duration(seconds: 1));
```

Documents are selected and held in memory (`_certificateImage`, `_govIdImage` as `File?`) but **never persisted**.

### Entry Points

| Entry Point | File |
|-------------|------|
| Profile page (trainer/nutritionist) | `lib/pages/trainer/trainer_profile_page.dart`, `lib/pages/nutritionist/nutritionist_profile_page.dart`, `lib/pages/profile/profile_page.dart` |
| Verification card | `_VerificationCard` widget when `_needsVerification` (role is trainer/nutritionist and `providers.verified != true`) |
| Router | `lib/router/app_router.dart:322-329` |

---

## 2. Upload Destination

### Current State: **NONE**

- **No Supabase Storage bucket** exists for verification documents.
- **No database table** stores document URLs or metadata for verification submissions.
- Documents are never uploaded; the flow is UI-only.

### Existing Storage Buckets (for reference)

| Bucket | Purpose | Public | Path Pattern |
|--------|---------|--------|--------------|
| `avatars` | Profile/cover images | Yes | `{userId}/avatar.{ext}`, `{userId}/cover.{ext}` |
| `posts` | Post media | Yes | `{userId}/{timestamp}.{ext}` |

**Source:** `supabase/migrations/20250127_create_storage_buckets.sql`, `20250215_profile_image_save_fix.sql`

---

## 3. Database Schema

### Tables Related to Verification

#### `providers` (primary)

| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID | PK |
| `user_id` | UUID | FK to auth.users |
| `provider_type` | provider_type | `'trainer'` or `'nutritionist'` |
| `specialization` | TEXT[] | Categories |
| `experience_years` | INTEGER | Years of experience |
| `hourly_rate` | NUMERIC | Optional |
| `bio` | TEXT | Optional |
| **`verified`** | **BOOLEAN** | **Verification status (true/false only)** |
| `rating` | NUMERIC | Discovery display |
| `total_reviews` | INTEGER | Discovery display |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

**Source:** `supabase/migrations/20250127_add_missing_tables_safe.sql`, `20250127_complete_schema.sql`

**Gaps:**
- `verified` is boolean only — no `pending`/`rejected` states
- No `submitted_at`, `reviewed_at`, `reviewer_id`, `rejection_notes`
- No document URLs (certificate, gov ID)

#### `trainer_verifications` (legacy, unused)

- Listed in `supabase/DUPLICATE_AND_UNUSED_TABLES_REPORT.md` as **UNUSED**
- No references in Flutter code
- Schema not defined in migrations (likely from older schema)
- Marked for archive: `ALTER TABLE public.trainer_verifications SET SCHEMA archive;`

#### `profiles`

- No verification-related columns
- `role` indicates trainer/nutritionist/client

---

## 4. Approval Mechanism

### Current Representation

| Location | Field | Values |
|----------|-------|--------|
| `providers.verified` | Boolean | `true` = verified, `false` = not verified |

**No** `pending` or `rejected` state. Providers are either verified or not.

### How Verification Status is Read

| File | Method |
|------|--------|
| `lib/pages/trainer/trainer_profile_page.dart` | `Supabase.from('providers').select('verified').eq('user_id', userId).maybeSingle()` |
| `lib/pages/nutritionist/nutritionist_profile_page.dart` | Same pattern |
| Discover page | `nearby_providers()` RPC returns `p.verified` |

### RPCs / Edge Functions for Approval

- **None.** No RPC or Edge Function exists to approve or reject verification.
- Approval would require manual SQL, e.g.:
  ```sql
  UPDATE providers SET verified = true WHERE user_id = '...';
  ```

---

## 5. RLS & Storage Policies

### Providers Table

| Policy | Operation | Condition |
|--------|-----------|-----------|
| "Anyone can view providers" | SELECT | `USING (true)` for authenticated |
| "Providers can update own provider" | UPDATE | `auth.uid() = user_id` |
| "Providers can insert own provider" | INSERT | `auth.uid() = user_id` |

**Source:** `supabase/migrations/20250127_complete_schema.sql`, `20250127_add_missing_tables_safe.sql`

**Implications:**
- Any authenticated user can read all providers (including `verified`)
- Only the provider can update their own row (including `verified`)
- **No admin/service_role policy** — admins cannot update `verified` via RLS without service role bypass

### Verification Tables

- No `verification_submissions` or equivalent table exists
- `trainer_verifications` is unused; no RLS policies referenced

### Storage for Verification Documents

- **No bucket** for verification docs
- **No policies** for verification document storage

---

## 6. Admin UI

### Current State

- **No admin panel** exists in the Flutter app
- **No admin routes** for verification approval
- **No admin-only RPCs** for verification workflow

### Approval Process

- **Manual only** — e.g. via Supabase SQL Editor:
  ```sql
  UPDATE providers SET verified = true WHERE user_id = '<uuid>';
  ```

---

## 7. Gaps Summary

| Gap | Description |
|-----|-------------|
| **Documents not uploaded** | `_submitVerification()` simulates submission; no Supabase Storage upload |
| **No verification bucket** | No bucket for certificate/gov ID images |
| **No submission table** | No table for `verification_submissions` with document URLs, status, timestamps |
| **Boolean-only status** | `providers.verified` cannot represent pending/rejected |
| **No audit trail** | No `reviewer_id`, `reviewed_at`, `rejection_notes` |
| **No admin UI** | No way to review/approve/reject from app |
| **No secure admin doc access** | No storage policy for admins to read verification docs |
| **No approval RPC** | No `approve_verification` / `reject_verification` function |

---

## 8. TODO List: Enable Admin Verification Workflow

### Phase 1: Persist Submissions

- [ ] **1.1** Create Storage bucket `verification-docs` (private)
  - Path pattern: `{user_id}/certificate.{ext}`, `{user_id}/gov_id.{ext}`
  - Policies: providers can INSERT/UPDATE/DELETE own; service_role can SELECT all
- [ ] **1.2** Create table `verification_submissions`:
  ```sql
  CREATE TABLE verification_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    provider_type provider_type NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
    certificate_url TEXT,
    gov_id_url TEXT,
    gov_id_type TEXT,
    category TEXT,
    certificate_name TEXT,
    experience_years INTEGER,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewer_id UUID REFERENCES auth.users(id),
    rejection_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  ```
- [ ] **1.3** Wire `VerificationSubmissionPage._submitVerification()` to:
  - Upload `_certificateImage` and `_govIdImage` to `verification-docs`
  - Insert row into `verification_submissions` with URLs and metadata

### Phase 2: Approval Mechanism

- [ ] **2.1** Create RPC `approve_verification(submission_id UUID)` (service_role or admin role):
  - Set `verification_submissions.status = 'approved'`
  - Set `verification_submissions.reviewed_at = NOW()`, `reviewer_id = auth.uid()`
  - Set `providers.verified = true` for the user
- [ ] **2.2** Create RPC `reject_verification(submission_id UUID, notes TEXT)`:
  - Set `verification_submissions.status = 'rejected'`, `rejection_notes`, `reviewed_at`, `reviewer_id`
  - Optionally notify user (push/email)

### Phase 3: RLS & Storage

- [ ] **3.1** RLS on `verification_submissions`:
  - Providers can SELECT own rows
  - Providers can INSERT own (status pending)
  - Service role / admin can SELECT all, UPDATE (for approval/rejection)
- [ ] **3.2** Storage policies for `verification-docs`:
  - Providers: INSERT/UPDATE/DELETE where `(storage.foldername(name))[1] = auth.uid()::text`
  - Admin: SELECT all (via service role or dedicated policy for admin role)

### Phase 4: Admin UI

- [ ] **4.1** Create admin route (e.g. `/admin/verification`) — guarded by admin role
- [ ] **4.2** Admin page: list pending submissions with provider info, document preview links
- [ ] **4.3** Approve/Reject buttons calling RPCs
- [ ] **4.4** Document viewer: signed URLs for private bucket (via Edge Function or service role)

### Phase 5: Provider UX

- [ ] **5.1** Update `providers.verified` semantics or add `verification_status` enum if keeping boolean
- [ ] **5.2** Show "Pending" vs "Rejected" in `_VerificationCard` when applicable
- [ ] **5.3** Push notification on approval/rejection (optional)

---

## 9. File Paths Reference

| Purpose | Path |
|---------|------|
| Verification submission UI | `lib/pages/trainer/verification_submission_page.dart` |
| Verification card (profile) | `lib/pages/trainer/trainer_profile_page.dart` (lines 136-154, 702-788) |
| Nutritionist profile | `lib/pages/nutritionist/nutritionist_profile_page.dart` |
| Client profile | `lib/pages/profile/profile_page.dart` |
| Router | `lib/router/app_router.dart` |
| Providers schema | `supabase/migrations/20250127_add_missing_tables_safe.sql`, `20250127_complete_schema.sql` |
| Storage buckets | `supabase/migrations/20250127_create_storage_buckets.sql` |

---

## 10. Table & Column Reference

| Table | Columns (verification-related) |
|-------|--------------------------------|
| `providers` | `verified` (BOOLEAN), `provider_type` |
| `verification_submissions` | **Does not exist** — to be created |
| `trainer_verifications` | Legacy, unused, no schema in migrations |

---

## 11. Storage Bucket Reference

| Bucket | Exists | Purpose |
|--------|--------|---------|
| `avatars` | Yes | Profile/cover images |
| `posts` | Yes | Post media |
| `verification-docs` | **No** | To be created for certificate + gov ID |
