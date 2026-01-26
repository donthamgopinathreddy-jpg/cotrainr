import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/motion/motion.dart';
import '../../pages/auth/login_page.dart';
import '../../pages/auth/signup_wizard_page.dart';
import '../../pages/auth/welcome_page.dart';
import '../../pages/home/home_shell_page.dart';
import '../../pages/notifications/notification_page.dart';
import '../../pages/insights/insights_detail_page.dart';
import '../../pages/messaging/messaging_page.dart';
import '../../pages/trainer/become_trainer_page.dart';
import '../../pages/refer/refer_friend_page.dart';
import '../../pages/video_sessions/video_sessions_page.dart';
import '../../pages/video_sessions/create_meeting_page.dart';
import '../../pages/video_sessions/join_meeting_page.dart';
import '../../pages/video_sessions/meeting_room_page.dart';
import '../../pages/meal_tracker/meal_tracker_page_v2.dart';
import '../../pages/quest/quest_page.dart';
import '../../models/video_session_models.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  redirect: (BuildContext context, GoRouterState state) {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final isLoggedIn = session != null;

    // Public routes that don't require auth
    final publicRoutes = ['/welcome', '/auth/login', '/auth/create-account'];
    final isPublicRoute = publicRoutes.contains(state.matchedLocation);

    // If not logged in and trying to access protected route
    if (!isLoggedIn && !isPublicRoute) {
      return '/welcome';
    }

    // If logged in and trying to access auth routes, redirect to home
    if (isLoggedIn && isPublicRoute) {
      return '/home';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const WelcomePage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/auth/login',
      name: 'login',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const LoginPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/auth/create-account',
      name: 'createAccount',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const SignupWizardPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const HomeShellPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const NotificationPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/messaging',
      name: 'messaging',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const MessagingPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/meal-tracker',
      name: 'mealTracker',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const MealTrackerPageV2(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/insights/steps',
      name: 'insightsSteps',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: InsightsDetailPage(
          args: (state.extra as InsightArgs?) ??
              InsightArgs(MetricType.steps, const [6, 7, 8, 7, 9, 8, 7],
                  goal: 10000),
        ),
        state: state,
      ),
    ),
    GoRoute(
      path: '/insights/water',
      name: 'insightsWater',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: InsightsDetailPage(
          args: (state.extra as InsightArgs?) ??
              InsightArgs(MetricType.water, const [1.2, 1.6, 1.4, 1.8, 1.5, 1.7, 1.6],
                  goal: 2.5),
        ),
        state: state,
      ),
    ),
    GoRoute(
      path: '/insights/calories',
      name: 'insightsCalories',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: InsightsDetailPage(
          args: (state.extra as InsightArgs?) ??
              InsightArgs(MetricType.calories, const [1800, 2000, 1900, 2100, 1700, 1950, 1850]),
        ),
        state: state,
      ),
    ),
    GoRoute(
      path: '/insights/distance',
      name: 'insightsDistance',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: InsightsDetailPage(
          args: (state.extra as InsightArgs?) ??
              InsightArgs(MetricType.distance, const [3.8, 4.2, 4.0, 4.5, 4.6, 4.1, 4.4]),
        ),
        state: state,
      ),
    ),
    GoRoute(
      path: '/trainer/become',
      name: 'becomeTrainer',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const BecomeTrainerPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/refer',
      name: 'referFriend',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const ReferFriendPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/video',
      name: 'videoSessions',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: VideoSessionsPage(
          role: state.uri.queryParameters['role'] == 'trainer'
              ? Role.trainer
              : state.uri.queryParameters['role'] == 'nutritionist'
                  ? Role.nutritionist
                  : Role.client,
        ),
        state: state,
      ),
    ),
    GoRoute(
      path: '/video/create',
      name: 'createMeeting',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: CreateMeetingPage(
          userRole: state.uri.queryParameters['role'] == 'trainer'
              ? Role.trainer
              : state.uri.queryParameters['role'] == 'nutritionist'
                  ? Role.nutritionist
                  : Role.client,
        ),
        state: state,
      ),
    ),
    GoRoute(
      path: '/video/join',
      name: 'joinMeeting',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const JoinMeetingPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/video/room/:meetingId',
      name: 'meetingRoom',
      pageBuilder: (context, state) {
        final meetingId = state.pathParameters['meetingId'] ?? '';
        return _fadeSlidePage(
          child: MeetingRoomPage(meetingId: meetingId),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/quest',
      name: 'quest',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const QuestPage(),
        state: state,
      ),
    ),
  ],
);

/// Standard page transition (fade + slight slide)
CustomTransitionPage<void> _fadeSlidePage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.pageTransitionDuration,
    reverseTransitionDuration: Motion.pageTransitionReverseDuration,
    transitionsBuilder: Motion.standardPageTransition(),
  );
}

/// Modal page transition (slide up + fade, for modals and detail pages)
/// Use this for modal-style pages like bottom sheets, detail views, etc.
// ignore: unused_element
CustomTransitionPage<void> _modalPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.modalDuration,
    reverseTransitionDuration: Motion.pageTransitionReverseDuration,
    transitionsBuilder: Motion.modalSlideUpTransition(),
  );
}





