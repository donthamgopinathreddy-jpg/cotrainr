import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../common/pressable_card.dart';
import '../../repositories/posts_repository.dart';

class FeedPreviewV3 extends StatefulWidget {
  final VoidCallback? onViewAllTap;

  const FeedPreviewV3({super.key, this.onViewAllTap});

  @override
  State<FeedPreviewV3> createState() => _FeedPreviewV3State();
}

class _FeedPreviewPost {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String caption;
  final String? mediaUrl;
  int likeCount;
  int commentCount;
  bool isLiked;
  bool isSaved;

  _FeedPreviewPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.caption,
    this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.isSaved = false,
  });
}

class _FeedPreviewV3State extends State<FeedPreviewV3> {
  final List<_FeedPreviewPost> _posts = [];
  final PostsRepository _postsRepo = PostsRepository();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealPosts();
  }

  Future<void> _loadRealPosts() async {
    setState(() => _isLoading = true);
    try {
      // Fetch recent posts (limit to 6 for preview)
      final posts = await _postsRepo.fetchRecentPosts(limit: 6);
      
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      
      // Get user's liked posts to check if posts are liked
      Set<String> likedPostIds = {};
      if (currentUserId != null) {
        try {
          final likedPosts = await supabase
              .from('post_likes')
              .select('post_id')
              .eq('user_id', currentUserId);
          likedPostIds = (likedPosts as List)
              .map((p) => p['post_id'] as String)
              .toSet();
        } catch (e) {
          print('Error fetching liked posts: $e');
        }
      }
      
      final realPosts = <_FeedPreviewPost>[];
      
      for (final post in posts) {
        final postId = post['id'] as String;
        final author = post['profiles'] as Map<String, dynamic>?;
        final content = post['content'] as String? ?? '';
        final likeCount = (post['likes_count'] as num?)?.toInt() ?? 0;
        final commentCount = (post['comments_count'] as num?)?.toInt() ?? 0;
        
        // Get author info
        final userName = author?['full_name'] as String? ?? 
                        author?['username'] as String? ?? 
                        'User';
        final username = author?['username'] as String? ?? 'user';
        final avatarUrl = author?['avatar_url'] as String?;
        
        // Get post media (first image)
        String? mediaUrl;
        try {
          final media = await _postsRepo.fetchPostMedia(postId);
          if (media.isNotEmpty) {
            mediaUrl = media.first['media_url'] as String?;
          }
        } catch (e) {
          print('Error fetching media for post $postId: $e');
        }
        
        realPosts.add(_FeedPreviewPost(
          id: postId,
          userId: username,
          userName: userName,
          avatarUrl: avatarUrl,
          caption: content,
          mediaUrl: mediaUrl,
          likeCount: likeCount,
          commentCount: commentCount,
          isLiked: likedPostIds.contains(postId),
          isSaved: false, // Saved posts not implemented yet
        ));
      }
      
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(realPosts);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading real posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final wasLiked = post.isLiked;
    
    // Optimistic update
    setState(() {
      if (post.isLiked) {
        post.likeCount--;
        post.isLiked = false;
      } else {
        post.likeCount++;
        post.isLiked = true;
      }
    });
    HapticFeedback.lightImpact();
    
    // Update in database
    try {
      await _postsRepo.toggleLike(post.id);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          post.isLiked = wasLiked;
          if (wasLiked) {
            post.likeCount++;
          } else {
            post.likeCount--;
          }
        });
      }
      print('Error toggling like: $e');
    }
  }

  void _toggleSave(int index) {
    setState(() {
      _posts[index].isSaved = !_posts[index].isSaved;
    });
    HapticFeedback.lightImpact();
  }

  void _onComment(int index) {
    HapticFeedback.lightImpact();
    // Navigate to comments or show comment sheet
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comments for ${_posts[index].userName}\'s post'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Community Feed',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onViewAllTap?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.orange,
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Text(
                        'No posts yet',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount: _posts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return _PostPreviewCard(
                          post: post,
                          onLike: () => _toggleLike(index),
                          onComment: () => _onComment(index),
                          onSave: () => _toggleSave(index),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  final _FeedPreviewPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;

  const _PostPreviewCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const cardWidth = 200.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.orange, AppColors.pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: post.avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: Text(
                                post.userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                post.userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            post.userName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${post.userId}',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Media/Image
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: post.mediaUrl != null && post.mediaUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: post.mediaUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: AppColors.orange.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.orange,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.orange.withOpacity(0.1),
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.orange.withOpacity(0.5),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              post.caption,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Like
                PressableCard(
                  onTap: onLike,
                  borderRadius: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: post.isLiked
                            ? AppColors.orange
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.likeCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: post.isLiked
                              ? AppColors.orange
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Comment
                PressableCard(
                  onTap: onComment,
                  borderRadius: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.commentCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Save
                PressableCard(
                  onTap: onSave,
                  borderRadius: 8,
                  child: Icon(
                    post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 16,
                    color: post.isSaved
                        ? AppColors.orange
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
