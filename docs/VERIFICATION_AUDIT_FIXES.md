# Verification Feature Audit – Issues & Fixes

**Date:** 2025-02-19  
**Scope:** SQL migrations, Flutter wiring, storage, RPCs, RLS, security

---

## 1. Risk Summary

| Risk | Severity | Impact |
|------|----------|--------|
| **Storage upsert fails** | **HIGH** | Second upload (overwrite) fails with RLS; users cannot re-upload docs |
| **Admin missing gov_id_type** | Medium | Retool cannot display ID type in admin panel |
| **govIdType not trimmed** | Low | Whitespace could violate CHECK constraint on edge cases |
| **Orphan files on 23505** | Low | Race: upload succeeds, insert fails → first row points to overwritten files (acceptable) |

**No destructive changes.** All fixes are additive or backward-compatible.

---

## 2. Issues Found

### Issue 1: Missing storage UPDATE policy for verification-docs (CRITICAL)

**File:** `supabase/migrations/20250216_verification_workflow.sql`  
**Lines:** 92–117

**Problem:** `StorageService` uses `upsert: true` for credential and gov_id uploads. Supabase storage upsert requires **UPDATE** policy on `storage.objects`. Current policies: INSERT, SELECT, DELETE only. Second upload (e.g. user changes image) fails with RLS violation.

**Breaking risk:** Users cannot overwrite/replace verification docs; upload fails silently or with generic error.

---

### Issue 2: list_pending_verifications omits gov_id_type

**File:** `supabase/migrations/20250216_verification_workflow.sql`  
**Lines:** 264–298

**Problem:** RPC return type does not include `gov_id_type`. Retool admin cannot display which ID type the provider selected.

**Breaking risk:** None. Additive change.

---

### Issue 3: govIdType not trimmed before insert

**File:** `lib/repositories/verification_repository.dart`  
**Line:** 88

**Problem:** CHECK constraint requires `length(trim(gov_id_type)) > 0` for pending. If UI ever sends whitespace-only, insert fails.

**Breaking risk:** Low. Dropdown values are clean; trim is defensive.

---

### Issue 4: Rejected flow – no refresh after "Submit New Documents"

**File:** `lib/pages/trainer/verification_submission_page.dart`  
**Lines:** 205–206

**Problem:** When user clicks "Submit New Documents" after rejection, `_submissionStatus` is set to `null` but `_loadRoleAndSubmission()` is not re-run. Form appears correctly; on successful submit, `_submissionStatus` is set to `'pending'` in the catch block. Flow works. **No fix needed** – verified correct.

---

## 3. Patches

### Patch 1: Add storage UPDATE policy for verification-docs

**File:** `supabase/migrations/20250216_verification_workflow.sql`

**Insert after line 100** (after INSERT policy, before SELECT):

```sql
DROP POLICY IF EXISTS "Providers can update own verification docs" ON storage.objects;
CREATE POLICY "Providers can update own verification docs"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'verification-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

---

### Patch 2: Add gov_id_type to list_pending_verifications

**File:** `supabase/migrations/20250216_verification_workflow.sql`

**Replace lines 264–298** with:

```sql
CREATE OR REPLACE FUNCTION public.list_pending_verifications(p_provider_type public.provider_type DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  provider_type public.provider_type,
  status TEXT,
  certificate_path TEXT,
  gov_id_path TEXT,
  gov_id_type TEXT,
  submitted_at TIMESTAMPTZ,
  full_name TEXT,
  email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    vs.id,
    vs.user_id,
    vs.provider_type,
    vs.status,
    vs.certificate_path,
    vs.gov_id_path,
    vs.gov_id_type,
    vs.submitted_at,
    p.full_name,
    au.email
  FROM public.verification_submissions vs
  LEFT JOIN public.profiles p ON p.id = vs.user_id
  LEFT JOIN auth.users au ON au.id = vs.user_id
  WHERE vs.status = 'pending'
    AND (p_provider_type IS NULL OR vs.provider_type = p_provider_type)
  ORDER BY vs.submitted_at ASC;
END;
$$;
```

---

### Patch 3: Trim govIdType in repository

**File:** `lib/repositories/verification_repository.dart`

**Replace line 88** (`'gov_id_type': govIdType,`) with:

```dart
'gov_id_type': govIdType.trim(),
```

---

## 4. Verification Queries & Test Steps

### SQL – Storage policy

```sql
-- Verify UPDATE policy exists
SELECT policyname, cmd FROM pg_policies
WHERE tablename = 'objects' AND schemaname = 'storage'
  AND policyname LIKE '%verification%';
-- Expect: Providers can upload, update, read, delete own verification docs
```

### SQL – list_pending_verifications

```sql
SELECT * FROM list_pending_verifications('trainer') LIMIT 1;
-- Expect: gov_id_type column present
```

### SQL – RLS on verification_submissions

```sql
-- As authenticated user: can only SELECT/INSERT own
SET ROLE authenticated;
SET request.jwt.claim.sub = '<some-user-uuid>';
SELECT * FROM verification_submissions WHERE user_id = '<some-user-uuid>';
-- Expect: returns own rows only
```

### Flutter – Storage upsert

1. Submit verification with credential + gov_id.
2. Before admin reviews, go back to form (e.g. after rejection), pick different images, submit again.
3. Expect: upload succeeds; no RLS error.

### Flutter – 23505 handling

1. Submit verification once → success.
2. In another tab/session, submit again (or bypass pre-check).
3. Expect: "You already have a pending submission. Please wait for review."

### Flutter – gov_id_type required

1. Leave gov ID type unselected, try submit.
2. Expect: "Please select government ID type" snackbar.

---

## 5. RLS & Security Model

| Component | Policy | Correct? |
|-----------|--------|----------|
| **verification_submissions** | SELECT own, INSERT own (pending only) | Yes |
| **verification_submissions** | No UPDATE for providers | Yes – RPC only |
| **storage.objects (verification-docs)** | INSERT own folder | Yes |
| **storage.objects (verification-docs)** | UPDATE own folder | **Missing** – Patch 1 |
| **storage.objects (verification-docs)** | SELECT own folder | Yes |
| **storage.objects (verification-docs)** | DELETE own folder | Yes |
| **approve_verification** | service_role only | Yes |
| **reject_verification** | service_role only | Yes |
| **list_pending_verifications** | service_role only | Yes |
| **protect_providers_verified** | Blocks direct UPDATE of verified | Yes |

**No privilege escalation.** Providers cannot approve themselves; RPCs are service_role-only.

---

## 6. Migration Idempotency

| Migration | Idempotent? |
|-----------|-------------|
| 20250216_verification_workflow | Yes – CREATE IF NOT EXISTS, DROP IF EXISTS, ON CONFLICT |
| 20250216_verification_gov_id_type | Yes – ADD COLUMN IF NOT EXISTS, DROP CONSTRAINT IF EXISTS |

---

## 7. Files Modified

| File | Change |
|------|--------|
| `supabase/migrations/20250219_verification_audit_fixes.sql` | **New** – Add UPDATE policy; add gov_id_type to list_pending_verifications |
| `lib/repositories/verification_repository.dart` | Trim govIdType before insert |

**Migration order:** Run `20250219_verification_audit_fixes.sql` after `20250216_verification_workflow.sql` and `20250216_verification_gov_id_type.sql`.
