import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';

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
  final int _totalClients = 15;
  final int _activeClients = 10;
  final int _upcomingConsultations = 4;
  final int _todayConsultations = 3;

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

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.spacing20),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: DesignTokens.fontSizeBody,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nutritionistName,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: DesignTokens.fontSizeH1,
                              fontWeight: DesignTokens.fontWeightBold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          context.push('/notifications');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(DesignTokens.spacing12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                          ),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats Cards
                Padding(
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

                const SizedBox(height: DesignTokens.spacing20),

                Padding(
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

                const SizedBox(height: DesignTokens.spacing24),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeH3,
                      fontWeight: DesignTokens.fontWeightBold,
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spacing12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          'Video Sessions',
                          Icons.video_call,
                          DesignTokens.primaryGradient,
                          () {
                            context.push('/video?role=nutritionist');
                          },
                          surfaceColor,
                          borderColor,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing12),
                      Expanded(
                        child: _buildQuickActionCard(
                          'My Clients',
                          Icons.people,
                          const LinearGradient(
                            colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
                          ),
                          () {
                            // Navigate to clients page (index 1 in dashboard)
                            // This will be handled by the dashboard navigation
                          },
                          surfaceColor,
                          borderColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DesignTokens.spacing24),

                // Recent Activity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                  child: Text(
                    'Recent Activity',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeH3,
                      fontWeight: DesignTokens.fontWeightBold,
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spacing12),

                // Recent activity list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.spacing16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildActivityItem(
                          'New client request from Sarah Johnson',
                          '1 hour ago',
                          Icons.person_add,
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 24),
                        _buildActivityItem(
                          'Meal plan sent to Mike Wilson',
                          '3 hours ago',
                          Icons.restaurant_menu,
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 24),
                        _buildActivityItem(
                          'Upcoming consultation in 1 hour',
                          'Just now',
                          Icons.access_time,
                          DesignTokens.accentOrange,
                          textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spacing32),
              ],
            ),
          ),
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

  Widget _buildQuickActionCard(
    String label,
    IconData icon,
    Gradient gradient,
    VoidCallback onTap,
    Color surfaceColor,
    Color borderColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacing20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.fontSizeBody,
                fontWeight: DesignTokens.fontWeightSemiBold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color titleColor,
    Color timeColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignTokens.spacing8),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          ),
          child: Icon(icon, size: 20, color: titleColor),
        ),
        const SizedBox(width: DesignTokens.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: DesignTokens.fontWeightMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: timeColor,
                  fontSize: DesignTokens.fontSizeBodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
