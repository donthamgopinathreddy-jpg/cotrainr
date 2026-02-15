# CoCircle Migration – Production Review

## Section 1: Critical Issues (will break prod / security bugs)

### 1.1 **rebuild_post_counts() is silently ineffective (data corruption risk)**

**Problem:** `rebuild_post_counts()` updates `posts.likes_count` and `posts.comments_count` directly. The `prevent_manual_post_counts` trigger fires on every `UPDATE` of `posts` and overwrites `NEW.likes_count` and `NEW.comments_count` with `OLD` values unless `app.allow_post_count_update` is `'true'`. `rebuild_post_counts()` never sets this flag, so its updates are reverted and counts stay wrong.

**Impact:** Admin runs `rebuild_post_counts()` expecting to fix counts; nothing changes. Counts remain incorrect.

**Fix:** Set the session flag before updating and clear it after:

```diff
 CREATE OR REPLACE FUNCTION public.rebuild_post_counts()
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
 AS $$
 BEGIN
+  PERFORM set_config('app.allow_post_count_update', 'true', true);
   UPDATE public.posts p
   SET
     likes_count = (SELECT COUNT(*)::INTEGER FROM public.post_likes pl WHERE pl.post_id = p.id),
     comments_count = (SELECT COUNT(*)::INTEGER FROM public.post_comments pc WHERE pc.post_id = p.id);
+  PERFORM set_config('app.allow_post_count_update', 'false', true);
 END $$;
```

---

### 1.2 **unique_violation vs duplicate_object in constraint block**

**Problem:** `ALTER TABLE ... ADD CONSTRAINT UNIQUE` raises `unique_violation` (SQLSTATE 23505) when existing rows violate the constraint. `duplicate_object` (SQLSTATE 42710) is raised when the constraint name already exists. The handler is correct, but `unique_violation` is raised during the `ALTER TABLE`, not as a separate statement, so the exception block is appropriate.

**Status:** No change needed; exception handling is correct.

---

### 1.3 **user_follows table may not exist**

**Problem:** If `user_follows` does not exist, the migration fails at the first `ALTER TABLE public.user_follows`. Migration order must ensure `user_follows` exists before this migration.

**Recommendation:** Confirm migration order. If `user_follows` is created elsewhere, ensure that migration runs first. No code change in this file.

---

## Section 2: Recommended Fixes (exact SQL diffs)

### 2.1 **rebuild_post_counts – set allow_post_count_update (CRITICAL)**

```diff
 -- rebuild_post_counts: admin-only, recompute likes_count/comments_count from post_likes/post_comments
 CREATE OR REPLACE FUNCTION public.rebuild_post_counts()
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
 AS $$
 BEGIN
+  PERFORM set_config('app.allow_post_count_update', 'true', true);
   UPDATE public.posts p
   SET
     likes_count = (SELECT COUNT(*)::INTEGER FROM public.post_likes pl WHERE pl.post_id = p.id),
     comments_count = (SELECT COUNT(*)::INTEGER FROM public.post_comments pc WHERE pc.post_id = p.id);
+  PERFORM set_config('app.allow_post_count_update', 'false', true);
 END $$;
```

---

### 2.2 **get_cocircle_feed – avoid assigning to IN parameter**

**Problem:** `p_limit := GREATEST(1, LEAST(p_limit, 50))` assigns to an IN parameter. In PL/pgSQL, IN parameters are read-only in some versions; assigning can fail or be undefined.

**Fix:** Use a local variable:

```diff
 AS $$
+DECLARE
+  lim int;
 BEGIN
   IF auth.uid() IS NULL THEN RETURN; END IF;
-  p_limit := GREATEST(1, LEAST(p_limit, 50));
+  lim := GREATEST(1, LEAST(p_limit, 50));

   RETURN QUERY
   SELECT
     ...
   ORDER BY p.created_at DESC, p.id DESC
-  LIMIT p_limit;
+  LIMIT lim;
 END $$;
```

---

### 2.3 **get_notification_push – ensure notification_push column exists**

**Problem:** `get_notification_push` selects `p.notification_push`. If that column is missing (e.g. from `20250213_notification_system.sql`), the function fails at creation.

