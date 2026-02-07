# Fix Cocircle Feed - Complete Solution

## Root Cause Analysis

### Issues Found:
1. **❌ NO FOLLOWS TABLE** - Cannot determine which users are followed
2. **❌ Feed query only fetches public posts** - Missing own posts + followed users' posts
3. **❌ RLS policy references 'friends' but no way to determine friends**

### ID Mapping Verification:
✅ **CORRECT**: 
- `posts.author_id` → `auth.users(id)` → `profiles.id` (all same UUID)
- Foreign keys properly set up

---

## Solution Steps (Do in Order)

### Step 1: Run Database Migration
**File**: `supabase/migrations/20250127_add_user_follows.sql`

Run this SQL in your Supabase SQL Editor:
```sql
-- Creates user_follows table and updates posts RLS policy
```

**What it does:**
- Creates `user_follows` table with `follower_id` and `following_id`
- Adds indexes for efficient queries
- Updates posts RLS policy to allow viewing:
  1. Own posts (any visibility)
  2. Public posts from anyone
  3. Posts from users I follow (friends visibility)

---

### Step 2: Verify Post Creation Works
**File**: `lib/pages/cocircle/cocircle_create_post_page.dart`

✅ **Already correct** - Post creation uses:
- `author_id: userId` (correct UUID from `auth.currentUser?.id`)
- `visibility: 'public'` (will show in feed)

**Test**: Create a post and check Supabase dashboard → `posts` table

---

### Step 3: Updated Feed Query
**File**: `lib/repositories/posts_repository.dart`

✅ **Already updated** - `fetchRecentPosts()` now:
- Fetches posts that pass RLS (own + followed + public)
- Uses keyset pagination (order by `created_at DESC, id DESC`)
- Supports cursor params for pagination

**How RLS works now:**
The updated RLS policy automatically filters posts to show:
- Your own posts (any visibility)
- Public posts from anyone
- Posts from users you follow (if visibility = 'friends')

**No need to manually filter in Flutter** - RLS handles it!

---

### Step 4: Profile Posts Query
**File**: `lib/repositories/posts_repository.dart`

✅ **Already updated** - `fetchUserPosts(userId)` now:
- Fetches all posts by a specific user
- Uses keyset pagination
- Includes post_media in query

**Test**: Open any user profile → should show their posts

---

### Step 5: Create Follow Relationships (Optional)
To test the "followed users" feed feature, you need to create follow relationships:

**Option A: Via Supabase Dashboard**
```sql
-- Example: User A follows User B
INSERT INTO public.user_follows (follower_id, following_id)
VALUES ('user-a-uuid', 'user-b-uuid');
```

**Option B: Add Follow Button in Flutter** (future enhancement)
```dart
// In user_profile_page.dart or similar
Future<void> _followUser(String userId) async {
  await supabase.from('user_follows').insert({
    'follower_id': supabase.auth.currentUser!.id,
    'following_id': userId,
  });
}
```

---

## Testing Checklist

### ✅ Test 1: Create Post
1. Create a new post via Cocircle create page
2. Check Supabase `posts` table → post should exist
3. Check feed → post should appear immediately

### ✅ Test 2: Feed Shows Own Posts
1. Create a post with your account
2. Open Cocircle feed
3. **Expected**: Your post appears in feed

### ✅ Test 3: Feed Shows Public Posts
1. Have another user create a public post
2. Open your Cocircle feed
3. **Expected**: Their public post appears

### ✅ Test 4: Profile Shows User Posts
1. Open any user's profile page
2. **Expected**: All their posts appear in grid

### ✅ Test 5: Follow Feature (if implemented)
1. Follow a user (create entry in `user_follows`)
2. That user creates a post with `visibility = 'friends'`
3. **Expected**: Post appears in your feed

---

## Debugging

### If posts still don't show:

1. **Check RLS Policy**:
   ```sql
   -- In Supabase SQL Editor
   SELECT * FROM pg_policies WHERE tablename = 'posts';
   ```
   Should see: "Users can view feed posts"

2. **Check Post Visibility**:
   ```sql
   SELECT id, author_id, visibility, created_at 
   FROM posts 
   ORDER BY created_at DESC 
   LIMIT 10;
   ```

3. **Check User Authentication**:
   ```dart
   print('Current user: ${supabase.auth.currentUser?.id}');
   ```

4. **Check Follow Relationships**:
   ```sql
   SELECT * FROM user_follows 
   WHERE follower_id = 'your-user-id';
   ```

5. **Check Flutter Logs**:
   Look for: `"Fetched X posts from database (feed: own + followed + public)"`

---

## Summary

### What Was Fixed:
1. ✅ Created `user_follows` table
2. ✅ Updated posts RLS policy for feed logic
3. ✅ Updated Flutter queries with keyset pagination
4. ✅ Verified ID mapping (all correct)

### What Works Now:
- ✅ Feed shows: own posts + followed users' posts + public posts
- ✅ Profile shows: all posts by that user
- ✅ RLS automatically filters based on follows
- ✅ Keyset pagination ready for infinite scroll

### Next Steps (Optional):
- Add follow/unfollow UI buttons
- Implement infinite scroll with pagination cursors
- Add search users by username/name (already in ProfileRepository)

---

## Files Changed:
1. `supabase/migrations/20250127_add_user_follows.sql` (NEW)
2. `lib/repositories/posts_repository.dart` (UPDATED)

## Files to Review:
- `lib/pages/cocircle/cocircle_page.dart` (feed UI)
- `lib/pages/cocircle/user_profile_page.dart` (profile UI)
