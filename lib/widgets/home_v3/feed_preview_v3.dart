import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../common/pressable_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMockPosts();
  }

  void _loadMockPosts() {
    _posts.addAll([
      _FeedPreviewPost(
        id: '1',
        userId: 'fitness_john',
        userName: 'John Doe',
        caption: 'Just completed my first 10K run! 🏃‍♂️',
        likeCount: 24,
        commentCount: 5,
        isLiked: false,
        isSaved: false,
      ),
      _FeedPreviewPost(
        id: '2',
        userId: 'trainer_sarah',
        userName: 'Sarah Johnson',
        caption: 'New workout routine for my clients! 💪',
        likeCount: 56,
        commentCount: 12,
        isLiked: true,
        isSaved: true,
      ),
      _FeedPreviewPost(
        id: '3',
        userId: 'nutritionist_mike',
        userName: 'Dr. Mike Chen',
        caption: 'Meal prep Sunday! Healthy and delicious 🥗',
        likeCount: 89,
        commentCount: 15,
        isLiked: false,
        isSaved: false,
      ),
      _FeedPreviewPost(
        id: '4',
        userId: 'fitness_anna',
        userName: 'Anna Martinez',
        caption: 'Morning yoga session complete! 🧘‍♀️',
        likeCount: 42,
        commentCount: 8,
        isLiked: true,
        isSaved: false,
      ),
      _FeedPreviewPost(
        id: '5',
        userId: 'trainer_alex',
        userName: 'Alex Thompson',
        caption: 'Strength training tips for beginners 💪',
        likeCount: 67,
        commentCount: 11,
        isLiked: false,
        isSaved: true,
      ),
      _FeedPreviewPost(
        id: '6',
        userId: 'nutritionist_lisa',
        userName: 'Lisa Park',
        caption: 'Healthy breakfast ideas to start your day right! 🍳',
        likeCount: 93,
        commentCount: 18,
        isLiked: true,
        isSaved: true,
      ),
    ]);
  }

  void _toggleLike(int index) {
    setState(() {
      final post = _posts[index];
      if (post.isLiked) {
        post.likeCount--;
        post.isLiked = false;
      } else {
        post.likeCount++;
        post.isLiked = true;
      }
    });
    HapticFeedback.lightImpact();
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
          child: ListView.separated(
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
                  child: post.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            post.avatarUrl!,
                            fit: BoxFit.cover,
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
              child: post.mediaUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        post.mediaUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
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
