import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing social posts (Cocircle)
class PostsRepository {
  final SupabaseClient _supabase;

  PostsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Fetch recent posts for Cocircle feed (Instagram-style)
  /// Returns: own posts + posts from followed users + public posts
  /// Uses keyset pagination with cursor params: last_created_at, last_id
  Future<List<Map<String, dynamic>>> fetchRecentPosts({
    int limit = 20,
    String? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Error: User not authenticated');
        return [];
      }

      print('Fetching feed posts for user: $userId');

      // Build query WITHOUT join first to test if RLS works
      // If this returns posts, then the join is the issue
      // We'll fetch profiles separately if needed
      dynamic queryBuilder = _supabase.from('posts').select('''
            id,
            author_id,
            content,
            visibility,
            likes_count,
            comments_count,
            created_at
          ''');

      // Keyset pagination: order by created_at desc, then id desc for tie-breaking
      // Apply cursor for pagination if provided
      if (lastCreatedAt != null) {
        queryBuilder = queryBuilder
            .lt('created_at', lastCreatedAt)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(limit);
      } else {
        queryBuilder = queryBuilder
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(limit);
      }

      // Execute query
      print('Executing feed query for user: $userId');
      final postsResponse = await queryBuilder;
      print(
        'Query executed successfully, response type: ${postsResponse.runtimeType}',
      );

      final posts = (postsResponse as List).cast<Map<String, dynamic>>();
      print('Raw posts count: ${posts.length}');

      // Fetch profiles separately for all unique author_ids
      final authorIds = posts
          .map((p) => p['author_id'] as String)
          .toSet()
          .toList();

      final profilesMap = <String, Map<String, dynamic>>{};
      if (authorIds.isNotEmpty) {
        try {
          // Fetch profiles for all authors
          // Build OR query: id = 'id1' OR id = 'id2' ...
          var profilesQuery = _supabase
              .from('profiles')
              .select('id, username, avatar_url, full_name, role');

          // Use OR filter for multiple IDs
          if (authorIds.length == 1) {
            profilesQuery = profilesQuery.eq('id', authorIds[0]);
          } else {
            final orConditions = authorIds.map((id) => 'id.eq.$id').join(',');
            profilesQuery = profilesQuery.or(orConditions);
          }

          final profilesResponse = await profilesQuery;

          final profiles = (profilesResponse as List)
              .cast<Map<String, dynamic>>();
          for (final profile in profiles) {
            profilesMap[profile['id'] as String] = profile;
          }
          print(
            'Fetched ${profilesMap.length} profiles for ${authorIds.length} authors',
          );
        } catch (e) {
          print('Error fetching profiles: $e');
        }
      }

      // Enrich posts with profile data
      final enrichedPosts = <Map<String, dynamic>>[];
      for (final post in posts) {
        final authorId = post['author_id'] as String;
        final profileData = profilesMap[authorId];

        enrichedPosts.add({...post, 'profiles': profileData});
      }

      print(
        'Fetched ${enrichedPosts.length} posts from database (feed: own + followed + public)',
      );
      if (enrichedPosts.isEmpty) {
        print('WARNING: No posts returned. Check:');
        print('  1. RLS policy "Users can view feed posts" exists');
        print(
          '  2. Posts exist in database with visibility="public" or author_id=$userId',
        );
        print('  3. User is authenticated: true');
      }
      return enrichedPosts;
    } catch (e, stackTrace) {
      print('Error fetching posts: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch posts by a specific user (for profile page)
  /// Uses keyset pagination with cursor params: last_created_at, last_id
  Future<List<Map<String, dynamic>>> fetchUserPosts(
    String userId, {
    int limit = 50,
    String? lastCreatedAt,
    String? lastId,
  }) async {
    try {
      print('Fetching posts for user: $userId');

      // Build query WITHOUT join first to test if RLS works
      dynamic queryBuilder = _supabase
          .from('posts')
          .select('''
            id,
            author_id,
            content,
            visibility,
            likes_count,
            comments_count,
            created_at
          ''')
          .eq('author_id', userId);

      // Keyset pagination: order by created_at desc, then id desc
      // Apply cursor for pagination if provided
      if (lastCreatedAt != null) {
        queryBuilder = queryBuilder
            .lt('created_at', lastCreatedAt)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(limit);
      } else {
        queryBuilder = queryBuilder
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(limit);
      }

      // Execute query
      final postsResponse = await queryBuilder;
      print(
        'User posts query executed, response type: ${postsResponse.runtimeType}',
      );

      final posts = (postsResponse as List).cast<Map<String, dynamic>>();
      print('Raw user posts count: ${posts.length}');

      // Fetch profile for this user
      Map<String, dynamic>? profileData;
      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, username, avatar_url, full_name, role')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          profileData = profileResponse;
          print('Fetched profile for user: ${profileData['username']}');
        }
      } catch (e) {
        print('Error fetching profile: $e');
      }

      // Fetch post media for all posts
      final enrichedPosts = <Map<String, dynamic>>[];
      for (final post in posts) {
        final postId = post['id'] as String;

        // Fetch media for this post
        List<Map<String, dynamic>> postMedia = [];
        try {
          final mediaResponse = await _supabase
              .from('post_media')
              .select('id, media_url, media_kind, order_index')
              .eq('post_id', postId)
              .order('order_index');

          postMedia = (mediaResponse as List).cast<Map<String, dynamic>>();
        } catch (e) {
          print('Error fetching media for post $postId: $e');
        }

        enrichedPosts.add({
          ...post,
          'profiles': profileData,
          'post_media': postMedia,
        });
      }

      print('Fetched ${enrichedPosts.length} posts for user profile');
      return enrichedPosts;
    } catch (e, stackTrace) {
      print('Error fetching user posts: $e');
      print('Stack trace: $stackTrace');
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

  /// Toggle like on a post (like if not liked, unlike if liked)
  /// Returns the new like count and whether the post is now liked
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if already liked
      final existingLike = await _supabase
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike: delete the like
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Decrement like count - get current count first
        final currentPost = await _supabase
            .from('posts')
            .select('likes_count')
            .eq('id', postId)
            .single();

        final currentCount = (currentPost['likes_count'] as int?) ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await _supabase
            .from('posts')
            .update({'likes_count': newCount})
            .eq('id', postId);

        return {'isLiked': false, 'likeCount': newCount};
      } else {
        // Like: insert the like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });

        // Increment like count - get current count first
        final currentPost = await _supabase
            .from('posts')
            .select('likes_count')
            .eq('id', postId)
            .single();

        final currentCount = (currentPost['likes_count'] as int?) ?? 0;
        final newCount = currentCount + 1;

        await _supabase
            .from('posts')
            .update({'likes_count': newCount})
            .eq('id', postId);

        return {'isLiked': true, 'likeCount': newCount};
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  /// Fetch comments for a post
  Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
    try {
      // Fetch comments without join first
      final commentsResponse = await _supabase
          .from('post_comments')
          .select('''
            id,
            post_id,
            author_id,
            content,
            created_at
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      final comments = (commentsResponse as List).cast<Map<String, dynamic>>();

      // Fetch profiles for all unique author_ids
      final authorIds = comments
          .map((c) => c['author_id'] as String)
          .toSet()
          .toList();

      final profilesMap = <String, Map<String, dynamic>>{};
      if (authorIds.isNotEmpty) {
        try {
          var profilesQuery = _supabase
              .from('profiles')
              .select('id, username, avatar_url, full_name');

          if (authorIds.length == 1) {
            profilesQuery = profilesQuery.eq('id', authorIds[0]);
          } else {
            final orConditions = authorIds.map((id) => 'id.eq.$id').join(',');
            profilesQuery = profilesQuery.or(orConditions);
          }

          final profilesResponse = await profilesQuery;
          final profiles = (profilesResponse as List)
              .cast<Map<String, dynamic>>();
          for (final profile in profiles) {
            profilesMap[profile['id'] as String] = profile;
          }
        } catch (e) {
          print('Error fetching comment profiles: $e');
        }
      }

      // Enrich comments with profile data
      final enrichedComments = <Map<String, dynamic>>[];
      for (final comment in comments) {
        final authorId = comment['author_id'] as String;
        final profileData = profilesMap[authorId];

        enrichedComments.add({...comment, 'profiles': profileData});
      }

      return enrichedComments;
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  /// Create a comment on a post
  /// Returns the created comment with profile data
  Future<Map<String, dynamic>> createComment(
    String postId,
    String content,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Insert comment
      final commentResponse = await _supabase
          .from('post_comments')
          .insert({'post_id': postId, 'author_id': userId, 'content': content})
          .select('''
            id,
            post_id,
            author_id,
            content,
            created_at
          ''')
          .single();

      // Increment comment count - get current count first
      final currentPost = await _supabase
          .from('posts')
          .select('comments_count')
          .eq('id', postId)
          .single();

      final currentCount = (currentPost['comments_count'] as int?) ?? 0;
      final newCount = currentCount + 1;

      await _supabase
          .from('posts')
          .update({'comments_count': newCount})
          .eq('id', postId);

      // Fetch profile for the comment author
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, full_name')
          .eq('id', userId)
          .maybeSingle();

      return {...commentResponse, 'profiles': profileResponse};
    } catch (e) {
      print('Error creating comment: $e');
      rethrow;
    }
  }

  /// Delete a post (only by the author)
  /// Also deletes associated media files from storage and database records (via CASCADE)
  Future<void> deletePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify the post belongs to the current user
      final post = await _supabase
          .from('posts')
          .select('author_id')
          .eq('id', postId)
          .single();

      if (post['author_id'] != userId) {
        throw Exception('You can only delete your own posts');
      }

      // Fetch media files before deleting the post (for storage cleanup)
      final mediaRecords = await _supabase
          .from('post_media')
          .select('media_url')
          .eq('post_id', postId);

      // Delete media files from storage
      if (mediaRecords.isNotEmpty) {
        for (final media in mediaRecords) {
          final mediaUrl = media['media_url'] as String?;
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            try {
              // Extract file path from URL
              final uri = Uri.parse(mediaUrl);
              final pathSegments = uri.pathSegments;
              if (pathSegments.length >= 3) {
                // Format: /storage/v1/object/public/bucket/path
                final bucket = pathSegments[2];
                final filePath = pathSegments.sublist(3).join('/');

                await _supabase.storage.from(bucket).remove([filePath]);
                print('Deleted media file: $filePath');
              }
            } catch (e) {
              print('Error deleting media file from storage: $e');
              // Continue with post deletion even if storage deletion fails
            }
          }
        }
      }

      // Delete the post (CASCADE will handle post_media, post_likes, post_comments database records)
      await _supabase.from('posts').delete().eq('id', postId);

      print('Post $postId deleted successfully');
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }
}
