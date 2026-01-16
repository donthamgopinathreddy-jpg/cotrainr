import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../utils/page_transitions.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  final String _username = 'John Doe';
  final String _handle = '@fitness_john';
  final String _role = 'client';
  final String _bio =
      'Fitness enthusiast on a journey to better health and strength.';
  final int _postsCount = 42;
  final int _followersCount = 1280;
  final int _followingCount = 356;
  final bool _isSubscribed = false;
  final String? _coverImageUrl = null;
  final String? _avatarUrl = null;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileCoverHeader(
                  coverImageUrl: _coverImageUrl,
                  avatarUrl: _avatarUrl,
                  onSettings: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageTransitions.slideRoute(
                        const SettingsPage(),
                        beginOffset: const Offset(0, 0.05),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _IdentityRow(
                    username: _username,
                    handle: _handle,
                    role: _role,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _bio,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _QuickActionsRow(
                    role: _role,
                    isSubscribed: _isSubscribed,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StatsCard(
                    posts: _postsCount,
                    followers: _followersCount,
                    following: _followingCount,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ProfileTabs(
                    index: _tabIndex,
                    onChanged: (index) => setState(() => _tabIndex = index),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
        ),
    );
  }
}

class _ProfileCoverHeader extends StatelessWidget {
  final String? coverImageUrl;
  final String? avatarUrl;
  final VoidCallback onSettings;

  const _ProfileCoverHeader({
    required this.coverImageUrl,
    required this.avatarUrl,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 220;
    const double avatarSize = 96;
    final double safeTop = MediaQuery.of(context).padding.top;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: coverHeight + avatarSize / 2 + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: coverHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                image: coverImageUrl != null && coverImageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(coverImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: safeTop + 10,
            child: IconButton(
              onPressed: onSettings,
              icon: Icon(Icons.settings_rounded,
                  color: colorScheme.onSurface),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: coverHeight - avatarSize / 2,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                image: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: avatarUrl == null || avatarUrl!.isEmpty
                    ? colorScheme.surface
                    : null,
              ),
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? Icon(Icons.person,
                      size: 36, color: colorScheme.onSurface)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  final String username;
  final String handle;
  final String role;

  const _IdentityRow({
    required this.username,
    required this.handle,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                handle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: role == 'trainer'
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              role == 'trainer' ? 'TRAINER' : 'CLIENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: role == 'trainer'
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ),
      ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurface.withOpacity(0.8)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.9),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.6),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
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
                  color: isSelected ? colorScheme.primary : Colors.transparent,
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
                          : colorScheme.onSurface.withOpacity(0.7),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Icon(Icons.edit,
              color: colorScheme.onSurface.withOpacity(0.6), size: 18),
        ],
      ),
    );
  }
}
