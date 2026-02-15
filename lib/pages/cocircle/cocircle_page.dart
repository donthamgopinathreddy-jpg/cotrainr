import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cocircle/cocircle_feed_card.dart';
import '../../utils/page_transitions.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../models/cocircle_feed_post.dart';
import 'cocircle_create_post_page.dart';
import 'user_profile_page.dart';

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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allUsers = [];
  final ProfileRepository _profileRepo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _profileRepo.searchUsers(_controller.text);
      setState(() {
        _allUsers = users
            .map(
              (u) => <String, dynamic>{
                'userId': u['id'] as String,
                'userName':
                    (u['full_name'] as String?) ??
                    (u['username'] as String? ?? 'User'),
                'username': u['username'] as String?,
                'avatarUrl': u['avatar_url'] as String?,
              },
            )
            .toList();
      });
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  void _onSearchChanged() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      _removeOverlay();
      return;
    }

    // Load users from database
    _loadUsers().then((_) {
      if (!mounted) return;
      setState(() {
        _searchResults = _allUsers.where((user) {
          final userId = (user['userId']?.toString() ?? '').toLowerCase();
          final userName = (user['userName']?.toString() ?? '').toLowerCase();
          final username = (user['username']?.toString() ?? '').toLowerCase();
          final searchTerm = query.toLowerCase();
          return userId.contains(searchTerm) ||
              userName.contains(searchTerm) ||
              username.contains(searchTerm);
        }).toList();
      });

      if (_searchResults.isNotEmpty && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _searchResults.isNotEmpty) {
      _showOverlay();
    } else if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final colorScheme = Theme.of(context).colorScheme;
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surface,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _searchResults.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return InkWell(
                          onTap: () {
                            _controller.text =
                                user['userName']?.toString() ?? '';
                            _focusNode.unfocus();
                            _removeOverlay();
                            // Navigate to user profile
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfilePage(
                                  isOwnProfile: false,
                                  userId: user['userId']?.toString(),
                                  userName: user['userName']?.toString(),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.purple.withValues(alpha: 0.2),
                                  backgroundImage: (user['avatarUrl'] as String?) != null &&
                                          (user['avatarUrl'] as String).isNotEmpty
                                      ? CachedNetworkImageProvider(user['avatarUrl'] as String)
                                      : null,
                                  child: (user['avatarUrl'] as String?) == null ||
                                          (user['avatarUrl'] as String).isEmpty
                                      ? Text(
                                          (user['userName']?.toString() ?? 'U')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.purple,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['userName']?.toString() ?? 'User',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user['username'] != null
                                            ? '@${user['username']}'
                                            : '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
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
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 22,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
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
  final Set<String> _followingUserIds = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final PostsRepository _postsRepo = PostsRepository();
  final FollowRepository _followRepo = FollowRepository();
  bool _isLoading = false;
  String? _currentUserId;

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
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadRealData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadRealData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final posts = await _postsRepo.fetchRecentPosts(limit: 20);
      if (!mounted) return;

      final authorIds = posts.map((p) => p['author_id'] as String).toSet().toList();
      final followingIds = _currentUserId != null && authorIds.isNotEmpty
          ? await _followRepo.getFollowingStatusForUsers(authorIds)
          : <String>{};

      final cocirclePosts = <CocircleFeedPost>[];
      for (final post in posts) {
        final author = post['profiles'] as Map<String, dynamic>?;
        final authorId = post['author_id'] as String;
        final username = author?['username'] as String? ?? 'user';
        final fullName = author?['full_name'] as String? ?? username;
        final authorAvatar = author?['avatar_url'] as String?;
        final authorRole = (author?['role'] as String? ?? 'client').toUpperCase();
        final mediaList = (post['media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final firstMedia = mediaList.isNotEmpty ? mediaList.first : null;
        final mediaKind = firstMedia?['media_kind'] as String?;
        final isVideo = mediaKind == 'video';

        cocirclePosts.add(
          CocircleFeedPost(
            id: post['id'] as String,
            authorId: authorId,
            username: username,
            fullName: fullName,
            userRole: authorRole,
            avatarUrl: authorAvatar,
            timestamp: DateTime.parse(post['created_at'] as String),
            mediaUrl: firstMedia?['media_url'] as String?,
            mediaType: isVideo ? 'video' : 'image',
            caption: post['content'] as String? ?? '',
            likeCount: (post['likes_count'] as int?) ?? 0,
            commentCount: (post['comments_count'] as int?) ?? 0,
            shareCount: 0,
            isLiked: (post['is_liked'] as bool?) ?? false,
            media: mediaList,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(cocirclePosts);
          _followingUserIds.clear();
          _followingUserIds.addAll(followingIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading Cocircle posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadRealData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A2335) // Dark blue-black mix
        : const Color(0xFFE3F2FD); // Very light blue

    return Container(
      color: backgroundColor,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFF8B5CF6), // Purple from gradient
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
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
                          onAddTap: () async {
                            HapticFeedback.selectionClick();
                            final result = await Navigator.push(
                              context,
                              PageTransitions.slideRoute(
                                const CocircleCreatePostPage(),
                                beginOffset: const Offset(0, 0.05),
                              ),
                            );
                            // Reload posts if a new post was created
                            if (result == true) {
                              await _loadRealData();
                            }
                          },
                          onProfileTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              PageTransitions.slideRoute(
                                const UserProfilePage(),
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
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                // Empty state
                if (!_isLoading && _posts.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState()),
                // Posts list - Single tile per row, continuous scrolling
                if (!_isLoading && _posts.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final post = _posts[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _posts.length - 1 ? 12 : 0,
                          ),
                          child: CocircleFeedCard(
                            post: post,
                            onLike: () => _toggleLike(post.id),
                            onComment: () => _openComments(post.id),
                            onShare: () => _sharePost(post.id),
                            onDoubleTap: () => _handleDoubleTap(post.id),
                            onFollow: () => _toggleFollow(post.authorId),
                            onProfileTap: () =>
                                _openProfile(post.authorId, post.userName),
                            isFollowing: _followingUserIds.contains(post.authorId),
                            isOwnPost: post.authorId == _currentUserId,
                          ),
                        );
                      }, childCount: _posts.length),
                    ),
                  ),
                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  Future<void> _toggleLike(String postId) async {
    HapticFeedback.lightImpact();

    // Optimistic update
    setState(() {
      final post = _posts.firstWhere((p) => p.id == postId);
      post.isLiked = !post.isLiked;
      post.likeCount += post.isLiked ? 1 : -1;
    });

    try {
      // Update in database
      final result = await _postsRepo.toggleLike(postId);

      // Update with actual result from database
      if (mounted) {
        setState(() {
          final post = _posts.firstWhere((p) => p.id == postId);
          post.isLiked = result['isLiked'] as bool;
          post.likeCount = result['likeCount'] as int;
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          final post = _posts.firstWhere((p) => p.id == postId);
          post.isLiked = !post.isLiked;
          post.likeCount += post.isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating like: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openComments(String postId) {
    HapticFeedback.lightImpact();
    // Comments are handled in CocircleFeedCard widget
    // This is just a callback for analytics/tracking
  }

  void _sharePost(String postId) async {
    HapticFeedback.lightImpact();
    final post = _posts.firstWhere((p) => p.id == postId);

    try {
      if (post.mediaUrl != null) {
        // Share image with caption
        await Share.shareXFiles(
          [XFile(post.mediaUrl!)],
          text: post.caption.isNotEmpty
              ? '${post.userName}: ${post.caption}'
              : 'Check out this post from ${post.userName} on Cocircle!',
        );
      } else {
        // Share text only
        await Share.share(
          post.caption.isNotEmpty
              ? '${post.userName}: ${post.caption}\n\nShared from Cocircle'
              : 'Check out ${post.userName}\'s post on Cocircle!',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: ${e.toString()}')),
        );
      }
    }
  }

  void _handleDoubleTap(String postId) {
    if (!_posts.firstWhere((p) => p.id == postId).isLiked) {
      _toggleLike(postId);
    }
    HapticFeedback.mediumImpact();
    // TODO: Show heart burst animation
  }

  Future<void> _toggleFollow(String targetUserId) async {
    if (targetUserId == _currentUserId) return;
    HapticFeedback.lightImpact();

    final wasFollowing = _followingUserIds.contains(targetUserId);
    setState(() {
      if (wasFollowing) {
        _followingUserIds.remove(targetUserId);
      } else {
        _followingUserIds.add(targetUserId);
      }
    });

    try {
      final success = wasFollowing
          ? await _followRepo.unfollowUser(targetUserId)
          : await _followRepo.followUser(targetUserId);
      if (!success && mounted) {
        setState(() {
          if (wasFollowing) {
            _followingUserIds.add(targetUserId);
          } else {
            _followingUserIds.remove(targetUserId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${wasFollowing ? 'unfollow' : 'follow'} user')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _followingUserIds.add(targetUserId);
          } else {
            _followingUserIds.remove(targetUserId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _openProfile(String userId, String userName) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageTransitions.slideRoute(
        UserProfilePage(
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
          child: Icon(Icons.people_outline, size: 26, color: Colors.white),
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
            child: Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }
}

