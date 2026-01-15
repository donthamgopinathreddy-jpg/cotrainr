import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/design_tokens.dart';

class CocirclePost {
  final String id;
  final String userId;
  final String? imageUrl;
  final String? avatarUrl;
  final int likeCount;
  final int commentCount;

  CocirclePost({
    required this.id,
    required this.userId,
    this.imageUrl,
    this.avatarUrl,
    required this.likeCount,
    required this.commentCount,
  });
}

class CocirclePreviewV2 extends StatelessWidget {
  final List<CocirclePost> posts;

  const CocirclePreviewV2({
    super.key,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cocircle',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeH2,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/home/cocircle'),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBody,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: DesignTokens.spacing12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 200 + (index * 50)),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () => context.push('/home/cocircle'),
                  child: Container(
                    width: 140,
                    margin: EdgeInsets.only(right: DesignTokens.spacing12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: DesignTokens.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Image cover
                        if (posts[index].imageUrl != null)
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: posts[index].imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: DesignTokens.surface,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: DesignTokens.surface,
                                child: Icon(
                                  Icons.image,
                                  color: DesignTokens.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: DesignTokens.surface,
                            child: Icon(
                              Icons.image,
                              color: DesignTokens.textSecondary,
                            ),
                          ),
                        // Top right badge
                        Positioned(
                          top: DesignTokens.spacing8,
                          right: DesignTokens.spacing8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'New',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Bottom overlay: avatar + @handle, left; likes + comments, right
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(DesignTokens.spacing8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundImage: posts[index].avatarUrl != null
                                          ? CachedNetworkImageProvider(
                                              posts[index].avatarUrl!)
                                          : null,
                                      child: posts[index].avatarUrl == null
                                          ? Icon(Icons.person, size: 12)
                                          : null,
                                    ),
                                    SizedBox(width: DesignTokens.spacing4),
                                    Text(
                                      '@${posts[index].userId}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_outline,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      '${posts[index].likeCount}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: DesignTokens.spacing8),
                                    Icon(
                                      Icons.comment_outlined,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      '${posts[index].commentCount}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

