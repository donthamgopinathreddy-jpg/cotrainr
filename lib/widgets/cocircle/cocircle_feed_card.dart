import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../common/pressable_card.dart';
import '../common/follow_button.dart';

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
  final TextEditingController _commentTextController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];

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

  void _loadComments() {
    // TODO: Load comments from API
    // For now, using sample data
    setState(() {
      _comments.addAll([
        {
          'id': '1',
          'userId': 'user1',
          'userName': 'John Doe',
          'avatarUrl': null,
          'text': 'Great post! Keep it up! 👏',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': '2',
          'userId': 'user2',
          'userName': 'Jane Smith',
          'avatarUrl': null,
          'text': 'Love this! Thanks for sharing.',
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
        },
      ]);
    });
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
      if (_showComments) {
        _commentController.forward();
        widget.onComment?.call();
      } else {
        _commentController.reverse();
      }
    });
  }

  void _submitComment() {
    final text = _commentTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': 'current_user',
        'userName': 'You',
        'avatarUrl': null,
        'text': text,
        'timestamp': DateTime.now(),
      });
      _commentTextController.clear();
    });
    // TODO: Submit comment to API
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Clean, minimal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: widget.onProfileTap,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _cocircleGradient,
                    ),
                    padding: const EdgeInsets.all(2.5),
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
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // User Info
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.post.userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '@${widget.post.userId}',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(widget.post.timestamp),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                if (!widget.isOwnPost)
                  FollowButton(
                    isFollowing: widget.isFollowing,
                    onTap: widget.onFollow,
                  ),
              ],
            ),
          ),

          // Caption - Above media for better readability
          if (widget.post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                widget.post.caption,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.9),
                  height: 1.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),

          // Media - Full width within card
          if (hasMedia)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: GestureDetector(
                onDoubleTap: () {
                  widget.onDoubleTap?.call();
                  _showHeartAnimation();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 500,
                          maxHeight: 700,
                        ),
                        child: Image(
                          image: CachedNetworkImageProvider(widget.post.mediaUrl!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 500,
                              color: colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                              ),
                            );
                          },
                        ),
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
                            size: 120,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Actions Bar - Modern, spacious
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Row(
              children: [
                _buildActionButton(
                  icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
                  count: widget.post.likeCount,
                  isActive: widget.post.isLiked,
                  onTap: widget.onLike,
                  useGradient: true,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: _showComments ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  count: widget.post.commentCount,
                  onTap: _toggleComments,
                ),
                const Spacer(),
                // Role Badge (if applicable) - aligned with comment box
                if (widget.post.userRole.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.post.userRole,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                        letterSpacing: 0.5,
                      ),
                    ),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Comments List
          if (_comments.isNotEmpty)
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Widget iconWidget;
    Color? textColor;
    
    if (isActive && useGradient) {
      iconWidget = ShaderMask(
        shaderCallback: (bounds) => _cocircleGradient.createShader(bounds),
        child: Icon(
          icon,
          size: 26,
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
        size: 26,
      );
      textColor = iconColor;
    }

    return PressableCard(
      onTap: onTap,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            if (count > 0) ...[
              const SizedBox(width: 8),
              isActive && useGradient
                  ? ShaderMask(
                      shaderCallback: (bounds) => _cocircleGradient.createShader(bounds),
                      child: Text(
                        _formatCount(count),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    )
                  : Text(
                      _formatCount(count),
                      style: TextStyle(
                        fontSize: 15,
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


