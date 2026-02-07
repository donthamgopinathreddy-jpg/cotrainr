import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/messages_repository.dart';
import '../../repositories/metrics_repository.dart';
import '../../services/health_tracking_service.dart';
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
  final MetricsRepository _metricsRepo = MetricsRepository();
  final HealthTrackingService _healthService = HealthTrackingService();

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
    _loadStreak();
    _loadMetrics();
    _startMetricsSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload notifications when returning from notifications page
    // This ensures the red dot disappears after checking notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationsCount();
    });
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfileData(),
      _loadCocirclePosts(),
      _loadUnreadMessages(),
    ]);
  }

  Future<void> _loadStreak() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get today's metrics to check last login date
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      
      // Get or create today's metrics
      final todayMetrics = await supabase
          .from('metrics_daily')
          .select('id, date, streak_days')
          .eq('user_id', userId)
          .eq('date', todayDate.toIso8601String().split('T')[0])
          .maybeSingle();

      // Get yesterday's metrics to calculate streak
      final yesterday = todayDate.subtract(const Duration(days: 1));
      final yesterdayMetrics = await supabase
          .from('metrics_daily')
          .select('date, streak_days')
          .eq('user_id', userId)
          .eq('date', yesterday.toIso8601String().split('T')[0])
          .maybeSingle();

      int newStreak = 1;
      
      if (yesterdayMetrics != null) {
        final yesterdayStreak = (yesterdayMetrics['streak_days'] as num?)?.toInt() ?? 0;
        final yesterdayDate = DateTime.parse(yesterdayMetrics['date'] as String);
        final daysDiff = todayDate.difference(yesterdayDate).inDays;
        
        if (daysDiff == 1) {
          // Consecutive day, increment streak
          newStreak = yesterdayStreak + 1;
        } else {
          // Gap in login, reset to 1
          newStreak = 1;
        }
      }

      // Update or insert today's metrics with streak
      if (todayMetrics != null) {
        await supabase
            .from('metrics_daily')
            .update({'streak_days': newStreak})
            .eq('id', todayMetrics['id'] as String);
      } else {
        await supabase
            .from('metrics_daily')
            .insert({
              'user_id': userId,
              'date': todayDate.toIso8601String().split('T')[0],
              'streak_days': newStreak,
            });
      }

      if (mounted) {
        setState(() {
          _streakDays = newStreak;
        });
      }
    } catch (e) {
      print('Error loading streak: $e');
      // Fallback to 0 if error
      if (mounted) {
        setState(() {
          _streakDays = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      print('HomePage: Starting to load profile data...');
      final profile = await _profileRepo.fetchMyProfile();
      
      if (!mounted) {
        print('HomePage: Widget not mounted, skipping state update');
        return;
      }
      
      if (profile != null) {
        print('HomePage: Full profile data: $profile');
        
        // Get full name (first and last name) for welcome message
        final fullName = profile['full_name'] as String?;
        final username = profile['username'] as String?;
        final avatarUrl = profile['avatar_url'] as String?;
        final coverUrl = profile['cover_url'] as String?;
        
        // Prefer full_name, fallback to username, then 'User'
        // Trim whitespace and check if it's not empty
        String newUsername;
        if (fullName != null && fullName.trim().isNotEmpty) {
          newUsername = fullName.trim();
        } else if (username != null && username.isNotEmpty) {
          newUsername = username;
        } else {
          newUsername = 'User';
        }
        
        print('HomePage: Loaded name: $newUsername (full_name: "$fullName", username: "$username")');
        print('HomePage: Avatar URL: $avatarUrl (isNull: ${avatarUrl == null}, isEmpty: ${avatarUrl?.isEmpty ?? true})');
        print('HomePage: Cover URL: $coverUrl (isNull: ${coverUrl == null}, isEmpty: ${coverUrl?.isEmpty ?? true})');
        
        setState(() {
          _username = newUsername;
          _avatarUrl = avatarUrl;
          _coverImageUrl = coverUrl;
          
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
        
        // Load notifications count
        await _loadNotificationsCount();
      } else {
        print('HomePage: Profile is null - profile may not exist in database');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile not found. Please contact support.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('HomePage: Error loading profile: $e');
      print('HomePage: Error stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    await Future.wait([
      _loadAllData(),
      _loadNotificationsCount(),
      _loadStreak(),
      _loadMetrics(),
    ]);
  }

  /// Load today's metrics from Supabase
  Future<void> _loadMetrics() async {
    try {
      final todayMetrics = await _metricsRepo.getTodayMetrics();
      
      if (todayMetrics != null && mounted) {
        setState(() {
          _currentSteps = (todayMetrics['steps'] as num?)?.toInt() ?? 0;
          _currentCalories = ((todayMetrics['calories_burned'] as num?)?.toDouble() ?? 0.0).toInt();
          _currentWater = (todayMetrics['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
        });
      }

      // Also load weekly data for charts
      await _loadWeeklyMetrics();
    } catch (e) {
      print('Error loading metrics: $e');
    }
  }

  /// Load weekly metrics for charts
  Future<void> _loadWeeklyMetrics() async {
    try {
      final weeklyMetrics = await _metricsRepo.getWeeklyMetrics();
      
      if (mounted) {
        setState(() {
          _stepsWeeklyData.clear();
          _caloriesWeeklyData.clear();
          _waterWeeklyData.clear();

          // Fill arrays with 7 days of data
          final today = DateTime.now();
          for (int i = 6; i >= 0; i--) {
            final date = today.subtract(Duration(days: i));
            final dateString = date.toIso8601String().split('T')[0];
            
            final dayMetrics = weeklyMetrics.firstWhere(
              (m) => (m['date'] as String?) == dateString,
              orElse: () => <String, dynamic>{},
            );

            _stepsWeeklyData.add((dayMetrics['steps'] as num?)?.toDouble() ?? 0.0);
            _caloriesWeeklyData.add((dayMetrics['calories_burned'] as num?)?.toDouble() ?? 0.0);
            _waterWeeklyData.add((dayMetrics['water_intake_liters'] as num?)?.toDouble() ?? 0.0);
          }
        });
      }
    } catch (e) {
      print('Error loading weekly metrics: $e');
    }
  }

  /// Start syncing metrics from health service to Supabase
  void _startMetricsSync() {
    // Sync metrics every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        // Get current metrics from health service
        final steps = await _healthService.getTodaySteps();
        final calories = await _healthService.getTodayCalories();
        final distance = await _healthService.getTodayDistance();

        // Update Supabase
        await _metricsRepo.updateTodayMetrics(
          steps: steps,
          caloriesBurned: calories,
          distanceKm: distance,
        );

        // Update UI if values changed
        if (mounted) {
          setState(() {
            _currentSteps = steps;
            _currentCalories = calories.toInt();
          });
        }
      } catch (e) {
        print('Error syncing metrics: $e');
      }
    });
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
                  key: ValueKey('${_username}_${_avatarUrl}_${_coverImageUrl}'), // Force rebuild when data changes
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
