import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/common/follow_button.dart';
import '../../widgets/common/pressable_card.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/follow_repository.dart';
import '../../repositories/messages_repository.dart';
import '../../pages/messaging/chat_screen.dart';

class UserProfilePage extends StatefulWidget {
  final bool isOwnProfile;
  final String? userId;
  final String? userName;
  
  const UserProfilePage({
    super.key,
    this.isOwnProfile = true,
    this.userId,
    this.userName,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _bioFocusNode = FocusNode();
  final ProfileRepository _profileRepo = ProfileRepository();
  final PostsRepository _postsRepo = PostsRepository();
  final FollowRepository _followRepo = FollowRepository();
  final MessagesRepository _messagesRepo = MessagesRepository();
  
  bool _isEditingBio = false;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  
  List<Map<String, dynamic>> _userPosts = [];
  String? _avatarUrl;
  String? _username;
  String? _fullName;
  String? _bio;
  int _postCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  int _level = 1; // TODO: Get from user_profiles table
  String? _currentUserId; // Store current user ID for delete check
  String? _profileUserId; // The user ID of the profile being viewed
  
  final cocircleGradient = const LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Get current user ID
      _currentUserId = Supabase.instance.client.auth.currentUser?.id;
      
      final userId = widget.userId ?? _currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _profileUserId = userId;

      // Fetch user profile
      final profile = await _profileRepo.fetchUserProfile(userId);
      if (profile != null) {
        _username = profile['username'] as String?;
        _fullName = profile['full_name'] as String?;
        _bio = profile['bio'] as String?;
        _avatarUrl = profile['avatar_url'] as String?;
        _bioController.text = _bio ?? '';
      }

      // Fetch user posts
      print('Loading posts for user profile: $userId');
      final posts = await _postsRepo.fetchUserPosts(userId);
      print('Received ${posts.length} posts for user profile');
      _userPosts = posts;
      _postCount = posts.length;

      // Fetch follower and following counts
      _followerCount = await _followRepo.getFollowerCount(userId);
      _followingCount = await _followRepo.getFollowingCount(userId);

      // Check if current user is following this profile user
      if (!widget.isOwnProfile && _currentUserId != null) {
        _isFollowing = await _followRepo.isFollowing(userId);
      }

      // TODO: Fetch level from user_profiles table
      try {
        final userProfileResponse = await Supabase.instance.client
            .from('user_profiles')
            .select('level')
            .eq('user_id', userId)
            .maybeSingle();
        if (userProfileResponse != null) {
          _level = (userProfileResponse['level'] as int?) ?? 1;
        }
      } catch (e) {
        // Ignore if user_profiles doesn't exist for this user
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleBioEdit() {
    setState(() {
      _isEditingBio = !_isEditingBio;
      if (_isEditingBio) {
        _bioFocusNode.requestFocus();
      } else {
        _bioFocusNode.unfocus();
        // Save bio if it's own profile
        if (widget.isOwnProfile && _bioController.text != _bio) {
          _saveBio();
        }
      }
    });
  }

  Future<void> _saveBio() async {
    try {
      await _profileRepo.updateProfile({'bio': _bioController.text});
      setState(() {
        _bio = _bioController.text;
      });
    } catch (e) {
      print('Error saving bio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save bio')),
        );
      }
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profileUserId == null || _currentUserId == null) return;
    if (_isLoadingFollow) return;

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await _followRepo.unfollowUser(_profileUserId!);
        if (success) {
          setState(() {
            _isFollowing = false;
            _followerCount = (_followerCount - 1).clamp(0, double.infinity).toInt();
          });
        }
      } else {
        success = await _followRepo.followUser(_profileUserId!);
        if (success) {
          setState(() {
            _isFollowing = true;
            _followerCount++;
          });
        }
      }

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? 'Failed to unfollow' : 'Failed to follow'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  Future<void> _handleMessage() async {
    if (_profileUserId == null || _currentUserId == null) return;
    if (_profileUserId == _currentUserId) return;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening chat...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Create or find conversation with the profile user
      final conversationId = await _messagesRepo.createOrFindConversation(_profileUserId!);
      
      if (conversationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to create conversation. Please try again.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Navigate to chat screen
      if (mounted) {
        final name = _fullName ?? _username ?? widget.userName ?? 'User';
        final gradient = _getGradientForName(name);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              userName: name,
              avatarGradient: gradient,
              isOnline: false,
              avatarUrl: _avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error opening message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  LinearGradient _getGradientForName(String name) {
    final hash = name.hashCode;
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFFB74D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFAB47BC), Color(0xFFBA68C8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A2335) // Dark blue-black mix
        : const Color(0xFFE3F2FD); // Very light blue

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.onSurface,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        title: Text(
          _fullName ?? _username ?? widget.userName ?? 'User',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  // Profile Picture - shows real user avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: cocircleGradient,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surface,
                      ),
                      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: _avatarUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 120,
                                  height: 120,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.person,
                                    size: 60,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 120,
                                  height: 120,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.person,
                                    size: 60,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Username
                  Text(
                    _fullName ?? _username ?? widget.userName ?? 'User',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // User Handle
                  Text(
                    _username != null ? '@$_username' : '',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
            const SizedBox(height: 12),
            // Level Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Level $_level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bio with Edit Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _isEditingBio
                        ? TextField(
                            controller: _bioController,
                            focusNode: _bioFocusNode,
                            maxLines: 2,
                            maxLength: 150,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Write your bio...',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              counterText: '',
                            ),
                            onSubmitted: (_) => _toggleBioEdit(),
                          )
                        : Text(
                            _bioController.text.isEmpty
                                ? 'No bio yet'
                                : _bioController.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  if (widget.isOwnProfile) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _toggleBioEdit();
                      },
                      child: Icon(
                        _isEditingBio ? Icons.check : Icons.edit,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Follow and Message buttons for other users
            if (!widget.isOwnProfile && _profileUserId != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: FollowButton(
                        isFollowing: _isFollowing,
                        onTap: _isLoadingFollow ? null : _handleFollowToggle,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PressableCard(
                        onTap: _handleMessage,
                        borderRadius: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: cocircleGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Message',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Tab Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProfileTabs(
                selectedIndex: _selectedTabIndex,
                onTabChanged: (index) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
                gradient: cocircleGradient,
                postCount: _postCount,
                followerCount: _followerCount,
                followingCount: _followingCount,
              ),
            ),
            const SizedBox(height: 24),
            // Content based on selected tab
            _buildTabContent(_selectedTabIndex, colorScheme),
            const SizedBox(height: 24),
          ],
        ),
      ),
            ),
    );
  }

