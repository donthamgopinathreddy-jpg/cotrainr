import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/home/hero_header_widget.dart';
import '../../widgets/home/streak_card_v2.dart';
import '../../widgets/home/steps_card_v2.dart';
import '../../widgets/home/calories_water_row_v2.dart';
import '../../widgets/home/bmi_card_v2.dart';
import '../../widgets/home/quick_access_v2.dart';
import '../../widgets/home/cocircle_preview_v2.dart'
    show CocirclePost, CocirclePreviewV2;
import '../../widgets/home/nearby_preview_v2.dart'
    show NearbyPlace, NearbyPreviewV2;

/// Home Screen UI
/// Layout Order:
/// 1. Hero header with cover image + avatar
/// 2. Streak card
/// 3. Steps primary card
/// 4. Calories and water row
/// 5. BMI card
/// 6. Quick access grid
/// 7. Cocircle preview
/// 8. Nearby places
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  // Mock data - Replace with real data from providers
  final String _username = 'John Doe';
  final String? _coverImageUrl = null; // null for gradient placeholder
  final String? _avatarUrl = null; // null for gradient placeholder
  final int _notificationCount = 3;
  final int _streakDays = 7;
  final int _currentSteps = 8234;
  final int _goalSteps = 10000;
  final int _currentCalories = 1856;
  final double _currentWater = 1.5;
  final double _goalWater = 2.5;
  final double _bmi = 22.4;
  final String _bmiStatus = 'Normal';
  final String _userRole = 'client';

  // Weekly data for sparklines
  final List<double> _stepsWeeklyData = [6.2, 7.1, 8.3, 7.8, 8.5, 8.2, 8.0];
  final List<double> _caloriesWeeklyData = [1.8, 2.0, 1.9, 2.1, 1.7, 1.9, 1.8];
  final List<double> _waterWeeklyData = [1.2, 1.5, 1.8, 1.6, 1.4, 1.7, 1.5];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    // TODO: Refresh data from providers
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.backgroundOf(context),
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Hero Header with Cover Image + Avatar
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: HeroHeaderWidget(
                  coverImageUrl: _coverImageUrl,
                  avatarUrl: _avatarUrl,
                  username: _username,
                  notificationCount: _notificationCount,
                ),
              ),
            ),

            // Spacing for floating avatar
            const SliverToBoxAdapter(child: SizedBox(height: 44)),

            // 2. Streak Card
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: StreakCardV2(streakDays: _streakDays),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing16),
            ),

            // 3. Steps Primary Card
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: StepsCardV2(
                  currentSteps: _currentSteps,
                  goalSteps: _goalSteps,
                  weeklyData: _stepsWeeklyData,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing16),
            ),

            // 4. Calories and Water Row
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: CaloriesWaterRowV2(
                  currentCalories: _currentCalories,
                  caloriesWeeklyData: _caloriesWeeklyData,
                  currentWater: _currentWater,
                  goalWater: _goalWater,
                  waterWeeklyData: _waterWeeklyData,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing16),
            ),

            // 5. BMI Card
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: BmiCardV2(bmi: _bmi, status: _bmiStatus),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

            // 6. Quick Access Grid
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: QuickAccessV2(userRole: _userRole),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

            // 7. Cocircle Preview
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: CocirclePreviewV2(posts: _getMockCocirclePosts()),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spacing24),
            ),

            // 8. Nearby Places
            SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: DesignTokens.animationMedium,
                curve: DesignTokens.animationCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: NearbyPreviewV2(places: _getMockNearbyPlaces()),
              ),
            ),

            // Bottom padding for bottom nav
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  List<CocirclePost> _getMockCocirclePosts() {
    return [
      CocirclePost(
        id: '1',
        userId: 'fitness_john',
        imageUrl: null, // Placeholder
        avatarUrl: null, // Placeholder
        likeCount: 24,
        commentCount: 5,
      ),
      CocirclePost(
        id: '2',
        userId: 'trainer_sarah',
        imageUrl: null, // Placeholder
        avatarUrl: null, // Placeholder
        likeCount: 56,
        commentCount: 12,
      ),
      CocirclePost(
        id: '3',
        userId: 'nutritionist_mike',
        imageUrl: null, // Placeholder
        avatarUrl: null, // Placeholder
        likeCount: 12,
        commentCount: 3,
      ),
    ];
  }

  List<NearbyPlace> _getMockNearbyPlaces() {
    return [
      NearbyPlace(
        id: '1',
        name: 'Gold\'s Gym',
        category: 'Gyms',
        rating: 4.5,
        distance: 0.8,
        thumbnailUrl: null,
        imageUrl: null, // Will use placeholder gradient
      ),
      NearbyPlace(
        id: '2',
        name: 'The Yoga Institute',
        category: 'Yoga',
        rating: 4.8,
        distance: 1.2,
        thumbnailUrl: null,
        imageUrl: null, // Will use placeholder gradient
      ),
      NearbyPlace(
        id: '3',
        name: 'Cult.fit Center',
        category: 'Gyms',
        rating: 4.6,
        distance: 1.5,
        thumbnailUrl: null,
        imageUrl: null, // Will use placeholder gradient
      ),
      NearbyPlace(
        id: '4',
        name: 'Anytime Fitness',
        category: 'Gyms',
        rating: 4.4,
        distance: 2.1,
        thumbnailUrl: null,
        imageUrl: null, // Will use placeholder gradient
      ),
      NearbyPlace(
        id: '5',
        name: 'Talwalkars Gym',
        category: 'Gyms',
        rating: 4.7,
        distance: 2.5,
        thumbnailUrl: null,
        imageUrl: null, // Will use placeholder gradient
      ),
    ];
  }
}
