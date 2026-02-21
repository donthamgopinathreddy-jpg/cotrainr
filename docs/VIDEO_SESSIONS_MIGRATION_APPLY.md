# Video Sessions Hardening Migration – Apply & Verify

**Do not consider the migration applied until all verification checks pass.**

---

## Definition: "Applied"

The migration is **applied** only when all of the following are true:

| # | Requirement |
|---|-------------|
| a | No duplicates in `video_session_participants` (0 rows from duplicates query) |
| b | Unique index `uq_video_session_participants_session_user` exists |
| c | Provider CHECK constraint exists and includes `external` |
| d | (Optional) `role` and `created_at` columns exist on `video_session_participants` |
| e | Provider distribution sanity check: all `provider` values in `video_sessions` are in `('zoom','meet','jitsi','manual','external')` |

---

## 1. Apply steps

**Prerequisite:** The Zoom schema must exist. Run `supabase/scripts/verify_video_sessions_prereqs.sql` first. If `video_session_participants exists` or `video_sessions.provider exists` is false, run `supabase/migrations/20250215_video_sessions_zoom.sql` before the hardening migration.

### Option A: Supabase Dashboard SQL Editor

1. Open your Supabase project → **SQL Editor**
2. If needed, run `20250215_video_sessions_zoom.sql` first (creates `video_sessions` with `provider`, `video_session_participants`)
3. Create a new query and copy the full contents of `supabase/migrations/20250215_video_sessions_participants_and_external.sql`
4. Paste into the editor and click **Run**
5. Note any errors (migration is not applied if errors occur)

### Option B: Supabase CLI (when linked)

```bash
supabase link
supabase db push
```

---

## 2. Verification queries

**First:** Run `supabase/scripts/verify_video_sessions_prereqs.sql`. If any result is false, run `20250215_video_sessions_zoom.sql` before continuing.

**Then:** Run each query in `supabase/scripts/verify_video_sessions_migration.sql`. Use the results to fill the decision table below.

### a) Duplicates check

```sql
SELECT session_id, user_id, COUNT(*)
FROM public.video_session_participants
GROUP BY 1,2 HAVING COUNT(*) > 1;
```

### b) Index existence

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname='public'
  AND tablename='video_session_participants'
  AND indexname='uq_video_session_participants_session_user';
```

### c) Provider constraint

```sql
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid='public.video_sessions'::regclass
  AND conname='video_sessions_provider_check';
```

### d) Column existence (role, created_at)

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_schema='public'
  AND table_name='video_session_participants'
  AND column_name IN ('role','created_at');
```

### e) Provider distribution in video_sessions

```sql
SELECT provider, COUNT(*)
FROM public.video_sessions
GROUP BY 1 ORDER BY 2 DESC;
```

### f) Role distribution in video_session_participants (if role column exists)

```sql
SELECT role, COUNT(*)
FROM public.video_session_participants
GROUP BY 1;
```

---

## 3. Decision table

Fill in PASS/FAIL based on query results. **Migration is applied only if all required checks are PASS.**

| Check | PASS criteria | FAIL criteria | Result |
|-------|---------------|---------------|--------|
| **a) No duplicates** | Query returns 0 rows | Query returns ≥1 row | |
| **b) Unique index exists** | Query returns 1 row | Query returns 0 rows | |
| **c) Provider CHECK includes external** | Query returns 1 row and `pg_get_constraintdef` contains `'external'` | 0 rows, or definition lacks `external` | |
| **d) role/created_at exist** (optional) | Query returns 2 rows | Query returns &lt;2 rows | |
| **e) Provider distribution valid** | All `provider` values in (e) are in `zoom`, `meet`, `jitsi`, `manual`, `external` | Any provider value outside that set | |
| **f) Role distribution** (optional, if role exists) | Query runs without error; values are `host` or `participant` | Query errors or unexpected values | |

---

## 4. Final status

- **If all required checks (a, b, c, e) are PASS:** Migration is applied.
- **If any required check is FAIL:** Migration is not applied. Fix the cause and re-run migration and verification.

---

## 5. If errors occur

- **Unique index fails:** Rows from query (a) are offending duplicates. Re-run migration after fixing data.
- **Constraint fails:** Another provider constraint may exist; drop it first or adjust the migration.
- **Permission denied:** Ensure the SQL Editor uses a role with `ALTER TABLE` and `CREATE INDEX` on `public`.
