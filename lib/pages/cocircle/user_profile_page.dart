import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/follow_button.dart';

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
  final TextEditingController _bioController = TextEditingController(
    text: 'Fitness enthusiast on a journey to better health',
  );
  final FocusNode _bioFocusNode = FocusNode();
  bool _isEditingBio = false;
  int _selectedTabIndex = 0;
  
  // Mock data
  final int _postCount = 1;
  final int _followerCount = 3;
  final int _followingCount = 0;
  final int _level = 12;
  final String _userHandle = '@alexjohnson';
  
  final cocircleGradient = const LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void dispose() {
    _bioController.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  void _toggleBioEdit() {
    setState(() {
      _isEditingBio = !_isEditingBio;
      if (_isEditingBio) {
        _bioFocusNode.requestFocus();
      } else {
        _bioFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
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
          widget.userName ?? 'gopinath',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Profile Picture
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
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Username
            Text(
              widget.userName ?? 'gopinath',
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
              _userHandle,
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
    );
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
        itemCount: 1, // Show one post as in the image
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
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
          );
        },
      ),
    );
  }

  Widget _buildFollowersContent(ColorScheme colorScheme) {
    final followers = [
      {'name': 'Sarah Johnson', 'handle': '@sarahfit', 'userId': 'sarahfit', 'isFollowing': false},
      {'name': 'Mike Chen', 'handle': '@mikegains', 'userId': 'mikegains', 'isFollowing': true},
      {'name': 'Emma Wilson', 'handle': '@emmaworkout', 'userId': 'emmaworkout', 'isFollowing': false},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: followers.map((follower) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _FollowerItem(
              name: follower['name'] as String,
              handle: follower['handle'] as String,
              userId: follower['userId'] as String,
              gradient: cocircleGradient,
              isFollowing: follower['isFollowing'] as bool,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFollowingContent(ColorScheme colorScheme) {
    final following = [
      {'name': 'Alex Trainer', 'handle': '@alextrainer', 'userId': 'alextrainer'},
    ];

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: following.map((user) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _FollowingItem(
              name: user['name'] as String,
              handle: user['handle'] as String,
              userId: user['userId'] as String,
              gradient: cocircleGradient,
            ),
          );
        }).toList(),
      ),
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

  const _FollowerItem({
    required this.name,
    required this.handle,
    required this.userId,
    required this.gradient,
    this.isFollowing = false,
  });

  @override
  State<_FollowerItem> createState() => _FollowerItemState();
}

class _FollowerItemState extends State<_FollowerItem> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              gradient: widget.gradient,
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
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
          FollowButton(
            isFollowing: _isFollowing,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isFollowing = !_isFollowing;
              });
            },
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
        ],
      ),
    );
  }
}

class _FollowingItem extends StatelessWidget {
  final String name;
  final String handle;
  final String userId;
  final LinearGradient gradient;

  const _FollowingItem({
    required this.name,
    required this.handle,
    required this.userId,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(
              isOwnProfile: false,
              userId: userId,
              userName: name,
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
              gradient: gradient,
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
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
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  handle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FollowButton(
            isFollowing: true,
            onTap: () {
              // Already following
            },
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
        ],
      ),
    );
  }
}
