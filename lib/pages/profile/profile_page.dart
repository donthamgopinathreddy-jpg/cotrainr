import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_stats_row.dart';
import '../../widgets/profile/profile_tabs.dart';
import '../../widgets/profile/profile_posts_grid.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Mock data - Replace with real data from providers
  final String _username = 'John Doe';
  final String _handle = '@fitness_john';
  final int _level = 12;
  final String _bio = 'Fitness enthusiast | Runner | Always pushing limits 💪';
  final int _postsCount = 42;
  final int _followersCount = 1280;
  final int _followingCount = 356;
  final List<String> _postImages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _loadMockData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    // Mock post images
    for (int i = 0; i < 12; i++) {
      _postImages.add(''); // Empty for now, will show gradient placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.backgroundOf(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: ProfileHeader(
              username: _username,
              handle: _handle,
              level: _level,
              bio: _bio,
              coverImageUrl: null,
              avatarUrl: null,
              onEditProfile: () {
                HapticFeedback.lightImpact();
                // TODO: Navigate to edit profile
              },
              onSettings: () {
                HapticFeedback.lightImpact();
                // TODO: Navigate to settings
              },
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: ProfileStatsRow(
              posts: _postsCount,
              followers: _followersCount,
              following: _followingCount,
            ),
          ),

          // Tabs
          SliverToBoxAdapter(
            child: ProfileTabs(
              controller: _tabController,
              onTabChanged: (index) {
                HapticFeedback.lightImpact();
                setState(() => _selectedTabIndex = index);
              },
            ),
          ),

          // Content based on selected tab
          SliverToBoxAdapter(
            child: _buildTabContent(),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // Posts
        return ProfilePostsGrid(images: _postImages);
      case 1: // Achievements
        return _buildAchievementsTab();
      case 2: // Activity
        return _buildActivityTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAchievementsTab() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      child: Column(
        children: [
          Text(
            'Achievements',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeH2,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: DesignTokens.spacing16,
              mainAxisSpacing: DesignTokens.spacing16,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  gradient: DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  boxShadow: DesignTokens.glowShadow,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      child: Column(
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeH2,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceOf(context),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  boxShadow: DesignTokens.cardShadowOf(context),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: DesignTokens.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                    const SizedBox(width: DesignTokens.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed daily quest',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeBody,
                              fontWeight: FontWeight.w600,
                              color: DesignTokens.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing4),
                          Text(
                            '2 hours ago',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeMeta,
                              color: DesignTokens.textSecondaryOf(context),
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
        ],
      ),
    );
  }
}

