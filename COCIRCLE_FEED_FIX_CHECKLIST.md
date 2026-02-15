# CoCircle Feed Fix - Manual Test Checklist

## Prerequisites
1. Run the migration: `supabase/migrations/20250213_cocircle_feed_fix.sql` in Supabase SQL Editor
2. Ensure profiles have `username`, `full_name`, `avatar_url` populated (signup flow or backfill)

## Test Flow

### 1. Signup
- [ ] Create new account with username (e.g. `testuser`)
- [ ] Profile created with username, full_name (if provided)

### 2. Create Post
- [ ] Navigate to CoCircle
- [ ] Tap + to create post
- [ ] Add caption, optionally media
- [ ] Post appears in feed

### 3. Feed Shows Correct Author
- [ ] Feed shows **@username** (e.g. `@testuser`), NOT UUID
- [ ] Avatar displays correctly
- [ ] Full name displays correctly
- [ ] No `@` followed by UUID

### 4. Follow
- [ ] Open another user's profile (search or tap post author)
- [ ] Tap Follow
- [ ] Button changes to Following
- [ ] Follower count increments on their profile

### 5. Friends Posts Show
- [ ] User A follows User B
- [ ] User B creates post with visibility = `friends`
- [ ] User A sees the post in feed
- [ ] Non-followers do NOT see friends-only posts

### 6. Like
- [ ] Tap like on a post
- [ ] Like count increments
- [ ] Tap again to unlike
- [ ] Like count decrements
- [ ] Counts stay correct (no drift after refresh)

### 7. Like Notification
- [ ] User B likes User A's post
- [ ] User A receives notification: "X liked your post"

### 8. Comment
- [ ] Tap comment, add text, submit
- [ ] Comment appears in list
- [ ] comments_count increments
- [ ] Count stays correct after refresh

### 9. Comment Notification
- [ ] User B comments on User A's post
- [ ] User A receives notification: "X commented on your post"

### 10. Profile Counts
- [ ] Profile page shows correct followers_count
- [ ] Profile page shows correct following_count
- [ ] Follow/Unfollow updates counts correctly

### 11. Follow Notification
- [ ] User B follows User A
- [ ] User A receives notification: "X started following you"
