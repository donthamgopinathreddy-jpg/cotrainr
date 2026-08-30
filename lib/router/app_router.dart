import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/motion/motion.dart';
import '../theme/design_tokens.dart';
import '../config/feature_flags.dart';
import '../../pages/auth/login_page.dart';
import '../../pages/auth/signup_wizard_page.dart';
import '../../pages/auth/welcome_page.dart';
import '../../pages/auth/welcome_animation_page.dart';
import '../../pages/auth/permissions_page.dart';
import '../../pages/auth/reset_password_page.dart';
import '../../pages/auth/post_auth_continue_page.dart';
import '../../pages/auth/complete_profile_page.dart';
import '../../pages/auth/account_restricted_page.dart';
import '../core/startup/go_router_auth_refresh.dart';
import '../../pages/splash_page.dart';
import '../../pages/home/home_shell_page.dart';
import '../../pages/notifications/notification_page.dart';
import '../../pages/insights/insights_detail_page.dart';
import '../../pages/messaging/messaging_page.dart';
import '../../pages/messaging/chat_screen.dart';
import '../../pages/trainer/become_trainer_page.dart';
import '../../pages/trainer/trainer_dashboard_page.dart';
import '../../pages/trainer/create_client_page.dart';
import '../../pages/trainer/client_detail_page.dart';
import '../../pages/trainer/trainer_coach_notes_page.dart';
import '../../pages/trainer/verification_submission_page.dart';
import '../../pages/nutritionist/nutritionist_dashboard_page.dart';
import '../../pages/nutritionist/nutritionist_client_detail_page.dart';
import '../../pages/refer/refer_friend_page.dart';
import '../../pages/subscription/subscription_page.dart';
import '../../pages/video_sessions/video_sessions_page_v2.dart';
import '../../pages/video_sessions/session_detail_page.dart';
import '../../pages/meal_tracker/meal_tracker_page_v2.dart';
import '../../pages/coach_notes/coach_notes_page.dart';
import '../../pages/ai_planner/ai_planner_page.dart';
import '../../pages/nutrition_goal_planner/nutrition_goal_planner_page.dart';
import '../../pages/quest/quest_page.dart';
import '../../pages/bmi/bmi_details_screen.dart';
import '../../pages/client/my_trainers_page.dart';
import '../../pages/provider/provider_review_page.dart';
import '../../pages/profile/provider_professional_edit_page.dart';
import '../../pages/profile/provider_certifications_page.dart';
import '../../pages/profile/public_profile_readonly_page.dart';
import '../../pages/profile/settings/service_locations_page.dart';
import '../../pages/profile/cotrainr_pass_page.dart';
import '../../pages/profile/partner_center_application_page.dart';

