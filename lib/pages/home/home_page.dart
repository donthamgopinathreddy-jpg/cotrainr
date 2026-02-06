import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/messages_repository.dart';
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
  final ProfileRepository _profileRepo = ProfileRepository();
  final PostsRepository _postsRepo = PostsRepository();
  final MessagesRepository _messagesRepo = MessagesRepository();

  // Real data from Supabase
  String _username = 'Loading...';
  String? _coverImageUrl;
  String? _avatarUrl;
  int _notificationCount = 0;
  int _unreadMessagesCount = 0;
  int _streakDays = 0;
  int _currentSteps = 0;
  int _goalSteps = 10000;
  int _currentCalories = 0;
  double _currentWater = 0.0;
  double _goalWater = 2.5;
  double _bmi = 0.0;
  String _bmiStatus = '';
  String _userRole = 'client';

  // Cocircle posts
  List<CocirclePost> _cocirclePosts = [];

  // Weekly data for sparklines
  final List<double> _stepsWeeklyData = [];
  final List<double> _caloriesWeeklyData = [];
  final List<double> _waterWeeklyData = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfileData(),
      _loadCocirclePosts(),
      _loadUnreadMessages(),
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await _profileRepo.fetchMyProfile();
      if (profile != null && mounted) {
        setState(() {
          // Get username - prefer full_name, fallback to username
          final fullName = profile['full_name'] as String?;
          final username = profile['username'] as String?;
          _username = (fullName != null && fullName.isNotEmpty) 
                      ? fullName 
                      : (username ?? 'User');
          
          print('Loaded username: $_username (full_name: $fullName, username: $username)');
          
          _avatarUrl = profile['avatar_url'] as String?;
          _coverImageUrl = profile['cover_url'] as String?;
          
          // Get height and weight
          final heightCm = (profile['height_cm'] as num?)?.toDouble() ?? 0.0;
          final weightKg = (profile['weight_kg'] as num?)?.toDouble() ?? 0.0;
          
          // Calculate BMI
          if (heightCm > 0 && weightKg > 0) {
            _bmi = ProfileRepository.calculateBMI(heightCm, weightKg);
            _bmiStatus = ProfileRepository.getBMIStatus(_bmi);
          }
          
          // Get role
          _userRole = (profile['role'] as String?) ?? 'client';
        });
      } else {
        print('Profile is null or widget not mounted');
      }
      
      // Load notifications count
      await _loadNotificationsCount();
    } catch (e) {
      print('Error loading profile: $e');
      // Keep default values on error
    }
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

      if (mounted) {
        setState(() {
          _notificationCount = (response as List).length;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadAllData();
  }

  Future<void> _loadCocirclePosts() async {
    try {
      final posts = await _postsRepo.fetchRecentPosts(limit: 5);
      if (!mounted) return;

      final cocirclePosts = <CocirclePost>[];
      for (final post in posts) {
        // Get post media (first image if available)
        final media = await _postsRepo.fetchPostMedia(post['id'] as String);
        final firstMedia = media.isNotEmpty ? media.first : null;
        
        // Get author info
        final author = post['profiles'] as Map<String, dynamic>?;
        final authorUsername = author?['username'] as String? ?? 'user';
        final authorAvatar = author?['avatar_url'] as String?;

        cocirclePosts.add(CocirclePost(
          id: post['id'] as String,
          userId: authorUsername,
          imageUrl: firstMedia?['media_url'] as String?,
          avatarUrl: authorAvatar,
          likeCount: (post['likes_count'] as int?) ?? 0,
          commentCount: (post['comments_count'] as int?) ?? 0,
        ));
      }

      setState(() {
        _cocirclePosts = cocirclePosts;
      });
    } catch (e) {
      print('Error loading Cocircle posts: $e');
    }
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final count = await _messagesRepo.getUnreadMessagesCount();
      if (mounted) {
        setState(() {
          _unreadMessagesCount = count;
        });
      }
    } catch (e) {
      print('Error loading unread messages: $e');
    }
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
                  key: ValueKey(_username), // Force rebuild when username changes
                  coverImageUrl: _coverImageUrl,
                  avatarUrl: _avatarUrl,
                  username: _username,
                  notificationCount: _notificationCount + _unreadMessagesCount,
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
                child: CocirclePreviewV2(posts: _cocirclePosts),
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
