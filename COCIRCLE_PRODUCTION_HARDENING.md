# CoCircle Production Hardening – Final Pass

## 1) Flutter: Direct SELECT from `profiles`

**Search result: ZERO direct SELECT from profiles.**

All profile access uses RPCs:
- `profile_repository.dart`: `get_my_profile`, `get_public_profile`, `search_public_profiles` (fetchMyProfile, fetchUserProfile, searchUsers, fetchNotificationPreferences)
- `profile_role_service.dart`: `get_my_profile` (ensureProfileExists checks via RPC)
- `profile_repository.dart` lines 100, 122: `from('profiles').update()` – UPDATE only, no SELECT
- `profile_role_service.dart` line 45: `from('profiles').insert()` – INSERT only

**No Flutter code changes required for task 1.**

---

## 2) Flutter: UPDATE on `posts` with likes_count or comments_count

**Search result: ZERO such UPDATEs.**

No `.from('posts').update(...)` with `likes_count` or `comments_count` exists. Counts are:
- Updated by DB triggers (post_likes, post_comments)
- Read via SELECT (toggleLike refetches `likes_count` after like/unlike)
- Displayed from feed RPC / fetchUserPosts response

**No Flutter code changes required for task 2.**

---

## 3) SQL Migration Changes

### 3a) get_cocircle_feed – p_limit clamp

```sql
-- Add after "IF auth.uid() IS NULL THEN RETURN; END IF;"
  p_limit := GREATEST(1, LEAST(p_limit, 50));
```

### 3b) search_public_profiles – p_limit clamp

```sql
-- Add after "IF trim(coalesce(p_query, '')) = '' THEN RETURN; END IF;"
  p_limit := GREATEST(1, LEAST(p_limit, 50));
```

### 3c) get_notification_push – remove GRANT to authenticated

```diff
 REVOKE ALL ON FUNCTION public.get_notification_push(uuid) FROM PUBLIC;
 GRANT EXECUTE ON FUNCTION public.get_notification_push(uuid) TO service_role;
-GRANT EXECUTE ON FUNCTION public.get_notification_push(uuid) TO authenticated;
 ALTER FUNCTION public.get_notification_push(uuid) OWNER TO postgres;
```

### 3d) rebuild_follow_counts – new admin RPC (service_role only)

```sql
-- rebuild_follow_counts: admin-only, recompute followers_count/following_count from user_follows
CREATE OR REPLACE FUNCTION public.rebuild_follow_counts()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles p
  SET
    followers_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.following_id = p.id),
    following_count = (SELECT COUNT(*)::INTEGER FROM public.user_follows uf WHERE uf.follower_id = p.id);
END $$;

REVOKE ALL ON FUNCTION public.rebuild_follow_counts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebuild_follow_counts() TO service_role;
ALTER FUNCTION public.rebuild_follow_counts() OWNER TO postgres;
```

---

## 4) Exact Code Diffs

### Flutter: no changes

No edits were made to Flutter code for tasks 1 and 2.

### SQL: `supabase/migrations/20250213_cocircle_feed_fix.sql`

All four migration changes above have been applied in the migration file.

---

## 5) Manual Test Checklist

### Feed author display
- [ ] Feed shows `@username` (not UUID) for each post author
- [ ] Author avatar displays correctly
- [ ] Author full name displays when available
- [ ] Tapping author navigates to correct profile

### Follow/unfollow counts
- [ ] Profile page shows correct follower count before follow
- [ ] After following, follower count increases by 1
- [ ] After unfollowing, follower count decreases by 1
- [ ] Following count updates correctly on both profiles
- [ ] Counts persist after app restart / refresh

### Friends visibility
- [ ] Post with visibility `friends` is hidden from non-followers
- [ ] Post with visibility `friends` is visible to followers
- [ ] Post with visibility `public` is visible to all authenticated users
- [ ] Own posts always visible regardless of visibility

### Like/comment count correctness after refresh
- [ ] Like a post → like count increases by 1
- [ ] Unlike a post → like count decreases by 1
- [ ] Add comment → comment count increases by 1
- [ ] Delete comment (if supported) → comment count decreases by 1
- [ ] Pull-to-refresh feed → counts match DB
- [ ] Navigate away and back → counts still correct

### Notifications
- [ ] Like on post creates notification for author
- [ ] Comment on post creates notification for author
- [ ] Follow creates notification for followed user
- [ ] Push notification sent when user has `notification_push = true`
- [ ] Push notification skipped when user has `notification_push = false`

### Search & limits
- [ ] `search_public_profiles` returns max 50 results
- [ ] `get_cocircle_feed` returns max 50 posts per page
- [ ] Pagination works with keyset cursor

### Admin (optional)
- [ ] Run `SELECT rebuild_follow_counts();` via service_role to fix counts if needed
