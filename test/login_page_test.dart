import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/core/auth/auth_error_mapper.dart';
import 'package:cotrainr/pages/auth/login_page.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/auth/auth_ui.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: LoginPage()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test('Login uses direct email/password path, not identifier stack', () {
    final src = File('lib/pages/auth/login_page.dart').readAsStringSync();
    expect(src, contains('signInWithPassword'));
    expect(src, contains("email: _idOrEmail.text.trim().toLowerCase()"));
    expect(src, contains("context.go('/auth/continue')"));
    expect(src, isNot(contains('LoginWithIdentifierService')));
    expect(src, isNot(contains('LoginIdentifier')));
    expect(src, isNot(contains('rpc_resolve_login_identifier')));
    expect(src, isNot(contains('login-with-identifier')));
    expect(src, isNot(contains("go('/home')")));
    expect(src, contains("label: 'Email'"));
    expect(src, contains("hint: 'you@example.com'"));
    expect(src, isNot(contains('Email or User ID')));
    expect(src, isNot(contains('User ID or Email')));
    expect(src, contains('Forgot password?'));
    expect(src, contains('OAuthProvider.google'));
    expect(src, contains('Duration(seconds: 15)'));
    expect(src, contains('Duration(seconds: 3)'));
  });

  testWidgets('Login shows Email label and email-only validation',
      (tester) async {
    await _pumpLogin(tester);

    expect(find.text('Email'), findsWidgets);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Or continue with'), findsOneWidget);
    expect(find.text('Email or User ID'), findsNothing);
    expect(find.text('User ID or Email'), findsNothing);
    expect(find.text('Username'), findsNothing);
    expect(find.textContaining('User ID'), findsNothing);

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Min 6 chars'), findsOneWidget);
    expect(find.textContaining('AuthApiException'), findsNothing);
    expect(find.textContaining('statusCode'), findsNothing);
    expect(find.text('Remember me'), findsNothing);
    expect(find.byType(AuthPrimaryButton), findsWidgets);
    final cta = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(AuthPrimaryButton).first,
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((cta.decoration as BoxDecoration).gradient, CotrainrGradients.primary);
  });

  testWidgets('malformed email is rejected; valid email is accepted',
      (tester) async {
    await _pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.tap(fields.at(0));
    await tester.pump();
    await tester.enterText(fields.at(0), 'abc@');
    await tester.tap(fields.at(1));
    await tester.pump();
    await tester.enterText(fields.at(1), 'secret1');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your email.'), findsNothing);

    await tester.tap(fields.at(0));
    await tester.pump();
    await tester.enterText(fields.at(0), '  TEST@GMAIL.COM  ');
    await tester.tap(fields.at(1));
    await tester.pump();
    await tester.enterText(fields.at(1), '123');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(find.text('Enter your email.'), findsNothing);
    expect(find.text('Min 6 chars'), findsOneWidget);
  });

  testWidgets('User ID is not accepted as a login identifier', (tester) async {
    await _pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.tap(fields.at(0));
    await tester.pump();
    await tester.enterText(fields.at(0), '@gopi_26');
    await tester.tap(fields.at(1));
    await tester.pump();
    await tester.enterText(fields.at(1), 'secret1');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('mapped errors never include raw backend tokens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final msg = AuthErrorMapper.map(
                Exception(
                  'AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
                ),
              );
              return Text(msg.display);
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('AuthApiException'), findsNothing);
    expect(
      find.textContaining('Incorrect email or password'),
      findsOneWidget,
    );
    expect(find.textContaining('User ID'), findsNothing);
  });
}