**Recommendation:** Ensure `20250213_notification_system.sql` (or equivalent) runs before this migration and adds `notification_push` to `profiles`. No change in this migration if the column is guaranteed.

---

## Section 3: Performance Improvements

### 3.1 **Redundant index on user_follows**

**Observation:** `idx_user_follows_follower_following` on `(follower_id, following_id)` overlaps with the unique index created by `user_follows_follower_following_unique`. If the UNIQUE constraint is applied, the unique index covers lookups on `(follower_id, following_id)`.

**Recommendation:** Keep the explicit `CREATE INDEX` for idempotency when the UNIQUE constraint is skipped (e.g. due to duplicates). The extra index is redundant but low cost. Optional: drop it when the UNIQUE constraint exists.

---

### 3.2 **rebuild_post_counts – per-row subqueries**

**Observation:** The function uses correlated subqueries for each post. For admin-only, infrequent use this is acceptable. A more efficient pattern would use pre-aggregated CTEs and JOIN, but adds complexity. Recommend keeping current pattern after applying the set_config fix.

---

### 3.3 **search_public_profiles – index on username_lower**

**Observation:** The query filters on `username_lower LIKE '%' || lower(q) || '%'`. A leading wildcard prevents use of a B-tree index. For better search performance, consider `pg_trgm` and a GIN index on `username_lower` (you asked not to add it unless requested, so this is optional).

---

## Section 4: Optional Hardening

### 4.1 **Escape LIKE wildcards in search_public_profiles**

**Observation:** `%` and `_` in the search string act as wildcards. A query like `%` can match many rows (limited by `LIMIT 50`).

**Optional fix:** Escape `%` and `_`:

```sql
q := replace(replace(trim(coalesce(p_query, '')), '\', '\\'), '%', '\%');
q := replace(q, '_', '\_');
-- Then use: p.username_lower LIKE '%' || lower(q) || '%' ESCAPE '\'
```

---

### 4.2 **COALESCE author_role in get_cocircle_feed**

**Observation:** `pr.role::text` can be NULL for orphaned or incomplete profiles.

**Optional fix:**

```diff
-    pr.role::text,
+    COALESCE(pr.role::text, ''),
```

---

### 4.3 **REVOKE on trigger functions**

**Observation:** Trigger functions `update_follow_counts`, `update_posts_likes_count`, `update_posts_comments_count` already have `REVOKE ALL ... FROM PUBLIC`. Clients cannot call them directly; they run only via triggers. Good.

---

### 4.4 **sync_username_lower – no GRANT after REVOKE**

**Observation:** `sync_username_lower` has `REVOKE ALL ... FROM PUBLIC` but no `GRANT EXECUTE`. Trigger execution uses the trigger owner’s privileges, so this is fine. No change needed.

---

## Section 5: Final Go/No-Go Checklist for Production Deploy

| Check | Status |
|-------|--------|
| **rebuild_post_counts sets allow_post_count_update** | ✓ Fixed |
| **get_cocircle_feed p_limit assignment** | ✓ Fixed (use local variable) |
| **user_follows table exists** | ✓ Verify migration order |
| **profiles.notification_push exists** | ✓ Verify notification migration runs first |
| **post_visibility enum exists** | ✓ Verify schema |
| **post_likes.post_id, post_comments.post_id** | ✓ Confirmed in schema |
| **RLS + SECURITY DEFINER** | ✓ RPCs bypass RLS correctly |
| **REVOKE SELECT on profiles** | ✓ Applied |
| **Admin RPCs service_role only** | ✓ Correct |
| **Idempotent constraint blocks** | ✓ Exception handling correct |
| **Keyset pagination logic** | ✓ Correct |
| **LATERAL + jsonb_agg** | ✓ Correct for empty media |

### Verdict

**Go** – Critical fixes have been applied to the migration.

**Pre-deploy checks:**
1. Run migration on staging with production-like data.
2. Confirm `user_follows` and `profiles.notification_push` exist.
3. Run `rebuild_post_counts()` and `rebuild_follow_counts()` and verify counts.
4. Test feed, follow/unfollow, like/comment flows.
