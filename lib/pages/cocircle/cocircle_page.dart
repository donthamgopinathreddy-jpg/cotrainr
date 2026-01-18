import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cocircle/cocircle_feed_card.dart';
import '../../utils/page_transitions.dart';
import 'cocircle_create_post_page.dart';
import 'cocircle_profile_page.dart';

class CocirclePage extends StatefulWidget {
  const CocirclePage({super.key});

  @override
  State<CocirclePage> createState() => _CocirclePageState();
}

class _CocircleSearchBar extends StatefulWidget {
  final String hintText;

  const _CocircleSearchBar({required this.hintText});

  @override
  State<_CocircleSearchBar> createState() => _CocircleSearchBarState();
}

class _CocircleSearchBarState extends State<_CocircleSearchBar> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        ),
      ),
    );
  }
}

class _CocirclePageState extends State<CocirclePage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final List<CocircleFeedPost> _posts = [];
  final Set<String> _followingUserIds = {}; // Track who we follow
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  static const _currentUserId = 'fitness_john'; // Current user, hide Follow on own posts

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadMockData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.background,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.orange,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: DesignTokens.spacing16,
                    right: DesignTokens.spacing16,
                    top: DesignTokens.spacing12,
                  ),
                  child: Column(
                    children: [
                      _CocircleHeaderRow(
                      onAddTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        PageTransitions.slideRoute(
                          const CocircleCreatePostPage(),
                          beginOffset: const Offset(0, 0.05),
                        ),
                      );
                      },
                      onProfileTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          PageTransitions.slideRoute(
                            const CocircleProfilePage(),
                            beginOffset: const Offset(0, 0.05),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: DesignTokens.spacing16),
                    const _CocircleSearchBar(
                      hintText: 'Search by User ID or name...',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (_posts.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
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
                      onFollow: () => _toggleFollow(post.userId),
                      onProfileTap: () => _openProfile(post.userId, post.userName),
                      isFollowing: _followingUserIds.contains(post.userId),
                      isOwnPost: post.userId == _currentUserId,
                    );
                  },
                  childCount: _posts.length,
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
        ),
        ),
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

  void _toggleFollow(String userId) {
    setState(() {
      if (_followingUserIds.contains(userId)) {
        _followingUserIds.remove(userId);
      } else {
        _followingUserIds.add(userId);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _openProfile(String userId, String userName) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageTransitions.slideRoute(
        CocircleProfilePage(
          userId: userId,
          userName: userName,
          isOwnProfile: userId == _currentUserId,
        ),
        beginOffset: const Offset(0, 0.05),
      ),
    );
  }
}

class _CocircleHeaderRow extends StatelessWidget {
  final VoidCallback onAddTap;
  final VoidCallback onProfileTap;

  const _CocircleHeaderRow({
    required this.onAddTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final cocircleGradient = const LinearGradient(
      colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Row(
      children: [
        ShaderMask(
          shaderCallback: (rect) => cocircleGradient.createShader(rect),
          child: Icon(
            Icons.people_outline,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (rect) => cocircleGradient.createShader(rect),
          child: Text(
            'COCIRCLE',
            style: GoogleFonts.montserrat(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onProfileTap,
          icon: ShaderMask(
            shaderCallback: (rect) => cocircleGradient.createShader(rect),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
        IconButton(
          onPressed: onAddTap,
          icon: ShaderMask(
            shaderCallback: (rect) => cocircleGradient.createShader(rect),
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ],
    );
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

