/// Model for CoCircle feed post (Instagram-style).
/// Use [username] for handle display (@username), [authorId] for navigation/follow.
class CocircleFeedPost {
  final String id;
  final String authorId;
  final String username;
  final String fullName;
  final String userRole;
  final String? avatarUrl;
  final DateTime timestamp;
  final String? mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String caption;
  int likeCount;
  int commentCount;
  final int shareCount;
  bool isLiked;
  final List<Map<String, dynamic>> media;

  CocircleFeedPost({
    required this.id,
    required this.authorId,
    required this.username,
    required this.fullName,
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
    this.media = const [],
  });

  /// Display name (full name or username fallback)
  String get userName => fullName.isNotEmpty ? fullName : username;

  /// Handle for display (e.g. @username). Never shows UUID.
  String get handle => username.isNotEmpty ? '@$username' : '@user';
}
