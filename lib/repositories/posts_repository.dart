import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing social posts (Cocircle)
class PostsRepository {
  final SupabaseClient _supabase;

  PostsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetch recent public posts for Cocircle preview
  /// Returns up to 5 most recent posts with likes and comments count
  Future<List<Map<String, dynamic>>> fetchRecentPosts({int limit = 5}) async {
    try {
      // First get posts
      final postsResponse = await _supabase
          .from('posts')
          .select('id, author_id, content, visibility, likes_count, comments_count, created_at')
          .or('visibility.eq.public,visibility.eq.friends')
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (postsResponse as List).cast<Map<String, dynamic>>();
      
      // Then fetch author profiles for each post
      final enrichedPosts = <Map<String, dynamic>>[];
      for (final post in posts) {
        final authorId = post['author_id'] as String;
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select('id, username, avatar_url, full_name')
              .eq('id', authorId)
              .maybeSingle();
          
          enrichedPosts.add({
            ...post,
            'profiles': profileResponse,
          });
        } catch (e) {
          // If profile fetch fails, still include post without author info
          enrichedPosts.add({
            ...post,
            'profiles': null,
          });
        }
      }
      
      return enrichedPosts;
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  /// Fetch post media for a post
  Future<List<Map<String, dynamic>>> fetchPostMedia(String postId) async {
    try {
      final response = await _supabase
          .from('post_media')
          .select()
          .eq('post_id', postId)
          .order('order_index');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching post media: $e');
      return [];
    }
  }
}
