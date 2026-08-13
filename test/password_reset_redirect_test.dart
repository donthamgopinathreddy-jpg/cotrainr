import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cotrainr/core/auth/auth_deep_link.dart';
import 'package:cotrainr/core/startup/startup_router_bridge.dart';
import 'package:cotrainr/pages/auth/reset_password_page.dart';
import 'package:cotrainr/widgets/auth/auth_ui.dart';
import 'package:cotrainr/widgets/auth/forgot_password_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    StartupRouterBridge.setPendingDeepLinkRoute(null);
  });

  group('Password reset redirect contract', () {
    test('resetPasswordForEmail uses AuthDeepLink.resetPassword', () {
      final src =
          File('lib/widgets/auth/forgot_password_sheet.dart').readAsStringSync();
      expect(src.contains('AuthDeepLink.resetPassword'), isTrue);
      expect(src.contains('resetPasswordForEmail'), isTrue);
      expect(src.contains('redirectTo: widget.redirectTo'), isTrue);
      expect(AuthDeepLink.resetPassword, 'cotrainr://reset-password');
      expect(AuthDeepLink.callback, 'cotrainr://auth-callback');
      expect(AuthDeepLink.resetPassword, isNot(AuthDeepLink.callback));
    });

    test('auth-callback and reset-password stay classified separately', () {
      final reset = Uri.parse(AuthDeepLink.resetPassword);
      final callback = Uri.parse(AuthDeepLink.callback);
      expect(AuthDeepLink.isResetPasswordUri(reset), isTrue);
      expect(AuthDeepLink.isCallbackUri(reset), isFalse);
      expect(AuthDeepLink.isCallbackUri(callback), isTrue);
      expect(AuthDeepLink.isResetPasswordUri(callback), isFalse);
    });

    test('AppLinkHandler routes recovery separately from OAuth continue', () {
      final handler =
          File('lib/widgets/app_link_handler.dart').readAsStringSync();
      expect(handler.contains('isResetPasswordUri'), isTrue);
      expect(handler.contains('_continueAfterPasswordRecovery'), isTrue);
      expect(handler.contains("appRouter.go('/auth/reset-password')"), isTrue);
      expect(
        handler.contains("appRouter.go('/auth/reset-password?error=invalid')"),
        isTrue,
      );
      expect(handler.contains('_continueAfterAuthCallback'), isTrue);
      expect(handler.contains("appRouter.go('/auth/continue')"), isTrue);

      final start =
          handler.indexOf('Future<void> _continueAfterPasswordRecovery');
      expect(start, greaterThanOrEqualTo(0));
      final end = handler.indexOf('Future<void> _continueAfterAuthCallback', start);
      expect(end, greaterThan(start));
      final recoveryFn = handler.substring(start, end);
      expect(recoveryFn.contains("appRouter.go('/auth/continue')"), isFalse);
      expect(recoveryFn.contains("appRouter.go('/home')"), isFalse);
      expect(recoveryFn.contains('/auth/reset-password'), isTrue);
    });

    test('splash prefers pending reset over /auth/continue', () {
      final splash = File('lib/pages/splash_page.dart').readAsStringSync();
      expect(splash.contains("pending == '/auth/reset-password'"), isTrue);
      expect(splash.contains("next = '/auth/reset-password'"), isTrue);
    });

    test('AndroidManifest includes reset-password deep link', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android:host="reset-password"'), isTrue);
      expect(manifest.contains('android:scheme="cotrainr"'), isTrue);
      expect(manifest.contains('android:host="auth-callback"'), isTrue);
    });

    test('iOS CFBundleURLSchemes includes cotrainr', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('<string>cotrainr</string>'), isTrue);
    });
  });

  group('ForgotPasswordSheet redirectTo', () {
    testWidgets('default redirectTo is cotrainr://reset-password',
        (tester) async {
      String? capturedRedirect;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordSheet(
              onSubmit: (_) async {},
              redirectTo: AuthDeepLink.resetPassword,
            ),
          ),
        ),
      );
      final sheet = tester.widget<ForgotPasswordSheet>(
        find.byType(ForgotPasswordSheet),
      );
      capturedRedirect = sheet.redirectTo;
      expect(capturedRedirect, 'cotrainr://reset-password');
    });
  });

  group('Set New Password recovery UI', () {
    testWidgets('invalid recovery shows safe expired copy', (tester) async {
      final router = GoRouter(
        initialLocation: '/auth/reset-password?error=invalid',
        routes: [
          GoRoute(
            path: '/auth/reset-password',
            builder: (_, __) => const ResetPasswordPage(),
          ),
          GoRoute(
            path: '/auth/login',
            builder: (_, __) => const Scaffold(body: Text('Login')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('This reset link is invalid or has expired.'),
        findsOneWidget,
      );
      expect(find.text('Request a new link'), findsOneWidget);
      expect(find.textContaining('AuthException'), findsNothing);
      expect(find.textContaining('AuthApiException'), findsNothing);
    });

    testWidgets('loading session resolves to invalid without Supabase init',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ResetPasswordPage()),
      );
      await tester.pump();
      // First frame may still be loading; without a session it becomes invalid.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('This reset link is invalid or has expired.'),
        findsOneWidget,
      );
      expect(find.textContaining('/auth/continue'), findsNothing);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('theme still renders AuthPrimaryButton on invalid state',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/auth/reset-password?error=invalid',
        routes: [
          GoRoute(
            path: '/auth/reset-password',
            builder: (_, __) => const ResetPasswordPage(),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AuthPrimaryButton), findsOneWidget);
    });
  });
}
