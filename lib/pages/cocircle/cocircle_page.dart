import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/cocircle/cocircle_feed_card.dart';
import '../../widgets/cocircle/cocircle_create_fab.dart';

class CocirclePage extends StatefulWidget {
  const CocirclePage({super.key});

  @override
  State<CocirclePage> createState() => _CocirclePageState();
}

class _CocirclePageState extends State<CocirclePage> {
  final ScrollController _scrollController = ScrollController();
  final List<CocircleFeedPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    _posts.addAll([
      CocircleFeedPost(
        id: '1',
        userId: 'fitness_john',
        userName: 'John Doe',
        userRole: 'CLIENT',
        avatarUrl: null,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        mediaUrl: null,
        mediaType: 'image',
        caption: 'Just completed my first 10K run! 🏃‍♂️ Feeling amazing!',
        likeCount: 24,
        commentCount: 5,
        shareCount: 2,
        isLiked: false,
      ),
      CocircleFeedPost(
        id: '2',
        userId: 'trainer_sarah',
        userName: 'Sarah Johnson',
        userRole: 'TRAINER',
        avatarUrl: null,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        mediaUrl: null,
        mediaType: 'image',
        caption: 'New workout routine for my clients! Try this 20-minute HIIT session 💪',
        likeCount: 56,
        commentCount: 12,
        shareCount: 8,
        isLiked: true,
      ),
      CocircleFeedPost(
        id: '3',
        userId: 'nutritionist_mike',
        userName: 'Dr. Mike Chen',
        userRole: 'NUTRITIONIST',
        avatarUrl: null,
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        mediaType: 'image',
        caption: 'Meal prep Sunday! Healthy and delicious 🥗',
        likeCount: 89,
        commentCount: 15,
        shareCount: 12,
        isLiked: false,
      ),
    ]);
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    // TODO: Refresh feed
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.background,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: DesignTokens.accentOrange,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 80,
                  floating: false,
                  pinned: true,
                  backgroundColor: DesignTokens.surface,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                    title: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [DesignTokens.accentBlue, DesignTokens.accentBlueLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'CIRCLE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Feed
                if (_posts.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = _posts[index];
                        return CocircleFeedCard(
                          post: post,
                          onLike: () => _toggleLike(post.id),
                          onComment: () => _openComments(post.id),
                          onShare: () => _sharePost(post.id),
                          onDoubleTap: () => _handleDoubleTap(post.id),
                        );
                      },
                      childCount: _posts.length,
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),

          // Create Post FAB
          Positioned(
            bottom: 24,
            right: 24,
            child: CocircleCreateFAB(
              onTap: () {
                HapticFeedback.mediumImpact();
                // TODO: Navigate to create post page
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(DesignTokens.spacing32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: DesignTokens.textSecondary,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeH2,
              fontWeight: FontWeight.w600,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            'Be the first to share your fitness journey!',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeBody,
              color: DesignTokens.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _toggleLike(String postId) {
    setState(() {
      final post = _posts.firstWhere((p) => p.id == postId);
      post.isLiked = !post.isLiked;
      post.likeCount += post.isLiked ? 1 : -1;
    });
    HapticFeedback.lightImpact();
  }

  void _openComments(String postId) {
    HapticFeedback.lightImpact();
    // TODO: Open comments bottom sheet
  }

  void _sharePost(String postId) {
    HapticFeedback.lightImpact();
    // TODO: Implement share
  }

  void _handleDoubleTap(String postId) {
    if (!_posts.firstWhere((p) => p.id == postId).isLiked) {
      _toggleLike(postId);
    }
    HapticFeedback.mediumImpact();
    // TODO: Show heart burst animation
  }
}

// Model
class CocircleFeedPost {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String? avatarUrl;
  final DateTime timestamp;
  final String? mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String caption;
  int likeCount;
  final int commentCount;
  final int shareCount;
  bool isLiked;

  CocircleFeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.avatarUrl,
    required this.timestamp,
    this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.isLiked = false,
  });
}

