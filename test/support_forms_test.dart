import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/profile/settings/info_pages.dart';
import 'package:cotrainr/services/support_email_composer.dart';
import 'package:cotrainr/utils/launch_utils.dart';

void main() {
  const diagnostics = SupportDiagnostics(
    version: '1.0.0',
    buildNumber: '1',
    platform: 'Android',
    os: 'Android 14',
  );

  group('SupportEmailComposer', () {
    test('builds feedback subject and body', () {
      expect(
        SupportEmailComposer.feedbackSubject(type: FeedbackType.suggestion),
        'Cotrainr Feedback — Suggestion',
      );
      expect(
        SupportEmailComposer.feedbackSubject(
          type: FeedbackType.improvement,
          subject: 'Dark mode',
        ),
        'Cotrainr Feedback — Improvement — Dark mode',
      );

      final body = SupportEmailComposer.feedbackBody(
        type: FeedbackType.suggestion,
        message: '  Love the meals  ',
        diagnostics: diagnostics,
      );
      expect(body, contains('Feedback type: Suggestion'));
      expect(body, contains('Love the meals'));
      expect(body, contains('App version: 1.0.0'));
      expect(body, contains('Platform: Android'));
      expect(body, isNot(contains('noreply@')));
      expect(body, isNot(contains('access_token')));
      expect(body, isNot(contains('uuid')));
    });

    test('builds problem body with safe diagnostics only', () {
      final body = SupportEmailComposer.problemBody(
        problem: 'App crashed',
        context: 'Logging a meal',
        diagnostics: diagnostics,
      );
      expect(SupportEmailComposer.problemSubject, 'Cotrainr Problem Report');
      expect(body, contains('Problem:\nApp crashed'));
      expect(body, contains('What I was doing:\nLogging a meal'));
      expect(body, contains('App: Cotrainr 1.0.0 (1)'));
      expect(body, contains('Platform: Android'));
      expect(body, contains('OS: Android 14'));
      expect(body, isNot(contains('User ID')));
      expect(body, isNot(contains('refresh')));
      expect(body, isNot(contains('location')));

      final emptyContext = SupportEmailComposer.problemBody(
        problem: 'Bug',
        diagnostics: diagnostics,
      );
      expect(emptyContext, contains('Not provided'));
    });

    test('rejects whitespace-only text', () {
      expect(SupportEmailComposer.isNonEmptyText('   '), isFalse);
      expect(SupportEmailComposer.isNonEmptyText('ok'), isTrue);
    });
  });

  group('FeedbackPage', () {
    testWidgets('requires message and launches support email', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? sentTo;
      String? sentSubject;
      String? sentBody;
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackPage(
            diagnosticsLoader: () async => diagnostics,
            emailSender: (context, {required to, subject, body}) async {
              calls++;
              sentTo = to;
              sentSubject = subject;
              sentBody = body;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help us improve Cotrainr'), findsOneWidget);
      expect(find.text('Suggestion'), findsOneWidget);
      expect(find.textContaining(LaunchUtils.supportEmail), findsOneWidget);
      expect(find.text(LaunchUtils.noReplyEmail), findsNothing);

      // Disabled until message entered.
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      expect(calls, 0);

      await tester.enterText(find.byType(TextField).at(1), '   ');
      await tester.pump();
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      expect(calls, 0);

      await tester.tap(find.text('Improvement'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Theme');
      await tester.enterText(find.byType(TextField).at(1), 'Please polish dark mode');
      await tester.pump();
      await tester.tap(find.text('Send feedback'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(sentTo, LaunchUtils.supportEmail);
      expect(sentSubject, 'Cotrainr Feedback — Improvement — Theme');
      expect(sentBody, contains('Please polish dark mode'));
      expect(sentBody, contains('App version: 1.0.0'));
    });

    testWidgets('light and dark themes build', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            themeMode: mode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: FeedbackPage(
              diagnosticsLoader: () async => diagnostics,
              emailSender: (context, {required to, subject, body}) async => true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Feedback'), findsWidgets);
      }
    });
  });

  group('ReportProblemPage', () {
    testWidgets('simplified fields and safe diagnostics', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? sentTo;
      String? sentSubject;
      String? sentBody;
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReportProblemPage(
            diagnosticsLoader: () async => diagnostics,
            emailSender: (context, {required to, subject, body}) async {
              calls++;
              sentTo = to;
              sentSubject = subject;
              sentBody = body;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tell us what went wrong'), findsOneWidget);
      expect(find.text('Steps to reproduce'), findsNothing);
      expect(find.text('Expected behavior'), findsNothing);
      expect(find.text('Actual behavior'), findsNothing);
      expect(find.text(LaunchUtils.noReplyEmail), findsNothing);

      await tester.tap(find.text('Report problem'));
      await tester.pump();
      expect(calls, 0);

      await tester.enterText(find.byType(TextField).first, 'Crash on save');
      await tester.enterText(
        find.byType(TextField).at(1),
        'I was logging a meal',
      );
      await tester.pump();
      await tester.tap(find.text('Report problem'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(sentTo, LaunchUtils.supportEmail);
      expect(sentSubject, 'Cotrainr Problem Report');
      expect(sentBody, contains('Crash on save'));
      expect(sentBody, contains('I was logging a meal'));
      expect(sentBody, contains('App: Cotrainr 1.0.0 (1)'));
      expect(sentBody, isNot(contains('access_token')));
    });

    testWidgets('email launch failure does not claim success', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ReportProblemPage(
            diagnosticsLoader: () async => diagnostics,
            emailSender: (context, {required to, subject, body}) async {
              await LaunchUtils.showEmailLaunchFailure(context, email: to);
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Broken screen');
      await tester.pump();
      await tester.tap(find.text('Report problem'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't open your email app"), findsOneWidget);
      expect(find.text('Copy email'), findsOneWidget);
      expect(find.textContaining('Report sent'), findsNothing);
    });

    testWidgets('large text does not crash', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: MaterialApp(
            home: ReportProblemPage(
              diagnosticsLoader: () async => diagnostics,
              emailSender: (context, {required to, subject, body}) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Report a Problem'), findsWidgets);
    });
  });
}
