import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/posts_repository.dart';
import '../../utils/page_transitions.dart';
import '../../pages/cocircle/user_profile_page.dart';

class FeedPreviewV3 extends StatefulWidget {
  final VoidCallback? onViewAllTap;

  const FeedPreviewV3({super.key, this.onViewAllTap});

  @override
  State<FeedPreviewV3> createState() => _FeedPreviewV3State();
}

class _FeedPreviewPost {
  final String id;
  final String authorId;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String caption;
  final String? mediaUrl;
  int likeCount;
  int commentCount;
  bool isLiked;

  _FeedPreviewPost({
    required this.id,
    required this.authorId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.caption,
    this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
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
      // Fetch more posts so each tile can cycle through on swipe
      final posts = await _postsRepo.fetchRecentPosts(limit: 25);
      
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
        final authorId = post['author_id'] as String? ?? author?['id'] as String? ?? '';
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
          authorId: authorId,
          userId: username,
          userName: userName,
          avatarUrl: avatarUrl,
          caption: content,
          mediaUrl: mediaUrl,
          likeCount: likeCount,
          commentCount: commentCount,
          isLiked: likedPostIds.contains(postId),
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

  void _openProfile(String authorId, String userName) {
    if (authorId.isEmpty) return;
    HapticFeedback.lightImpact();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    Navigator.push(
      context,
      PageTransitions.slideRoute(
        UserProfilePage(
          userId: authorId,
          userName: userName,
          isOwnProfile: authorId == currentUserId,
        ),
        beginOffset: const Offset(0, 0.05),
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
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                Icons.people_outline,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.blue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Community Feed',
              style: GoogleFonts.montserrat(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onViewAllTap?.call();
              },
              child: Text(
                'View all →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.purple,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 420,
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.purple,
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
                  : _AsymmetricFeedGrid(
                      posts: _posts,
                      onProfileTap: _openProfile,
                      onPostTap: () => widget.onViewAllTap?.call(),
                    ),
        ),
      ],
    );
  }
}

/// Asymmetric grid per sketch: left 2 boxes (top large, bottom square), right 3 boxes (top small, middle, bottom large)
/// Each tile cycles through posts on swipe: tile 0->[0,5,10..], tile 1->[1,6,11..], etc.
class _AsymmetricFeedGrid extends StatefulWidget {
  final List<_FeedPreviewPost> posts;
  final void Function(String authorId, String userName) onProfileTap;
  final VoidCallback onPostTap;

  const _AsymmetricFeedGrid({
    required this.posts,
    required this.onProfileTap,
    required this.onPostTap,
  });

  @override
  State<_AsymmetricFeedGrid> createState() => _AsymmetricFeedGridState();
}

class _AsymmetricFeedGridState extends State<_AsymmetricFeedGrid> {
  /// Per-tile index in sequence: tile i shows post at index i + _tileIndices[i] * 5
  final List<int> _tileIndices = [0, 0, 0, 0, 0];
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.posts.length < 5) return;
      setState(() {
        for (var i = 0; i < 5; i++) {
          final nextIdx = _tileIndices[i] + 1;
          final postIdx = i + nextIdx * 5;
          _tileIndices[i] = postIdx < widget.posts.length ? nextIdx : 0;
        }
      });
    });
  }

  _FeedPreviewPost? _postForTile(int tileIndex) {
    final idx = tileIndex + _tileIndices[tileIndex] * 5;
    if (idx >= widget.posts.length) return null;
    return widget.posts[idx];
  }

  void _onSwipeNext(int tileIndex) {
    setState(() {
      final nextIdx = _tileIndices[tileIndex] + 1;
      final postIdx = tileIndex + nextIdx * 5;
      _tileIndices[tileIndex] = postIdx < widget.posts.length ? nextIdx : 0;
    });
    HapticFeedback.selectionClick();
  }

  void _onSwipePrev(int tileIndex) {
    setState(() {
      final prevIdx = _tileIndices[tileIndex] - 1;
      _tileIndices[tileIndex] = prevIdx >= 0 ? prevIdx : 0;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    final post0 = _postForTile(0);
    final post1 = _postForTile(1);
    final post2 = _postForTile(2);
    final post3 = _postForTile(3);
    final post4 = _postForTile(4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: post0 != null ? _buildTile(post0, _CardSize.large, 0) : _emptyTile()),
              SizedBox(height: gap),
              Expanded(flex: 1, child: post3 != null ? _buildTile(post3, _CardSize.square, 3) : _emptyTile()),
            ],
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: post1 != null ? _buildTile(post1, _CardSize.small, 1) : _emptyTile()),
              SizedBox(height: gap),
              Expanded(flex: 2, child: post2 != null ? _buildTile(post2, _CardSize.medium, 2) : _emptyTile()),
              SizedBox(height: gap),
              Expanded(flex: 1, child: post4 != null ? _buildTile(post4, _CardSize.large, 4) : _emptyTile()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(_FeedPreviewPost post, _CardSize size, int tileIndex) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey('${post.id}_${_tileIndices[tileIndex]}'),
        child: _PostPreviewCard(
          post: post,
          size: size,
          onProfileTap: () => widget.onProfileTap(post.authorId, post.userName),
          onPostTap: widget.onPostTap,
          onSwipeNext: () => _onSwipeNext(tileIndex),
          onSwipePrev: () => _onSwipePrev(tileIndex),
        ),
      ),
    );
  }

  Widget _emptyTile() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(color: Colors.transparent),
    );
  }
}

