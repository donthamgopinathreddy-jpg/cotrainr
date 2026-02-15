import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../common/pressable_card.dart';
import '../common/follow_button.dart';
import '../../repositories/posts_repository.dart';

class CocircleFeedCard extends StatefulWidget {
  final dynamic post; // CocircleFeedPost
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onFollow;
  final VoidCallback? onProfileTap;
  final bool isFollowing;
  final bool isOwnPost;

  const CocircleFeedCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDoubleTap,
    this.onFollow,
    this.onProfileTap,
    this.isFollowing = false,
    this.isOwnPost = false,
  });

  @override
  State<CocircleFeedCard> createState() => _CocircleFeedCardState();
}

class _CocircleFeedCardState extends State<CocircleFeedCard>
    with TickerProviderStateMixin {
  late AnimationController _heartController;
  late AnimationController _commentController;
  late FocusNode _commentFocusNode;
  bool _showHeart = false;
  bool _showComments = false;
  bool _isCommentFocused = false;
  bool _isLoadingComments = false;
  final TextEditingController _commentTextController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  final PostsRepository _postsRepo = PostsRepository();

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _commentController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _commentFocusNode = FocusNode();
    _commentFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isCommentFocused = _commentFocusNode.hasFocus;
        });
      }
    });
    // Load sample comments (replace with actual API call)
    _loadComments();
  }

  static const _cocircleGradient = LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void dispose() {
    _heartController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentTextController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (_isLoadingComments) return;
    
    setState(() => _isLoadingComments = true);
    
    try {
      final comments = await _postsRepo.fetchComments(widget.post.id);
      
      if (mounted) {
        setState(() {
          _comments.clear();
          // Transform comments to match expected format
          for (final comment in comments) {
            final profile = comment['profiles'] as Map<String, dynamic>?;
            _comments.add({
              'id': comment['id'] as String,
              'userId': comment['author_id'] as String,
              'userName': profile?['full_name'] as String? ?? 
                          profile?['username'] as String? ?? 
                          'User',
              'avatarUrl': profile?['avatar_url'] as String?,
              'text': comment['content'] as String,
              'timestamp': DateTime.parse(comment['created_at'] as String),
            });
          }
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
      if (_showComments) {
        _commentController.forward();
        widget.onComment?.call();
        // Load comments when opening
        if (_comments.isEmpty) {
          _loadComments();
        }
      } else {
        _commentController.reverse();
      }
    });
  }

  Future<void> _submitComment() async {
    final text = _commentTextController.text.trim();
    if (text.isEmpty) return;

    // Optimistic update
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id ?? 'current_user';
    
    setState(() {
      _comments.insert(0, {
        'id': tempId,
        'userId': currentUserId,
        'userName': 'You',
        'avatarUrl': null,
        'text': text,
        'timestamp': DateTime.now(),
      });
      widget.post.commentCount += 1;
      _commentTextController.clear();
    });

    try {
      // Submit to database
      final comment = await _postsRepo.createComment(widget.post.id, text);
      
      // Update with real comment data
      if (mounted) {
        final profile = comment['profiles'] as Map<String, dynamic>?;
        setState(() {
          // Remove temp comment
          _comments.removeWhere((c) => c['id'] == tempId);
          // Add real comment
          _comments.insert(0, {
            'id': comment['id'] as String,
            'userId': comment['author_id'] as String,
            'userName': profile?['full_name'] as String? ?? 
                        profile?['username'] as String? ?? 
                        'User',
            'avatarUrl': profile?['avatar_url'] as String?,
            'text': comment['content'] as String,
            'timestamp': DateTime.parse(comment['created_at'] as String),
          });
          // Update comment count (already incremented in DB)
        });
      }
    } catch (e) {
      print('Error submitting comment: $e');
      // Revert optimistic update
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == tempId);
          widget.post.commentCount -= 1;
          _commentTextController.text = text; // Restore text
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error posting comment: ${e.toString()}'),
              duration: const Duration(seconds: 2),
            ),
          );
        });
      }
    }
  }

  void _showHeartAnimation() {
    setState(() => _showHeart = true);
    _heartController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _showHeart = false);
          _heartController.reset();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMedia = widget.post.mediaUrl != null;

    // Tile design - compact card
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. HEADER - Name on top
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: widget.onProfileTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _cocircleGradient,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surface,
                        image: widget.post.avatarUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(widget.post.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: widget.post.avatarUrl == null
                          ? Icon(
                              Icons.person,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // User name
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDisplayName(widget.post),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (!widget.isOwnPost)
                          Text(
                            _getHandle(widget.post),
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ),
                // Follow button (only if not own post)
                if (!widget.isOwnPost)
                  FollowButton(
                    isFollowing: widget.isFollowing,
                    onTap: widget.onFollow,
                  ),
              ],
            ),
          ),

          // 2. MEDIA - Picture in the middle
          if (hasMedia)
            ClipRRect(
              borderRadius: BorderRadius.circular(0), // No border radius for middle section
              child: GestureDetector(
                onDoubleTap: () {
                  widget.onDoubleTap?.call();
                  _showHeartAnimation();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: widget.post.mediaType == 'video'
                          ? Container(
                              color: Colors.black,
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_filled,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : Image(
                              image: CachedNetworkImageProvider(widget.post.mediaUrl!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 32,
                                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_showHeart)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.0, end: 1.3).animate(
                          CurvedAnimation(
                            parent: _heartController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => _cocircleGradient.createShader(bounds),
                          child: const Icon(
                            Icons.favorite,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 3. ACTIONS BAR - Like, comment, and badge at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Caption (if exists)
                if (widget.post.caption.isNotEmpty) ...[
                  Text(
                    widget.post.caption,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                // Time
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(widget.post.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Actions: Like, Comment, Badge
                Row(
                  children: [
                    _buildActionButton(
                      icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
                      count: widget.post.likeCount,
                      isActive: widget.post.isLiked,
                      onTap: widget.onLike,
                      useGradient: true,
                      compact: true,
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: _showComments ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      count: widget.post.commentCount,
                      onTap: _toggleComments,
                      compact: true,
                    ),
                    const Spacer(),
                    // Role Badge
                    if (widget.post.userRole.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.post.userRole,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Comments Section - Expandable
          AnimatedBuilder(
            animation: _commentController,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _commentController.value,
                  child: child,
                ),
              );
            },
            child: _showComments ? _buildCommentsSection() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Comments List
          if (_isLoadingComments)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            )
          else if (_comments.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return _buildCommentItem(comment);
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isCommentFocused
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: _cocircleGradient,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                                controller: _commentTextController,
                                focusNode: _commentFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitComment(),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16), // Rectangular rounded box
                          ),
                          child: TextField(
                            controller: _commentTextController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 15,
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitComment(),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: _cocircleGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _submitComment,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _cocircleGradient,
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                image: comment['avatarUrl'] != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(comment['avatarUrl']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: comment['avatarUrl'] == null
                  ? Icon(
                      Icons.person,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 18,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['userName'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment['timestamp']),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['text'],
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    VoidCallback? onTap,
    bool isActive = false,
    bool useGradient = false,
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Widget iconWidget;
    Color? textColor;
    
    if (isActive && useGradient) {
      iconWidget = ShaderMask(
        shaderCallback: (bounds) => _cocircleGradient.createShader(bounds),
        child: Icon(
          icon,
          size: compact ? 20 : 26,
          color: Colors.white,
        ),
      );
      textColor = null; // Will use gradient for text too
    } else {
      final iconColor = isActive
          ? AppColors.orange
          : colorScheme.onSurface.withValues(alpha: 0.7);
      iconWidget = Icon(
        icon,
        color: iconColor,
        size: compact ? 20 : 26,
      );
      textColor = iconColor;
    }

    return PressableCard(
      onTap: onTap,
      borderRadius: compact ? 16 : 24,
      child: Padding(
        padding: compact 
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            if (count > 0) ...[
              SizedBox(width: compact ? 4 : 8),
              isActive && useGradient
                  ? ShaderMask(
                      shaderCallback: (bounds) => _cocircleGradient.createShader(bounds),
                      child: Text(
                        _formatCount(count),
                        style: TextStyle(
                          fontSize: compact ? 12 : 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    )
                  : Text(
                      _formatCount(count),
                      style: TextStyle(
                        fontSize: compact ? 12 : 15,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDisplayName(dynamic post) {
    if (post == null) return 'User';
    final fullName = post.fullName as String?;
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final userName = post.userName;
    if (userName != null && userName is String) return userName;
    final username = post.username as String?;
    return username ?? 'User';
  }

  /// Handle for display (@username). Never shows UUID.
  String _getHandle(dynamic post) {
    if (post == null) return '@user';
    final username = post.username as String?;
    if (username != null && username.isNotEmpty) return '@$username';
    final userId = post.userId;
    if (userId != null && userId is String && !_isUuid(userId)) return '@$userId';
    return '@user';
  }

  bool _isUuid(String s) {
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(s);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}


