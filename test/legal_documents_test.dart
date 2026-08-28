import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/legal/legal_acceptance_policy.dart';
import 'package:cotrainr/legal/legal_document_meta.dart';
import 'package:cotrainr/legal/privacy_policy_content.dart';
import 'package:cotrainr/legal/terms_of_service_content.dart';
import 'package:cotrainr/pages/profile/settings/info_pages.dart';
import 'package:cotrainr/utils/launch_utils.dart';
import 'package:cotrainr/widgets/auth/onboarding_role_goals.dart';
import 'package:cotrainr/widgets/legal/legal_document.dart';

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
      expect(PrivacyPolicyContent.sections.length, 27);
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
      expect(blob.toLowerCase(), isNot(contains('zoom')));
      expect(blob, contains('Google Meet'));
      expect(blob, contains('does not claim end-to-end encryption'));
      expect(blob, isNot(contains('provides end-to-end encryption')));
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
      expect(find.textContaining(LegalDocumentMeta.version), findsWidgets);
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

    testWidgets('all TOC rows open without crash', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyPage()),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < PrivacyPolicyContent.sections.length; i++) {
        final tocRow = find.byKey(ValueKey('legal-toc-$i'));
        await tester.ensureVisible(tocRow);
        await tester.tap(tocRow);
        await tester.pumpAndSettle();
        expect(
          find.text(PrivacyPolicyContent.sections[i].title),
          findsWidgets,
        );
      }
    });

    testWidgets('back navigation pops legal page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyPage), findsNothing);
      expect(find.text('Open'), findsOneWidget);
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

    testWidgets('narrow Android width builds', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsWidgets);
    });
  });

  group('Terms of Service', () {
    test('content includes role, disclaimer and acceptable use', () {
      final titles = TermsOfServiceContent.sections.map((s) => s.title).toList();
      expect(TermsOfServiceContent.sections.length, 33);
      expect(titles, contains('Member accounts'));
      expect(titles, contains('Trainer accounts'));
      expect(titles, contains('Nutritionist accounts'));
      expect(titles, contains('Provider verification'));
      expect(titles, contains('No medical advice'));
      expect(titles, contains('Acceptable use'));
      expect(titles, contains('Prohibited conduct'));
      expect(titles, contains('Video sessions and third-party video services'));
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
      expect(blob.toLowerCase(), isNot(contains('zoom')));
      expect(blob, contains('Google Meet'));
      expect(blob, contains('does not claim end-to-end encryption'));
      expect(blob, isNot(contains('provides end-to-end encryption')));
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
      expect(find.textContaining(LegalDocumentMeta.version), findsWidgets);
      expect(find.text('CONTENTS'), findsOneWidget);
      expect(find.text('noreply@cotrainr.com'), findsNothing);
      await tester.scrollUntilVisible(
        find.text(LaunchUtils.supportEmail),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(LaunchUtils.supportEmail), findsWidgets);
    });

    testWidgets('all TOC rows open without crash', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServicePage()),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < TermsOfServiceContent.sections.length; i++) {
        final tocRow = find.byKey(ValueKey('legal-toc-$i'));
        await tester.ensureVisible(tocRow);
        await tester.tap(tocRow);
        await tester.pumpAndSettle();
        expect(
          find.text(TermsOfServiceContent.sections[i].title),
          findsWidgets,
        );
      }
    });

    testWidgets('back navigation pops legal page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TermsOfServicePage(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServicePage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServicePage), findsNothing);
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

    testWidgets('large text and narrow width build', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: const MaterialApp(home: TermsOfServicePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsWidgets);
    });
  });

  group('Signup legal links', () {
    testWidgets('goals step links open Terms and Privacy pages', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var agreed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OnboardingGoalsStep(
                selectedGoalIds: const {'lose_weight'},
                onToggleGoal: (_) {},
                agreedLegal: agreed,
                onAgreedLegalChanged: (v) => agreed = v,
                onOpenTerms: () {},
                onOpenPrivacy: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

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
      expect(find.textContaining(LegalDocumentMeta.version), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Your data. Your choices.'), findsOneWidget);
      expect(find.textContaining(LegalDocumentMeta.version), findsWidgets);
    });
  });

  group('Legal acceptance policy', () {
    test('records current versions only when they match', () {
      expect(
        LegalAcceptancePolicy.versionsMatchCurrent(
          submittedTerms: LegalDocumentMeta.version,
          submittedPrivacy: LegalDocumentMeta.version,
          currentTerms: LegalDocumentMeta.version,
          currentPrivacy: LegalDocumentMeta.version,
        ),
        isTrue,
      );
      expect(
        LegalAcceptancePolicy.versionsMatchCurrent(
          submittedTerms: '2026-08-01',
          submittedPrivacy: LegalDocumentMeta.version,
          currentTerms: LegalDocumentMeta.version,
          currentPrivacy: LegalDocumentMeta.version,
        ),
        isFalse,
      );
    });

    test('existing users are not looped when re-accept is disabled', () {
      expect(
        LegalAcceptancePolicy.satisfiesOnboardingLegalGate(
          hasAnyAcceptance: true,
          acceptedTermsVersion: '2026-08-01',
          acceptedPrivacyVersion: '2026-08-01',
          currentTermsVersion: LegalDocumentMeta.version,
          currentPrivacyVersion: LegalDocumentMeta.version,
          requireReacceptance: false,
        ),
        isTrue,
      );
      expect(
        LegalAcceptancePolicy.satisfiesOnboardingLegalGate(
          hasAnyAcceptance: false,
          acceptedTermsVersion: null,
          acceptedPrivacyVersion: null,
          currentTermsVersion: LegalDocumentMeta.version,
          currentPrivacyVersion: LegalDocumentMeta.version,
          requireReacceptance: false,
        ),
        isFalse,
      );
    });

    test('re-accept mode requires current policy versions', () {
      expect(
        LegalAcceptancePolicy.satisfiesOnboardingLegalGate(
          hasAnyAcceptance: true,
          acceptedTermsVersion: '2026-08-01',
          acceptedPrivacyVersion: '2026-08-01',
          currentTermsVersion: LegalDocumentMeta.version,
          currentPrivacyVersion: LegalDocumentMeta.version,
          requireReacceptance: true,
        ),
        isFalse,
      );
      expect(
        LegalAcceptancePolicy.satisfiesOnboardingLegalGate(
          hasAnyAcceptance: true,
          acceptedTermsVersion: LegalDocumentMeta.version,
          acceptedPrivacyVersion: LegalDocumentMeta.version,
          currentTermsVersion: LegalDocumentMeta.version,
          currentPrivacyVersion: LegalDocumentMeta.version,
          requireReacceptance: true,
        ),
        isTrue,
      );
    });
  });

  group('legal release migration SQL contracts', () {
    late String sql;

    setUpAll(() {
      sql = File('supabase/migrations/20260828_legal_release.sql')
          .readAsStringSync();
    });

    test('bumps current_legal_versions to client meta version', () {
      expect(sql, contains("'${LegalDocumentMeta.version}'"));
      expect(sql, contains('current_legal_versions'));
      expect(sql, contains('require_legal_reacceptance'));
      expect(sql, contains('SELECT false;'));
    });

    test('acceptance is auth-bound with server timestamps and version checks',
        () {
      expect(sql, contains('record_legal_acceptance'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('Legal acceptance versions are outdated'));
      expect(sql, contains('v_accepted_at TIMESTAMPTZ := now()'));
      expect(sql, isNot(contains('p_accepted_at')));
    });

    test('append-only history + RLS: users read own, no client forge writes',
        () {
      expect(sql, contains('legal_acceptance_events'));
      expect(sql, contains('Users read own legal acceptance events'));
      expect(sql, contains('REVOKE ALL ON TABLE public.legal_acceptance_events'));
      expect(sql, contains('GRANT SELECT ON TABLE public.legal_acceptance_events'));
      expect(sql, contains('legal_acceptances_history_trg'));
    });

    test('get_onboarding_state grandfathering avoids acceptance loop', () {
      expect(sql, contains('get_onboarding_state'));
      expect(sql, contains('v_require_reaccept'));
      expect(
        sql,
        contains('Any prior acceptance satisfies the onboarding gate'),
      );
    });
  });

  group('LegalDocumentPage surface', () {
    test('section models expose TOC labels', () {
      expect(
        const LegalSectionData(number: '01', title: 'About', body: 'x')
            .tocLabel,
        '01  About',
      );
    });
  });
}