  void _showFloatingPostView(Map<String, dynamic> post, int postIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Handle post_media structure
    final media = post['post_media'];
    Map<String, dynamic>? firstMedia;
    
    if (media != null) {
      if (media is List && media.isNotEmpty) {
        firstMedia = media[0] as Map<String, dynamic>?;
      } else if (media is Map) {
        firstMedia = media as Map<String, dynamic>?;
      }
    }
    
    final mediaUrl = firstMedia?['media_url'] as String?;
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    final postId = post['id'] as String;
    final postAuthorId = post['author_id'] as String;
    final isOwnPost = _currentUserId != null && postAuthorId == _currentUserId;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.transparent,
            child: Stack(
              children: [
                // Full screen image
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.error_outline,
                            color: colorScheme.error,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Delete button (only for own posts, shown at top)
                if (isOwnPost)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showDeleteDialog(postId, postIndex);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                // Close button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(String postId, int postIndex) async {
    final colorScheme = Theme.of(context).colorScheme;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Post',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePost(postId, postIndex);
    }
  }

  Future<void> _deletePost(String postId, int postIndex) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting post...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Delete from database
      await _postsRepo.deletePost(postId);

      // Remove from local list
      if (mounted) {
        setState(() {
          _userPosts.removeAt(postIndex);
          _postCount = _userPosts.length;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTabContent(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0: // Posts
        return _buildPostsContent(colorScheme);
      case 1: // Followers
        return _buildFollowersContent(colorScheme);
      case 2: // Following
        return _buildFollowingContent(colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPostsContent(ColorScheme colorScheme) {
    if (_userPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.grid_view_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemCount: _userPosts.length,
        itemBuilder: (context, index) {
          final post = _userPosts[index];
          // Handle post_media structure - it can be a List or null
          final media = post['post_media'];
          Map<String, dynamic>? firstMedia;
          
          if (media != null) {
            if (media is List && media.isNotEmpty) {
              firstMedia = media[0] as Map<String, dynamic>?;
            } else if (media is Map) {
              firstMedia = media as Map<String, dynamic>?;
            }
          }
          
          final mediaUrl = firstMedia?['media_url'] as String?;

          final postId = post['id'] as String;
          final postAuthorId = post['author_id'] as String;
          final isOwnPost = _currentUserId != null && postAuthorId == _currentUserId;

          return GestureDetector(
            onTap: mediaUrl != null && mediaUrl.isNotEmpty
                ? () => _showFloatingPostView(post, index)
                : null,
            onLongPress: isOwnPost ? () => _showDeleteDialog(postId, index) : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colorScheme.surfaceContainerHighest,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: mediaUrl != null && mediaUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            size: 32,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            size: 32,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.orange.withValues(alpha: 0.3),
                              Colors.purple.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.image,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          size: 32,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowersContent(ColorScheme colorScheme) {
    if (_profileUserId == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No followers yet',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _followRepo.getFollowers(_profileUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading followers',
              style: TextStyle(color: colorScheme.error),
            ),
          );
        }

        final followers = snapshot.data ?? [];
        if (followers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No followers yet',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final follower = followers[index];
            final profile = follower['profiles'] as Map<String, dynamic>?;
            if (profile == null) return const SizedBox.shrink();

            final followerId = follower['follower_id'] as String;
            final name = profile['full_name'] as String? ?? 
                        profile['username'] as String? ?? 
                        'Unknown User';
            final username = profile['username'] as String? ?? '';
            final avatarUrl = profile['avatar_url'] as String?;
            final isFollowing = follower['is_following'] as bool? ?? false;

            return _FollowerItem(
              name: name,
              handle: '@$username',
              userId: followerId,
              gradient: _getGradientForName(name),
              isFollowing: isFollowing,
              avatarUrl: avatarUrl,
            );
          },
        );
      },
    );
  }

  Widget _buildFollowingContent(ColorScheme colorScheme) {
    if (_profileUserId == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Not following anyone yet',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _followRepo.getFollowing(_profileUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading following',
              style: TextStyle(color: colorScheme.error),
            ),
          );
        }

        final following = snapshot.data ?? [];
        if (following.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Not following anyone yet',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: following.length,
          itemBuilder: (context, index) {
            final follow = following[index];
            final profile = follow['profiles'] as Map<String, dynamic>?;
            if (profile == null) return const SizedBox.shrink();

            final followingId = follow['following_id'] as String;
            final name = profile['full_name'] as String? ?? 
                        profile['username'] as String? ?? 
                        'Unknown User';
            final username = profile['username'] as String? ?? '';
            final avatarUrl = profile['avatar_url'] as String?;
            final isFollowing = follow['is_following'] as bool? ?? true; // Profile user is already following them

            return _FollowingItem(
              name: name,
              handle: '@$username',
              userId: followingId,
              gradient: _getGradientForName(name),
              isFollowing: isFollowing,
              avatarUrl: avatarUrl,
            );
          },
        );
      },
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final LinearGradient gradient;
  final int postCount;
  final int followerCount;
  final int followingCount;

  const _ProfileTabs({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.gradient,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = [
      {'icon': Icons.grid_view_rounded, 'count': postCount},
      {'icon': Icons.people_rounded, 'count': followerCount},
      {'icon': Icons.person_add_rounded, 'count': followingCount},
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          final tab = tabs[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(index),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isSelected ? gradient : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab['count'].toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FollowerItem extends StatefulWidget {
  final String name;
  final String handle;
  final String userId;
  final LinearGradient gradient;
  final bool isFollowing;
  final String? avatarUrl;

  const _FollowerItem({
    required this.name,
    required this.handle,
    required this.userId,
    required this.gradient,
    this.isFollowing = false,
    this.avatarUrl,
  });

  @override
  State<_FollowerItem> createState() => _FollowerItemState();
}

class _FollowerItemState extends State<_FollowerItem> {
  late bool _isFollowing;
  final FollowRepository _followRepo = FollowRepository();

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  Future<void> _handleFollowToggle() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId) return;

    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await _followRepo.followUser(widget.userId);
      } else {
        success = await _followRepo.unfollowUser(widget.userId);
      }

      if (!success) {
        // Revert on failure
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      print('Error toggling follow: $e');
      // Revert on error
      setState(() {
        _isFollowing = !_isFollowing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.userId;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(
              isOwnProfile: false,
              userId: widget.userId,
              userName: widget.name,
            ),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.avatarUrl == null ? widget.gradient : null,
            ),
            padding: const EdgeInsets.all(2),
            child: widget.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.avatarUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.gradient,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                    ),
                    child: Icon(
                      Icons.person,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.handle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isOwnProfile)
            FollowButton(
              isFollowing: _isFollowing,
              onTap: _handleFollowToggle,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
        ],
      ),
    );
  }
}

class _FollowingItem extends StatefulWidget {
  final String name;
  final String handle;
  final String userId;
  final LinearGradient gradient;
  final bool isFollowing;
  final String? avatarUrl;

  const _FollowingItem({
    required this.name,
    required this.handle,
    required this.userId,
    required this.gradient,
    this.isFollowing = true,
    this.avatarUrl,
  });

  @override
  State<_FollowingItem> createState() => _FollowingItemState();
}

class _FollowingItemState extends State<_FollowingItem> {
  late bool _isFollowing;
  final FollowRepository _followRepo = FollowRepository();

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  Future<void> _handleFollowToggle() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId) return;

    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await _followRepo.followUser(widget.userId);
      } else {
        success = await _followRepo.unfollowUser(widget.userId);
      }

      if (!success) {
        // Revert on failure
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      print('Error toggling follow: $e');
      // Revert on error
      setState(() {
        _isFollowing = !_isFollowing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.userId;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(
              isOwnProfile: false,
              userId: widget.userId,
              userName: widget.name,
            ),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.avatarUrl == null ? widget.gradient : null,
            ),
            padding: const EdgeInsets.all(2),
            child: widget.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.avatarUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.gradient,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                    ),
                    child: Icon(
                      Icons.person,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.handle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isOwnProfile)
            FollowButton(
              isFollowing: _isFollowing,
              onTap: _handleFollowToggle,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
        ],
      ),
    );
  }
}
