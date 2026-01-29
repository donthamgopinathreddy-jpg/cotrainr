import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_images_provider.dart';
import '../../widgets/home_v3/hero_header_v3.dart';
import '../../widgets/home_v3/quick_access_v3.dart';

class NutritionistHomePage extends ConsumerStatefulWidget {
  const NutritionistHomePage({super.key});

  @override
  ConsumerState<NutritionistHomePage> createState() => _NutritionistHomePageState();
}

class _NutritionistHomePageState extends ConsumerState<NutritionistHomePage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Mock data - in real app, fetch from Supabase
  final String _nutritionistName = 'Nutritionist Name';
  final int _notificationCount = 3;
  final int _streakDays = 0; // Nutritionists don't have streaks
  final int _totalClients = 15;
  final int _activeClients = 10;
  final int _upcomingConsultations = 4;
  final int _todayConsultations = 3;
  
  // Recent messages mock data
  final List<Map<String, dynamic>> _recentMessages = [
    {'name': 'John Doe', 'message': 'Can you review my meal plan?', 'time': '2h ago'},
    {'name': 'Jane Smith', 'message': 'I have a question about macros', 'time': '5h ago'},
  ];
  
  // Upcoming sessions mock data
  final List<Map<String, dynamic>> _upcomingSessions = [
    {'client': 'John Doe', 'time': 'Today, 2:00 PM', 'type': 'Video Consultation'},
    {'client': 'Jane Smith', 'time': 'Tomorrow, 10:00 AM', 'type': 'Video Consultation'},
  ];

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
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Widget _safeSection(BuildContext context, Widget child) {
    final cs = Theme.of(context).colorScheme;
    try {
      return child;
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: DesignTokens.cardShadowOf(context),
        ),
        child: Text(
          'Section failed to render',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
  }

  Widget _animated(Widget child, int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Transform.scale(
              scale: 0.99 + 0.01 * value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero Header with Cover Image, Profile Image, and Notification Bell
            SliverToBoxAdapter(
              child: HeroHeaderV3(
                username: _nutritionistName,
                notificationCount: _notificationCount,
                coverImageUrl: ref.watch(profileImagesProvider).coverImagePath,
                avatarUrl: ref.watch(profileImagesProvider).profileImagePath,
                streakDays: _streakDays,
                onNotificationTap: () => context.push('/notifications'),
              ),
            ),
            
            // Spacing for floating avatar
            const SliverToBoxAdapter(child: SizedBox(height: 44)),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Quick Access
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _animated(_safeSection(context, const QuickAccessV3()), 100),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Stats Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Clients',
                        _totalClients.toString(),
                        Icons.people,
                        DesignTokens.accentOrange,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),
                    Expanded(
                      child: _buildStatCard(
                        'Active',
                        _activeClients.toString(),
                        Icons.check_circle,
                        DesignTokens.accentGreen,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing20),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Upcoming',
                        _upcomingConsultations.toString(),
                        Icons.calendar_today,
                        DesignTokens.accentBlue,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),
                    Expanded(
                      child: _buildStatCard(
                        'Today',
                        _todayConsultations.toString(),
                        Icons.today,
                        DesignTokens.accentAmber,
                        surfaceColor,
                        borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

            // Upcoming Sessions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Sessions',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: DesignTokens.fontSizeH3,
                        fontWeight: DesignTokens.fontWeightBold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.push('/video?role=nutritionist');
                      },
                      child: Text(
                        'View All',
                        style: TextStyle(color: DesignTokens.accentOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing12),
            ),

            // Upcoming sessions list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: _buildUpcomingSessionsList(textPrimary, textSecondary, surfaceColor, borderColor),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

            // Recent Messages
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Messages',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: DesignTokens.fontSizeH3,
                        fontWeight: DesignTokens.fontWeightBold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.push('/messaging');
                      },
                      child: Text(
                        'View All',
                        style: TextStyle(color: DesignTokens.accentOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing12),
            ),

            // Recent messages list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                child: _buildRecentMessagesList(textPrimary, textSecondary, surfaceColor, borderColor),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: DesignTokens.spacing12),
          Text(
            value,
            style: TextStyle(
              color: DesignTokens.textPrimaryOf(context),
              fontSize: DesignTokens.fontSizeH1,
              fontWeight: DesignTokens.fontWeightBold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: DesignTokens.textSecondaryOf(context),
              fontSize: DesignTokens.fontSizeBodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSessionsList(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (_upcomingSessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(DesignTokens.spacing20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.calendar_today_outlined, size: 48, color: textSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No upcoming sessions',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: DesignTokens.fontSizeBody,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: _upcomingSessions.map((session) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: const Icon(Icons.video_call, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['client'] as String,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session['time'] as String,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: DesignTokens.fontSizeBodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondary, size: 20),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRecentMessagesList(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (_recentMessages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(DesignTokens.spacing20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.message_outlined, size: 48, color: textSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No recent messages',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: DesignTokens.fontSizeBody,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: _recentMessages.map((message) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: DesignTokens.secondaryGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: const Icon(Icons.message, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['name'] as String,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message['message'] as String,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: DesignTokens.fontSizeBodySmall,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                message['time'] as String,
                style: TextStyle(
                  color: textSecondary.withOpacity(0.7),
                  fontSize: DesignTokens.fontSizeBodySmall,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
