import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/core/auth/auth_deep_link.dart';
import 'package:cotrainr/core/auth/auth_error_mapper.dart';
import 'package:cotrainr/pages/auth/login_page.dart';
import 'package:cotrainr/pages/auth/reset_password_page.dart';
import 'package:cotrainr/widgets/auth/auth_ui.dart';
import 'package:cotrainr/widgets/auth/forgot_password_sheet.dart';

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF9F1A),
        brightness: brightness,
      ),
    );

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.dark,
}) {
  return MaterialApp(
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode:
        brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration: Duration.zero,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        platformBrightness: brightness,
        disableAnimations: true,
      ),
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForgotPasswordSheet', () {
    testWidgets('opens from Login and closes safely', (tester) async {
      await tester.pumpWidget(_wrap(const LoginPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects invalid email without submit', (tester) async {
      var submits = 0;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ForgotPasswordSheet(
              onSubmit: (_) async {
                submits++;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      expect(submits, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('trims whitespace before submit', (tester) async {
      String? received;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ForgotPasswordSheet(
              onSubmit: (email) async {
                received = email;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField),
        '  reset@cotrainr.com  ',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(received, 'reset@cotrainr.com');
      expect(find.text('Check your email'), findsOneWidget);
    });

    testWidgets('blocks duplicate taps while loading', (tester) async {
      var submits = 0;
      final gate = Completer<void>();
      final key = GlobalKey<ForgotPasswordSheetState>();
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ForgotPasswordSheet(
              key: key,
              onSubmit: (_) async {
                submits++;
                await gate.future;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'a@b.com');
      await tester.pump();

      // Fire first submit and let it enter the loading/await path.
      final first = key.currentState!.submit();
      await tester.pump();
      expect(key.currentState!.isLoading, isTrue);

      // Second submit must no-op while loading.
      await key.currentState!.submit();
      expect(submits, 1);

      gate.complete();
      await first;
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
    });

    testWidgets('shows neutral anti-enumeration success copy', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ForgotPasswordSheet(
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.textContaining("If an account exists for this email"),
        findsOneWidget,
      );
      expect(find.textContaining('Account found'), findsNothing);
      expect(find.textContaining("doesn't exist"), findsNothing);
      expect(find.textContaining('Google'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('maps network errors to safe copy', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ForgotPasswordSheet(
              onSubmit: (_) async {
                throw const SocketException('Failed host lookup');
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('AuthException'), findsNothing);
    });

    testWidgets('maps AuthException without leaking raw text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: ForgotPasswordSheet(
              onSubmit: (_) async {
                throw const AuthException(
                  'AuthApiException(message: User not found, statusCode: 400)',
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('AuthApiException'), findsNothing);
      expect(find.textContaining('User not found'), findsNothing);
    });

    testWidgets('light and dark themes render compact card', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: ForgotPasswordSheet(onSubmit: (_) async {}),
            ),
            brightness: brightness,
          ),
        );
        await tester.pump();
        expect(find.text('Reset password'), findsOneWidget);
        expect(find.byType(AuthPrimaryButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
        'dismiss during pending request does not crash on completion',
        (tester) async {
      final gate = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      showForgotPasswordSheet(
                        context,
                        onSubmit: (_) => gate.future,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      // Dismiss while request is still in flight (barrier tap).
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsNothing);

      // Complete after dismissal — must not touch dead context / setState.
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'lifecycle regression: submit success without _dependents crash',
        (tester) async {
      // Reproduces the old failure path (submit → dispose dialog tree)
      // without showGeneralDialog transitionBuilder + external controller.
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showForgotPasswordSheet(
                      context,
                      onSubmit: (_) async {},
                    ),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'ok@cotrainr.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard inset keeps CTA reachable', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewInsets: EdgeInsets.only(bottom: 280),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: ForgotPasswordSheet(onSubmit: (_) async {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Send reset link'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AuthErrorMapper password reset', () {
    test('never enumerates accounts', () {
      final msg = AuthErrorMapper.mapPasswordResetFailure(
        const AuthException('User not found'),
      );
      expect(msg.display.toLowerCase().contains('not found'), isFalse);
      expect(msg.display.toLowerCase().contains('google'), isFalse);
      expect(msg.display, 'Something went wrong. Please try again.');
    });

    test('network and rate-limit copy', () {
      expect(
        AuthErrorMapper.mapPasswordResetFailure(
          const SocketException('offline'),
        ).display,
        'Check your connection and try again.',
      );
      expect(
        AuthErrorMapper.mapPasswordResetFailure(
          Exception('rate limit exceeded 429'),
        ).display,
        'Too many requests. Please wait a moment and try again.',
      );
    });
  });

  group('Reset deep link + Set New Password', () {
    test('redirect constant is cotrainr://reset-password', () {
      expect(AuthDeepLink.resetPassword, 'cotrainr://reset-password');
      expect(
        File('lib/widgets/auth/forgot_password_sheet.dart')
            .readAsStringSync()
            .contains('AuthDeepLink.resetPassword'),
        isTrue,
      );
      expect(
        File('lib/pages/auth/login_page.dart')
            .readAsStringSync()
            .contains('showGeneralDialog'),
        isFalse,
      );
    });

    testWidgets('Set New Password shows invalid without recovery session',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ResetPasswordPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('This reset link is invalid or has expired.'),
        findsOneWidget,
      );
      expect(find.textContaining('AuthException'), findsNothing);
    });
  });
}