/// Session-based redirect. Post-auth routing uses /auth/continue
/// (complete-profile / verification / home) — never blind /home.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  // Re-evaluates redirects on sign-in / sign-out / token invalidation so a
  // logged-out user leaves protected routes without any navigation action.
  refreshListenable: goRouterAuthRefresh,
  redirect: (BuildContext context, GoRouterState state) {
    goRouterAuthRefresh.bindAuthIfReady();
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final isLoggedIn = session != null;
    final location = state.matchedLocation;

    final publicRoutes = [
      '/splash',
      '/welcome',
      '/auth/login',
      '/auth/create-account',
      '/auth/permissions',
      '/auth/reset-password',
      '/auth/continue',
      '/auth/complete-profile',
      '/welcome-animation',
      '/invite',
    ];
    final isPublicRoute = publicRoutes.contains(location);

    // Splash owns the first auth decision — do not bounce away mid-startup.
    if (location == '/splash') {
      return null;
    }

    // Password recovery deep link must not be forced away.
    if (location == '/auth/reset-password') {
      return null;
    }

    // Post-auth resolver + social completion stay reachable while logged in.
    if (location == '/auth/continue' ||
        location == '/auth/complete-profile' ||
        location == '/auth/permissions') {
      if (!isLoggedIn) return '/welcome';
      return null;
    }

    if (!isLoggedIn && !isPublicRoute) {
      return '/welcome';
    }

    // Logged in on public auth routes → authoritative continue (not /home).
    if (isLoggedIn &&
        isPublicRoute &&
        location != '/welcome-animation' &&
        location != '/splash' &&
        location != '/auth/permissions' &&
        location != '/auth/reset-password' &&
        location != '/auth/continue' &&
        location != '/auth/complete-profile') {
      return '/auth/continue';
    }

    if (location.startsWith('/video') &&
        state.uri.queryParameters.containsKey('role')) {
      final cleanUri = state.uri.replace(queryParameters: {});
      return cleanUri.toString();
    }

    final path = state.uri.path;
    // OAuth custom-scheme returns must never become an unmatched Flutter route
    // (that produced the post-consent black screen). Treat as completion event.
    if (path == '/video/google-connected' ||
        path == '/google-connected' ||
        path.startsWith('/video/google-connected') ||
        path == '/video/session/google-connected' ||
        path.startsWith('/video/session/google-connected')) {
      final err = state.uri.queryParameters['error'] ??
          state.uri.queryParameters['google_error'];
      if (err != null && err.isNotEmpty) {
        return '/video?google-connected=1&google_error=${Uri.encodeComponent(err)}';
      }
      return '/video?google-connected=1';
    }
    if (path == '/video/zoom-connected' ||
        path.startsWith('/video/zoom-connected')) {
      return '/video';
    }
    // Reject non-UUID session detail ids (e.g. OAuth path fragments).
    final sessionMatch =
        RegExp(r'^/video/session/([^/]+)$').firstMatch(path);
    if (sessionMatch != null) {
      final id = sessionMatch.group(1) ?? '';
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id);
      if (!isUuid) return '/video';
    }
    if (path == '/video/create') {
      final clientId = state.uri.queryParameters['clientId'];
      return clientId != null
          ? '/video?openCreate=1&clientId=$clientId'
          : '/video?openCreate=1';
    }
    if (path == '/video/join') return '/video?openJoin=1';
    if (path.startsWith('/video/room/')) return '/video';

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const CotrainrSplashScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const WelcomePage(),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: Motion.standardPageTransition(
          slideOffset: const Offset(0, 0.02),
        ),
      ),
    ),
    GoRoute(
      path: '/auth/login',
      name: 'login',
      pageBuilder: (context, state) => _authFromWelcomePage(
        child: const LoginPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/auth/reset-password',
      name: 'resetPassword',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const ResetPasswordPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/auth/create-account',
      name: 'createAccount',
      pageBuilder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return _authFromWelcomePage(
          child: SignupWizardPage(initialReferralCode: code),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/invite',
      name: 'invite',
      redirect: (context, state) {
        final code = state.uri.queryParameters['code'];
        if (code != null && code.trim().isNotEmpty) {
          return '/auth/create-account?code=${Uri.encodeComponent(code.trim())}';
        }
        return '/auth/create-account';
      },
    ),
    GoRoute(
      path: '/auth/permissions',
      name: 'permissions',
      pageBuilder: (context, state) {
        final role = (state.extra as Map<String, dynamic>?)?['role'] ?? 'client';
        return _fadeSlidePage(
          child: PermissionsPage(userRole: role),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/auth/continue',
      name: 'postAuthContinue',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const PostAuthContinuePage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/auth/complete-profile',
      name: 'completeProfile',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const CompleteProfilePage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/account-restricted',
      name: 'accountRestricted',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const AccountRestrictedPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/welcome-animation',
      name: 'welcomeAnimation',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const WelcomeAnimationPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) {
        final tab =
            int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
        return _fadeSlidePage(
          child: HomeShellPage(
            key: ValueKey('home-shell-tab-$tab'),
            showWelcome: state.uri.queryParameters['showWelcome'] == 'true',
            initialTabIndex: tab,
          ),
          state: state,
          pageKey: ValueKey('home?tab=$tab'),
        );
      },
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
      path: '/coach-notes',
      name: 'coachNotes',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const CoachNotesPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/my-trainers',
      name: 'myTrainers',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const MyTrainersPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/my-nutritionists',
      name: 'myNutritionists',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const MyNutritionistsPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/ai-planner',
      name: 'aiPlanner',
      // Not part of the Android MVP: unreachable (including by deep link)
      // while the flag is off. Code/data intentionally retained.
      redirect: (context, state) {
        if (FeatureFlags.enableAiPlanner) return null;
        FeatureFlags.logBlockedOnce(
          'ai-planner',
          'AI Planner route blocked (enableAiPlanner=false)',
        );
        return '/home';
      },
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const AiPlannerPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/nutrition-goals',
      name: 'nutritionGoals',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const NutritionGoalPlannerPage(),
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
      path: '/profile/professional',
      name: 'providerProfessional',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const ProviderProfessionalEditPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/profile/certifications',
      name: 'providerCertifications',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const ProviderCertificationsPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/profile/service-locations',
      name: 'providerServiceLocations',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const ServiceLocationsPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/profile/cotrainr-pass',
      name: 'cotrainrPass',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const CotrainrPassPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/profile/partner-application',
      name: 'partnerApplication',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const PartnerCenterApplicationPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/providers/:providerId',
      name: 'publicProviderProfile',
      pageBuilder: (context, state) {
        final id = state.pathParameters['providerId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        return _fadeSlidePage(
          child: PublicProfileReadonlyPage(
            userId: id,
            titleFallback: extra?['titleFallback'] as String?,
            providerType: extra?['providerType'] as String?,
          ),
          state: state,
        );
      },
      routes: [
        GoRoute(
          path: 'review',
          name: 'providerReview',
          pageBuilder: (context, state) {
            final id = state.pathParameters['providerId'] ?? '';
            final extra = state.extra as Map<String, dynamic>?;
            return _fadeSlidePage(
              child: ProviderReviewPage(
                providerId: id,
                titleFallback: extra?['titleFallback'] as String?,
                providerType: extra?['providerType'] as String?,
                avatarUrl: extra?['avatarUrl'] as String?,
              ),
              state: state,
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/trainer/dashboard',
      name: 'trainerDashboard',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const TrainerDashboardPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/trainer/notes',
      name: 'trainerCoachNotes',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const TrainerCoachNotesPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/nutritionist/dashboard',
      name: 'nutritionistDashboard',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const NutritionistDashboardPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/subscription',
      name: 'subscription',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const SubscriptionPage(),
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
        child: VideoSessionsPageV2(uri: state.uri),
        state: state,
      ),
    ),
    GoRoute(
      path: '/video/session/:id',
      name: 'sessionDetail',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final action = state.uri.queryParameters['action'];
        return _fadeSlidePage(
          child: SessionDetailPage(
            sessionId: id,
            initialAction: action,
          ),
          state: state,
        );
      },
    ),
    // Legacy /video/create, /video/join, /video/room/* redirect in redirect callback above
    GoRoute(
      path: '/bmi',
      name: 'bmi',
      pageBuilder: (context, state) {
        final args = state.extra as BmiDetailsArgs?;
        return _fadeSlidePage(
          child: BmiDetailsScreen(
            args: args ?? const BmiDetailsArgs(bmi: 0, bmiStatus: ''),
          ),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/quest',
      name: 'quest',
      redirect: (context, state) =>
          FeatureFlags.enableQuest ? null : '/home',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const QuestPage(),
        state: state,
      ),
    ),
    GoRoute(
      path: '/verification',
      name: 'verification',
      pageBuilder: (context, state) => _fadeSlidePage(
        child: const VerificationSubmissionPage(),
        state: state,
      ),
    ),
    // Standardized client routes
    GoRoute(
      path: '/clients/:id',
      name: 'clientDetail',
      pageBuilder: (context, state) {
        final clientId = state.pathParameters['id'] ?? '';
        return _fadeSlidePage(
          child: ClientDetailPage(
            client: state.extra as ClientItem?,
            clientId: clientId,
          ),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/nutritionist/clients/:id',
      name: 'nutritionistClientDetail',
      pageBuilder: (context, state) {
        final clientId = state.pathParameters['id'] ?? '';
        return _fadeSlidePage(
          child: NutritionistClientDetailPage(
            client: state.extra as ClientItem?,
            clientId: clientId,
          ),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/messaging/chat/:conversationId',
      name: 'chatScreen',
      pageBuilder: (context, state) {
        final id = state.pathParameters['conversationId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        return _fadeSlidePage(
          child: ChatScreen(
            conversationId: id,
            userName: extra?['userName'] ?? 'User',
            avatarGradient: extra?['avatarGradient'] as LinearGradient? ?? DesignTokens.primaryGradient,
            isOnline: extra?['isOnline'] ?? false,
            avatarUrl: extra?['avatarUrl'],
          ),
          state: state,
        );
      },
    ),
  ],
);

/// Welcome (orange) → Login/Register (black): fade + light horizontal slide.
CustomTransitionPage<void> _authFromWelcomePage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: Motion.standardPageTransition(
      slideOffset: const Offset(0, 0.02),
    ),
  );
}

/// Standard page transition (smooth fade + subtle slide with scale)
CustomTransitionPage<void> _fadeSlidePage({
  required Widget child,
  required GoRouterState state,
  LocalKey? pageKey,
}) {
  return CustomTransitionPage<void>(
    key: pageKey ?? state.pageKey,
    child: child,
    transitionDuration: Motion.pageTransitionDuration,
    reverseTransitionDuration: Motion.pageTransitionReverseDuration,
    transitionsBuilder: Motion.standardPageTransition(),
    // Enable smooth transitions
    maintainState: true,
    fullscreenDialog: false,
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





