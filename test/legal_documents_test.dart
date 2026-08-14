import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/legal/legal_document_meta.dart';
import 'package:cotrainr/legal/privacy_policy_content.dart';
import 'package:cotrainr/legal/terms_of_service_content.dart';
import 'package:cotrainr/pages/profile/settings/info_pages.dart';
import 'package:cotrainr/utils/launch_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Privacy Policy', () {
    test('content includes required major sections', () {
      final titles = PrivacyPolicyContent.sections.map((s) => s.title).toList();
      expect(titles, contains('Health, fitness and body information'));
      expect(titles, contains('Nutrition and meal information'));
      expect(titles, contains('Location information'));
      expect(
        titles,
        contains('Information shared with Trainers and Nutritionists'),
      );
      expect(titles, contains('Account deletion'));
      expect(titles, contains('Access, correction and data requests'));
      expect(PrivacyPolicyContent.sections.length, greaterThanOrEqualTo(20));
    });

    test('content stays truthful on deletion, export and defaults', () {
      final blob = PrivacyPolicyContent.sections
          .map((s) => '${s.title}\n${s.body}\n${s.callout ?? ''}')
          .join('\n');
      expect(blob, contains('support@cotrainr.com'));
      expect(blob, contains('Coming soon'));
      expect(blob, isNot(contains('Download My Data” export is available')));
      expect(blob, contains('opt-out'));
      expect(blob, contains('does not provide immediate automated'));
      expect(blob, isNot(contains('noreply@cotrainr.com')));
      expect(blob, contains(LegalDocumentMeta.decisionRequiredPrefix));
    });

    testWidgets('renders metadata, summary, TOC and support contact',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Your data. Your choices.'), findsOneWidget);
      expect(find.textContaining('2026-08-01'), findsWidgets);
      expect(find.text('AT A GLANCE'), findsOneWidget);
      expect(find.text('CONTENTS'), findsOneWidget);
      expect(find.text('noreply@cotrainr.com'), findsNothing);

      await tester.scrollUntilVisible(
        find.text(LaunchUtils.supportEmail),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(LaunchUtils.supportEmail), findsWidgets);
      expect(find.text('Back to top'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Health, fitness and body information').last,
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Health, fitness and body information'),
        findsWidgets,
      );
    });

    testWidgets('TOC navigates to provider sharing section', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyPage()),
      );
      await tester.pumpAndSettle();

      // Section 08 in PrivacyPolicyContent.
      final tocRow = find.byKey(const ValueKey('legal-toc-7'));
      await tester.ensureVisible(tocRow);
      await tester.tap(tocRow);
      await tester.pumpAndSettle();
      expect(find.textContaining('default to on'), findsWidgets);
    });

    testWidgets('light and dark themes build', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            themeMode: mode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: const PrivacyPolicyPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Privacy Policy'), findsWidgets);
      }
    });

    testWidgets('large text does not crash', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: const MaterialApp(home: PrivacyPolicyPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsWidgets);
    });
  });

  group('Terms of Service', () {
    test('content includes role, disclaimer and acceptable use', () {
      final titles = TermsOfServiceContent.sections.map((s) => s.title).toList();
      expect(titles, contains('Member accounts'));
      expect(titles, contains('Trainer accounts'));
      expect(titles, contains('Nutritionist accounts'));
      expect(titles, contains('Provider verification'));
      expect(titles, contains('No medical advice'));
      expect(titles, contains('Acceptable use'));
      expect(titles, contains('User-generated content'));
      expect(titles, contains('Account deletion'));
      expect(titles, contains('Governing law'));
    });

    test('payments and governing law are flagged, not invented', () {
      final blob = TermsOfServiceContent.sections
          .map((s) => '${s.title}\n${s.body}')
          .join('\n');
      expect(blob, contains('not currently active in the MVP'));
      expect(blob, contains(LegalDocumentMeta.decisionRequiredPrefix));
      expect(blob, contains('support@cotrainr.com'));
      expect(blob, isNot(contains('Stripe')));
      expect(blob, isNot(contains('noreply@cotrainr.com')));
      expect(blob, contains('CoCircle are not currently available'));
    });

    testWidgets('renders title, TOC and support contact', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServicePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.text('The rules for using Cotrainr.'), findsOneWidget);
      expect(find.text('CONTENTS'), findsOneWidget);
      expect(find.text('noreply@cotrainr.com'), findsNothing);
      await tester.scrollUntilVisible(
        find.text(LaunchUtils.supportEmail),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(LaunchUtils.supportEmail), findsWidgets);
    });

    testWidgets('light and dark themes build', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            themeMode: mode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: const TermsOfServicePage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Terms of Service'), findsWidgets);
      }
    });
  });

  group('Signup legal links', () {
    testWidgets('signup opens the same Privacy and Terms pages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TermsOfServicePage(),
                        ),
                      ),
                      child: const Text('Open Terms'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      ),
                      child: const Text('Open Privacy'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Terms'));
      await tester.pumpAndSettle();
      expect(find.text('The rules for using Cotrainr.'), findsOneWidget);
      expect(find.textContaining('2026-08-01'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Your data. Your choices.'), findsOneWidget);
      expect(find.textContaining('2026-08-01'), findsWidgets);
    });
  });
}
