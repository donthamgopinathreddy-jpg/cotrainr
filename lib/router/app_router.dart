import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pages/auth/login_page.dart';
import '../../pages/auth/signup_page.dart';
import '../../pages/splash_page.dart';
import '../../pages/home/home_shell_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final isLoggedIn = session != null;

    // Public routes that don't require auth
    final publicRoutes = ['/splash', '/auth/login', '/auth/signup'];
    final isPublicRoute = publicRoutes.contains(state.matchedLocation);

    // If not logged in and trying to access protected route
    if (!isLoggedIn && !isPublicRoute) {
      return '/auth/login';
    }

    // If logged in and trying to access auth routes
    if (isLoggedIn && isPublicRoute && state.matchedLocation != '/splash') {
      return '/home';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/auth/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/auth/signup',
      name: 'signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeShellPage(),
      routes: [
        GoRoute(
          path: 'discover',
          name: 'discover',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Discover Page')),
          ),
        ),
        GoRoute(
          path: 'quest',
          name: 'quest',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Quest Page')),
          ),
        ),
        GoRoute(
          path: 'cocircle',
          name: 'cocircle',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Cocircle Page')),
          ),
        ),
        GoRoute(
          path: 'profile',
          name: 'profile',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Profile Page')),
          ),
        ),
      ],
    ),
  ],
);

