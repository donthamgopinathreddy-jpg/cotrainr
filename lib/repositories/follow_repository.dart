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
    if (_currentUserId == null) {
      // If not logged in, return without follow status
      try {
        final response = await _supabase
            .from('user_follows')
            .select('''
              follower_id,
              profiles!user_follows_follower_id_fkey(id, username, full_name, avatar_url)
            ''')
            .eq('following_id', userId)
            .order('created_at', ascending: false);

        return (response as List).cast<Map<String, dynamic>>();
      } catch (e) {
        print('Error getting followers: $e');
        return [];
      }
    }

    try {
      // Get followers
      final response = await _supabase
          .from('user_follows')
          .select('''
            follower_id,
            profiles!user_follows_follower_id_fkey(id, username, full_name, avatar_url)
          ''')
          .eq('following_id', userId)
          .order('created_at', ascending: false);

      final followers = (response as List).cast<Map<String, dynamic>>();
      
      // Get list of user IDs that current user is following
      final followingResponse = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', _currentUserId!);
      
      final followingIds = (followingResponse as List)
          .map((item) => item['following_id'] as String)
          .toSet();

      // Add follow status to each follower
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
    if (_currentUserId == null) {
      // If not logged in, return without follow status
      try {
        final response = await _supabase
            .from('user_follows')
            .select('''
              following_id,
              profiles!user_follows_following_id_fkey(id, username, full_name, avatar_url)
            ''')
            .eq('follower_id', userId)
            .order('created_at', ascending: false);

        return (response as List).cast<Map<String, dynamic>>();
      } catch (e) {
        print('Error getting following: $e');
        return [];
      }
    }

    try {
      // Get following
      final response = await _supabase
          .from('user_follows')
          .select('''
            following_id,
            profiles!user_follows_following_id_fkey(id, username, full_name, avatar_url)
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false);

      final following = (response as List).cast<Map<String, dynamic>>();
      
      // Get list of user IDs that current user is following
      final followingResponse = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', _currentUserId!);
      
      final followingIds = (followingResponse as List)
          .map((item) => item['following_id'] as String)
          .toSet();

      // Add follow status to each user (they're already being followed by profile user)
      // But we need to check if current user follows them
      for (var user in following) {
        final followingId = user['following_id'] as String;
        user['is_following'] = followingIds.contains(followingId);
      }

      return following;
    } catch (e) {
      print('Error getting following: $e');
      return [];
    }
  }
}
