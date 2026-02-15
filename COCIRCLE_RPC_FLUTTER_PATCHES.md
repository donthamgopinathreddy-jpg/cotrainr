# CoCircle RPC Flutter Patches

Migration uses SECURITY DEFINER RPCs instead of views (Postgres views cannot be security definer).

## RPCs Available

| RPC | Params | Returns |
|-----|--------|---------|
| `get_my_profile` | none | List (SETOF profiles for auth.uid()) |
| `get_public_profile` | `p_user_id: uuid` | List (single row) |
| `get_public_profiles` | `p_user_ids: uuid[]` | List (batch) |
| `search_public_profiles` | `p_query: text`, `p_limit: int` (default 20) | List |

## Files Changed

### lib/repositories/profile_repository.dart

**fetchMyProfile:**
```dart
final response = await _supabase.rpc('get_my_profile');
final list = (response as List).cast<Map<String, dynamic>>();
return list.isNotEmpty ? list.first : null;
```

**fetchUserProfile:**
```dart
if (userId == _currentUserId) {
  final list = (await _supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
  return list.isNotEmpty ? list.first : null;
}
final list = (await _supabase.rpc('get_public_profile', params: {'p_user_id': userId}) as List).cast<Map<String, dynamic>>();
return list.isNotEmpty ? list.first : null;
```

**searchUsers:**
```dart
final response = await _supabase.rpc('search_public_profiles', params: {'p_query': searchTerm, 'p_limit': limit});
return (response as List).cast<Map<String, dynamic>>();
```

**fetchNotificationPreferences:** Use `get_my_profile` RPC, extract notification columns from first row.

### lib/repositories/follow_repository.dart

**getFollowers / getFollowing:** Replace `profiles_public_v` with:
```dart
final profilesResponse = await _supabase.rpc('get_public_profiles', params: {'p_user_ids': followerIds});
```

### lib/repositories/posts_repository.dart

**fetchUserPosts:** Replace profile fetch with:
```dart
final list = (await _supabase.rpc('get_public_profile', params: {'p_user_id': userId}) as List).cast<Map<String, dynamic>>();
profileData = list.isNotEmpty ? list.first : null;
```

**fetchComments:** Replace profiles batch with:
```dart
final profilesResponse = await _supabase.rpc('get_public_profiles', params: {'p_user_ids': authorIds});
```

**createComment:** Replace profile fetch with:
```dart
final profileList = (await _supabase.rpc('get_public_profile', params: {'p_user_id': userId}) as List).cast<Map<String, dynamic>>();
final profileResponse = profileList.isNotEmpty ? profileList.first : null;
```

### lib/services/profile_role_service.dart

**getCurrentUserRole, getCurrentUserProfile, ensureProfileExists:** Use `get_my_profile` RPC.

### lib/pages/home/home_page.dart, lib/pages/home/home_page_v3.dart

Replace `profiles_own_v` with:
```dart
final list = (await supabase.rpc('get_my_profile') as List).cast<Map<String, dynamic>>();
final profile = list.isNotEmpty ? list.first : null;
```

### lib/pages/notifications/notification_page.dart

**_getActorProfile:** Use `get_public_profile` RPC.

### lib/repositories/messages_repository.dart

Replace `profiles_public_v` with `get_public_profile` RPC for other user profile.

## Feed (posts_repository.dart)

Replace `cocircle_feed_posts_v` view with `get_cocircle_feed` RPC:

```dart
final params = <String, dynamic>{
  'p_limit': limit,
  'p_before_created_at': lastCreatedAt,
  'p_before_id': lastId,
};
final postsResponse = await _supabase.rpc('get_cocircle_feed', params: params);
final posts = (postsResponse as List).cast<Map<String, dynamic>>();
```

Keep the single query for liked status (post_likes where user_id=me and post_id in (...)).
