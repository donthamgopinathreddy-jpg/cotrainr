import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../theme/design_tokens.dart';
import '../common/pill_chip.dart';

class CocircleFeedCard extends StatefulWidget {
  final dynamic post; // CocircleFeedPost
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDoubleTap;

  const CocircleFeedCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDoubleTap,
  });

  @override
  State<CocircleFeedCard> createState() => _CocircleFeedCardState();
}

class _CocircleFeedCardState extends State<CocircleFeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        boxShadow: DesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.post.avatarUrl == null
                        ? DesignTokens.primaryGradient
                        : null,
                    image: widget.post.avatarUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(widget.post.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.post.avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
                const SizedBox(width: DesignTokens.spacing12),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.userName,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeBody,
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${widget.post.userId}',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeMeta,
                                color: DesignTokens.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: DesignTokens.spacing8),
                          PillChip(
                            label: widget.post.userRole,
                            fontSize: 10,
                          ),
                          const SizedBox(width: DesignTokens.spacing8),
                          Text(
                            '· ${_formatTimestamp(widget.post.timestamp)}',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeMeta,
                              color: DesignTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Caption
          if (widget.post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacing16,
                0,
                DesignTokens.spacing16,
                DesignTokens.spacing12,
              ),
              child: Text(
                widget.post.caption,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeBody,
                  color: DesignTokens.textPrimary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Media
          if (widget.post.mediaUrl != null)
            GestureDetector(
              onDoubleTap: () {
                widget.onDoubleTap?.call();
                _showHeartAnimation();
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      gradient: widget.post.mediaUrl == null
                          ? DesignTokens.primaryGradient
                          : null,
                      image: widget.post.mediaUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(widget.post.mediaUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                  if (_showHeart)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                        CurvedAnimation(
                          parent: _heartController,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 80,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            child: Row(
              children: [
                _buildActionButton(
                  icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
                  count: widget.post.likeCount,
                  isActive: widget.post.isLiked,
                  onTap: widget.onLike,
                ),
                const SizedBox(width: DesignTokens.spacing24),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  count: widget.post.commentCount,
                  onTap: widget.onComment,
                ),
                const SizedBox(width: DesignTokens.spacing24),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  count: widget.post.shareCount,
                  onTap: widget.onShare,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  color: DesignTokens.textSecondary,
                  onPressed: () {},
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? Colors.red : DesignTokens.textSecondary,
            size: 24,
          ),
          const SizedBox(width: DesignTokens.spacing8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: DesignTokens.fontSizeBody,
              color: isActive ? Colors.red : DesignTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