enum _CardSize { large, medium, small, square }

class _PostPreviewCard extends StatelessWidget {
  final _FeedPreviewPost post;
  final _CardSize size;
  final VoidCallback onProfileTap;
  final VoidCallback onPostTap;
  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrev;

  const _PostPreviewCard({
    required this.post,
    required this.size,
    required this.onProfileTap,
    required this.onPostTap,
    this.onSwipeNext,
    this.onSwipePrev,
  });

  double get _radius {
    switch (size) {
      case _CardSize.small: return 10;
      case _CardSize.square: return 12;
      case _CardSize.medium: return 12;
      case _CardSize.large: return 14;
    }
  }

  static const _swipeVelocityThreshold = 200.0;

  @override
  Widget build(BuildContext context) {
    final isSmall = size == _CardSize.small;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPostTap();
      },
      onHorizontalDragEnd: (onSwipeNext != null || onSwipePrev != null)
          ? (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() > _swipeVelocityThreshold) {
                if (v < 0) {
                  onSwipeNext?.call();
                } else {
                  onSwipePrev?.call();
                }
              }
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media only - no background base
            post.mediaUrl != null && post.mediaUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: post.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _mediaPlaceholder(),
                    errorWidget: (context, url, error) => _mediaPlaceholder(),
                  )
                : _mediaPlaceholder(),
            // Bottom gradient for profile overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: isSmall ? 32 : 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
            // Profile inside post - tappable to open profile (stops propagation)
            Positioned(
              left: isSmall ? 6 : 10,
              right: isSmall ? 6 : 10,
              bottom: isSmall ? 6 : 8,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onProfileTap();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: isSmall ? 18 : 26,
                      height: isSmall ? 18 : 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: post.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _avatarPlaceholder(post),
                                errorWidget: (context, url, error) => _avatarPlaceholder(post),
                              ),
                            )
                          : _avatarPlaceholder(post),
                    ),
                    SizedBox(width: isSmall ? 4 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            post.userName,
                            style: TextStyle(
                              fontSize: isSmall ? 9 : 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isSmall)
                            Text(
                              '@${post.userId}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.9),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(_FeedPreviewPost post) {
    return Container(
      color: AppColors.purple,
      child: Center(
        child: Text(
          post.userName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _mediaPlaceholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 28,
        color: AppColors.purple.withValues(alpha: 0.2),
      ),
    );
  }
}

class _CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String caption;
  final String userName;
  final VoidCallback onCommentAdded;

  const _CommentsBottomSheet({
    required this.postId,
    required this.caption,
    required this.userName,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final PostsRepository _postsRepo = PostsRepository();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _postsRepo.fetchComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments.clear();
          for (final c in comments) {
            final profile = c['profiles'] as Map<String, dynamic>?;
            _comments.add({
              'id': c['id'],
              'userId': c['author_id'],
              'userName': profile?['full_name'] as String? ?? profile?['username'] as String? ?? 'User',
              'avatarUrl': profile?['avatar_url'] as String?,
              'text': c['content'] as String,
              'timestamp': DateTime.parse(c['created_at'] as String),
            });
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    _controller.clear();

    final currentUser = Supabase.instance.client.auth.currentUser;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _comments.insert(0, {
        'id': tempId,
        'userId': currentUser?.id ?? '',
        'userName': currentUser?.userMetadata?['full_name'] as String? ?? 'You',
        'avatarUrl': currentUser?.userMetadata?['avatar_url'] as String?,
        'text': text,
        'timestamp': DateTime.now(),
      });
    });

    try {
      await _postsRepo.createComment(widget.postId, text);
      widget.onCommentAdded();
    } catch (e) {
      if (mounted) {
        setState(() => _comments.removeWhere((c) => c['id'] == tempId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: AppColors.purple, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet. Be the first!',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            itemBuilder: (context, i) {
                              final c = _comments[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.purple.withValues(alpha: 0.3),
                                      backgroundImage: (c['avatarUrl'] as String?) != null &&
                                              (c['avatarUrl'] as String).isNotEmpty
                                          ? CachedNetworkImageProvider(c['avatarUrl'] as String)
                                          : null,
                                      child: c['avatarUrl'] == null
                                          ? Text(
                                              (c['userName'] as String).substring(0, 1).toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['userName'] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c['text'] as String,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: cs.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.blue, AppColors.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _isSubmitting ? null : _submitComment,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
