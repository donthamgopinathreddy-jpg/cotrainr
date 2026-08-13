import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/core/auth/auth_error_mapper.dart';
import 'package:cotrainr/pages/auth/login_page.dart';

void main() {
  testWidgets('Login shows validation for empty fields without raw exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Min 6 chars'), findsOneWidget);
    expect(find.textContaining('AuthApiException'), findsNothing);
    expect(find.textContaining('statusCode'), findsNothing);
    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('User ID or Email'), findsNothing);
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
  });
}
