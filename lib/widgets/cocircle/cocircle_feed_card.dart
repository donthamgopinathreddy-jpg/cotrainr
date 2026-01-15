import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF5C00), width: 2),
                    image: widget.post.avatarUrl != null
                        ? DecorationImage(
                            image:
                                CachedNetworkImageProvider(widget.post.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.post.avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.black54, size: 22)
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${widget.post.userId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.post.userRole,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blue,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_horiz,
                  color: Colors.black.withOpacity(0.4),
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
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.7),
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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: widget.post.mediaUrl == null
                            ? DesignTokens.primaryGradient
                            : null,
                        image: widget.post.mediaUrl != null
                            ? DecorationImage(
                                image:
                                    CachedNetworkImageProvider(widget.post.mediaUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
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
                  color: Colors.black.withOpacity(0.45),
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
            color: isActive ? AppColors.orange : Colors.black.withOpacity(0.45),
            size: 20,
          ),
          const SizedBox(width: DesignTokens.spacing8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              color: isActive ? AppColors.orange : Colors.black.withOpacity(0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

