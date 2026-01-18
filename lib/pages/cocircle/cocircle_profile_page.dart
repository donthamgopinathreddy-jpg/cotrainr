import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CocircleProfilePage extends StatefulWidget {
  final bool isOwnProfile;
  final String? userId; // User ID to show profile for
  final String? userName; // Username to display in header
  
  const CocircleProfilePage({
    super.key,
    this.isOwnProfile = true,
    this.userId,
    this.userName,
  });

  @override
  State<CocircleProfilePage> createState() => _CocircleProfilePageState();
}

class _CocircleProfilePageState extends State<CocircleProfilePage> {
  final TextEditingController _bioController = TextEditingController(
    text: 'Fitness enthusiast on a journey to better health',
  );
  final FocusNode _bioFocusNode = FocusNode();
  bool _isEditingBio = false;
  int _selectedTabIndex = 0;
  bool _isFollowing = false;
  
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

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: ShaderMask(
            shaderCallback: (rect) => cocircleGradient.createShader(rect),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (rect) => cocircleGradient.createShader(rect),
          child: Text(
            widget.userName ?? 'gopinath',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Center(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (rect) => cocircleGradient.createShader(rect),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4DA3FF).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (rect) => cocircleGradient.createShader(rect),
                  child: Text(
                    widget.userName ?? 'gopinath',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@alexjohnson',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: cocircleGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4DA3FF).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Level 12',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Bio with edit
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _isEditingBio
                            ? TextField(
                                controller: _bioController,
                                focusNode: _bioFocusNode,
                                maxLines: 3,
                                maxLength: 150,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  hintText: 'Write your bio...',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.4),
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
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                      ),
                      if (widget.isOwnProfile) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _toggleBioEdit,
                          child: ShaderMask(
                            shaderCallback: (rect) =>
                                cocircleGradient.createShader(rect),
                            child: Icon(
                              _isEditingBio ? Icons.check : Icons.edit,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!widget.isOwnProfile) ...[
                  const SizedBox(height: 16),
                  // Follow button (only for other users)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isFollowing = !_isFollowing;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _isFollowing ? null : cocircleGradient,
                        color: _isFollowing
                            ? colorScheme.surfaceVariant
                            : null,
                        borderRadius: BorderRadius.circular(24),
                        border: _isFollowing
                            ? Border.all(
                                color: colorScheme.outline.withOpacity(0.2))
                            : null,
                        boxShadow: _isFollowing
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF4DA3FF).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _isFollowing
                              ? colorScheme.onSurface
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tabs with slider
          _ProfileTabsSlider(
            selectedIndex: _selectedTabIndex,
            onTabChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            gradient: cocircleGradient,
          ),
          const SizedBox(height: 16),
          // Content based on selected tab
          _buildTabContent(_selectedTabIndex, colorScheme),
        ],
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.image,
              color: colorScheme.onSurface.withOpacity(0.3),
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowersContent(ColorScheme colorScheme) {
    final followers = [
      {'name': 'Sarah Johnson', 'handle': '@sarahfit', 'isFollowing': false},
      {'name': 'Mike Chen', 'handle': '@mikegains', 'isFollowing': true},
      {'name': 'Emma Wilson', 'handle': '@emmaworkout', 'isFollowing': false},
    ];

    return Column(
      children: followers.map((follower) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _FollowerItem(
            name: follower['name'] as String,
            handle: follower['handle'] as String,
            gradient: cocircleGradient,
            isFollowing: follower['isFollowing'] as bool,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFollowingContent(ColorScheme colorScheme) {
    final following = [
      {'name': 'Alex Trainer', 'handle': '@alextrainer'},
    ];

    if (following.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Not following anyone yet',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: following.map((user) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _FollowingItem(
            name: user['name'] as String,
            handle: user['handle'] as String,
            gradient: cocircleGradient,
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileTabsSlider extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final LinearGradient gradient;

  const _ProfileTabsSlider({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.gradient,
  });

  @override
  State<_ProfileTabsSlider> createState() => _ProfileTabsSliderState();
}

class _ProfileTabsSliderState extends State<_ProfileTabsSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(_ProfileTabsSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = ['Posts 1', 'Followers 3', 'Following 0'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.none,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available width (total width minus padding)
          final availableWidth = constraints.maxWidth - 6; // 3px left + 3px right
          final tabWidth = availableWidth / 3;
          
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Sliding pill background
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  // Calculate the left position of the pill
                  // Start at padding (3) + offset based on selected index
                  final targetOffset = widget.selectedIndex * tabWidth;
                  final currentOffset = targetOffset * _animation.value;
                  
                  return Positioned(
                    left: 3 + currentOffset,
                    top: 3,
                    child: Container(
                      width: tabWidth,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: widget.gradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  );
                },
              ),
              // Tab buttons
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = index == widget.selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onTabChanged(index);
                      },
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tabs[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: isSelected
                                ? Colors.white
                                : colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FollowerItem extends StatefulWidget {
  final String name;
  final String handle;
  final LinearGradient gradient;
  final bool isFollowing;

  const _FollowerItem({
    required this.name,
    required this.handle,
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

    return Row(
      children: [
        ShaderMask(
          shaderCallback: (rect) => widget.gradient.createShader(rect),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
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
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isFollowing = !_isFollowing;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: _isFollowing ? null : widget.gradient,
              color: _isFollowing ? colorScheme.surfaceVariant : null,
              borderRadius: BorderRadius.circular(20),
              border: _isFollowing
                  ? Border.all(color: colorScheme.outline.withOpacity(0.2))
                  : null,
            ),
            child: Text(
              _isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isFollowing
                    ? colorScheme.onSurface
                    : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FollowingItem extends StatelessWidget {
  final String name;
  final String handle;
  final LinearGradient gradient;

  const _FollowingItem({
    required this.name,
    required this.handle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        ShaderMask(
          shaderCallback: (rect) => gradient.createShader(rect),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
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
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            'Following',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
