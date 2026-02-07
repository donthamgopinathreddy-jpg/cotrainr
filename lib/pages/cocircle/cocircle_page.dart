import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/cocircle/cocircle_feed_card.dart';
import '../../utils/page_transitions.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/profile_repository.dart';
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
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                    size: 20,
                                  ),
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
  final Set<String> _followingUserIds = {}; // Track who we follow
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final PostsRepository _postsRepo = PostsRepository();
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
      print('Loaded ${posts.length} posts from repository');
      if (!mounted) return;

      final cocirclePosts = <CocircleFeedPost>[];

      for (final post in posts) {
        // Get post media
        final media = await _postsRepo.fetchPostMedia(post['id'] as String);
        final firstMedia = media.isNotEmpty ? media.first : null;

        // Get author info
        final author = post['profiles'] as Map<String, dynamic>?;
        final authorId = post['author_id'] as String;
        final authorUsername = author?['username'] as String? ?? 'user';
        final authorFullName =
            author?['full_name'] as String? ?? authorUsername;
        final authorAvatar = author?['avatar_url'] as String?;
        final authorRole = author?['role'] as String? ?? 'client';

        // Get like status (check if current user liked this post)
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        bool isLiked = false;
        if (userId != null) {
          try {
            final likeResponse = await supabase
                .from('post_likes')
                .select('id')
                .eq('post_id', post['id'])
                .eq('user_id', userId)
                .maybeSingle();
            isLiked = likeResponse != null;
          } catch (e) {
            // Ignore errors
          }
        }

        final mediaKind = firstMedia?['media_kind'] as String?;
        final isVideo = mediaKind == 'video';

        cocirclePosts.add(
          CocircleFeedPost(
            id: post['id'] as String,
            userId: authorId,
            userName: authorFullName,
            userRole: authorRole.toUpperCase(),
            avatarUrl: authorAvatar,
            timestamp: DateTime.parse(post['created_at'] as String),
            mediaUrl: firstMedia?['media_url'] as String?,
            mediaType: isVideo ? 'video' : 'image',
            caption: post['content'] as String? ?? '',
            likeCount: (post['likes_count'] as int?) ?? 0,
            commentCount: (post['comments_count'] as int?) ?? 0,
            shareCount: 0, // Not tracked in current schema
            isLiked: isLiked,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(cocirclePosts);
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
                            onFollow: () => _toggleFollow(post.userId),
                            onProfileTap: () =>
                                _openProfile(post.userId, post.userName),
                            isFollowing: _followingUserIds.contains(
                              post.userId,
                            ),
                            isOwnPost: post.userId == _currentUserId,
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
