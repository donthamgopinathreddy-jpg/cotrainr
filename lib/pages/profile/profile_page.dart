import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _tabIndex = 0;
  final String _username = 'John Doe';
  final String _handle = '@fitness_john';
  final String _role = 'client';
  final int _level = 12;
  final String _bio =
      'Fitness enthusiast on a journey to better health and strength.';
  final int _postsCount = 42;
  final int _followersCount = 1280;
  final int _followingCount = 356;
  final bool _isSubscribed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1020),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _ProfileHeader(
              username: _username,
              handle: _handle,
              role: _role,
              level: _level,
              bio: _bio,
              posts: _postsCount,
              followers: _followersCount,
              following: _followingCount,
              isSubscribed: _isSubscribed,
              onSettings: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              },
              onTabChanged: (index) => setState(() => _tabIndex = index),
              tabIndex: _tabIndex,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 140, 16, 20),
              child: Column(
                children: const [
                  _ProfileSectionCard(title: 'About Me'),
                  SizedBox(height: 12),
                  _ProfileSectionCard(title: 'Goals'),
                  SizedBox(height: 12),
                  _ProfileSectionCard(title: 'Recent Activity'),
                  SizedBox(height: 12),
                  _ProfileSectionCard(title: 'Badges'),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String username;
  final String handle;
  final String role;
  final int level;
  final String bio;
  final int posts;
  final int followers;
  final int following;
  final bool isSubscribed;
  final VoidCallback onSettings;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const _ProfileHeader({
    required this.username,
    required this.handle,
    required this.role,
    required this.level,
    required this.bio,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isSubscribed,
    required this.onSettings,
    required this.tabIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFFFF7A00), Color(0xFFFF4F9A), Color(0xFF6C63FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return SizedBox(
      height: 360,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(gradient: gradient),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.white70),
                  const Spacer(),
                  GestureDetector(
                    onTap: onSettings,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.settings,
                          color: Colors.white70, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 20,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person, size: 36, color: Colors.white70),
            ),
          ),
          Positioned(
            left: 120,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      handle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: role == 'trainer'
                            ? AppColors.orange.withOpacity(0.35)
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          role == 'trainer' ? 'TRAINER' : 'CLIENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: role == 'trainer'
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -20,
            child: _QuickActionsRow(
              role: role,
              isSubscribed: isSubscribed,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -92,
            child: _StatsCard(
              posts: posts,
              followers: followers,
              following: following,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -156,
            child: _ProfileTabs(
              index: tabIndex,
              onChanged: onTabChanged,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -210,
            child: Text(
              bio,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final String role;
  final bool isSubscribed;

  const _QuickActionsRow({required this.role, required this.isSubscribed});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickActionButton>[
      const _QuickActionButton(label: 'Refer a Friend', icon: Icons.card_giftcard),
      _QuickActionButton(
        label: isSubscribed ? 'Manage Subscription' : 'Subscribe',
        icon: Icons.star_rounded,
      ),
      if (role == 'client')
        const _QuickActionButton(
          label: 'Become a Trainer',
          icon: Icons.school_rounded,
        )
      else
        const _QuickActionButton(
          label: 'Trainer Dashboard',
          icon: Icons.dashboard_rounded,
        ),
    ];

    return Row(
      children: actions
          .map((action) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: action,
                ),
              ))
          .toList(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;

  const _QuickActionButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;

  const _StatsCard({
    required this.posts,
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Posts', value: posts.toString()),
          _StatItem(label: 'Followers', value: followers.toString()),
          _StatItem(label: 'Following', value: following.toString()),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _ProfileTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['Posts', 'Achievements', 'Progress'];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                height: 38,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF4F9A)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                    ),
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

class _ProfileSectionCard extends StatelessWidget {
  final String title;

  const _ProfileSectionCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Icon(Icons.edit, color: Colors.white.withOpacity(0.6), size: 18),
        ],
      ),
    );
  }
}
