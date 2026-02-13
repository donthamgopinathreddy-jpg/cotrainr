import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing user follows
class FollowRepository {
  final SupabaseClient _supabase;

  FollowRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Check if current user is following another user
  Future<bool> isFollowing(String userId) async {
    if (_currentUserId == null) return false;

    try {
      final response = await _supabase
          .from('user_follows')
          .select('id')
          .eq('follower_id', _currentUserId!)
          .eq('following_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  /// Follow a user
  Future<bool> followUser(String userId) async {
    if (_currentUserId == null) return false;
    if (_currentUserId == userId) return false; // Can't follow yourself

    try {
      await _supabase.from('user_follows').insert({
        'follower_id': _currentUserId!,
        'following_id': userId,
      });
      return true;
    } catch (e) {
      print('Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    if (_currentUserId == null) return false;

    try {
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', _currentUserId!)
          .eq('following_id', userId);
      return true;
    } catch (e) {
      print('Error unfollowing user: $e');
      return false;
    }
  }

  /// Get follower count for a user
  Future<int> getFollowerCount(String userId) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select('id')
          .eq('following_id', userId);

      return (response as List).length;
    } catch (e) {
      print('Error getting follower count: $e');
      return 0;
    }
  }

  /// Get following count for a user
  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select('id')
          .eq('follower_id', userId);

      return (response as List).length;
    } catch (e) {
      print('Error getting following count: $e');
      return 0;
    }
  }

  /// Get list of followers for a user with follow status
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      // Fetch follower IDs first (user_follows FKs point to auth.users, not profiles)
      final response = await _supabase
          .from('user_follows')
          .select('follower_id')
          .eq('following_id', userId)
          .order('created_at', ascending: false);

      final followerIds = (response as List)
          .map((r) => r['follower_id'] as String)
          .toList();

      if (followerIds.isEmpty) return [];

      // Fetch profiles for follower IDs
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', followerIds);

      final profilesMap = <String, Map<String, dynamic>>{};
      for (final p in profilesResponse as List) {
        profilesMap[p['id'] as String] = p as Map<String, dynamic>;
      }

      final followers = followerIds.map((followerId) {
        return {
          'follower_id': followerId,
          'profiles': profilesMap[followerId],
        };
      }).toList();
      // Get list of user IDs that current user is following (for follow status)
      Set<String> followingIds = {};
      if (_currentUserId != null) {
        final followingResponse = await _supabase
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', _currentUserId!);
        followingIds = (followingResponse as List)
            .map((item) => item['following_id'] as String)
            .toSet();
      }

      for (var follower in followers) {
        final followerId = follower['follower_id'] as String;
        follower['is_following'] = followingIds.contains(followerId);
      }

      return followers;
    } catch (e) {
      print('Error getting followers: $e');
      return [];
    }
  }

  /// Get list of users that a user is following with follow status
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      // Fetch following IDs first
      final response = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', userId)
          .order('created_at', ascending: false);

      final followingIds = (response as List)
          .map((r) => r['following_id'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      // Fetch profiles for following IDs
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', followingIds);

      final profilesMap = <String, Map<String, dynamic>>{};
      for (final p in profilesResponse as List) {
        profilesMap[p['id'] as String] = p as Map<String, dynamic>;
      }

      final following = followingIds.map((followingId) {
        return {
          'following_id': followingId,
          'profiles': profilesMap[followingId],
        };
      }).toList();
      // Add follow status: profile user follows them, check if current user does too
      Set<String> currentUserFollowingIds = {};
      if (_currentUserId != null) {
        final cr = await _supabase
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', _currentUserId!);
        currentUserFollowingIds = (cr as List)
            .map((item) => item['following_id'] as String)
            .toSet();
      }

      for (var user in following) {
        final followingId = user['following_id'] as String;
        user['is_following'] = currentUserFollowingIds.contains(followingId);
      }

      return following;
    } catch (e) {
      print('Error getting following: $e');
      return [];
    }
  }
}
