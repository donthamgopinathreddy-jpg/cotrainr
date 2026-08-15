import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/help/help_content.dart';
import 'package:cotrainr/pages/profile/settings/help_center_page.dart';
import 'package:cotrainr/pages/profile/settings/info_pages.dart';
import 'package:cotrainr/utils/launch_utils.dart';

void main() {
  group('HelpContent', () {
    test('search filters by question and keywords', () {
      final passwordHits = HelpContent.search('password');
      expect(passwordHits, isNotEmpty);
      expect(
        passwordHits.any((a) => a.question.contains('change my password')),
        isTrue,
      );

      final empty = HelpContent.search('   ');
      expect(empty, isEmpty);
    });

    test('does not present User ID as a login method', () {
      final blob = HelpContent.articles
          .map((a) => '${a.question}\n${a.answer}')
          .join('\n')
          .toLowerCase();
      expect(blob, contains('not used to sign in'));
      expect(blob, isNot(contains('sign in with your user id')));
      expect(blob, contains('not in the current mvp'));
    });

    test('deletion and export wording is truthful', () {
      final blob =
          HelpContent.articles.map((a) => '${a.question}\n${a.answer}').join('\n');
      expect(blob, contains('not available as an instant in-app action'));
      expect(blob, contains('Coming soon'));
      expect(blob, isNot(contains('Download My Data is available')));
      expect(blob, isNot(contains('immediately erased')));
    });

    test('has no fake live chat or phone support copy', () {
      final blob =
          HelpContent.articles.map((a) => '${a.question}\n${a.answer}').join('\n');
      expect(blob.toLowerCase(), isNot(contains('live chat')));
      expect(blob.toLowerCase(), isNot(contains('24/7')));
      expect(blob.toLowerCase(), isNot(contains('call support')));
      expect(blob, isNot(contains(LaunchUtils.noReplyEmail)));
      expect(blob, contains(LaunchUtils.supportEmail));
    });

    test('categories cover MVP areas', () {
      expect(HelpContent.categories.length, 6);
      expect(
        HelpContent.categories.map((c) => c.id),
        containsAll([
          HelpCategoryId.account,
          HelpCategoryId.health,
          HelpCategoryId.meals,
          HelpCategoryId.providers,
          HelpCategoryId.messaging,
          HelpCategoryId.privacy,
        ]),
      );
    });
  });

  group('HelpCenterPage', () {
    testWidgets('renders search, categories, popular FAQs, support email',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      expect(find.text('Help Center'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Quick help'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Popular questions'), findsOneWidget);
      expect(find.text('How do I change my password?'), findsOneWidget);
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text(LaunchUtils.supportEmail), findsOneWidget);
      expect(find.text(LaunchUtils.noReplyEmail), findsNothing);
      expect(find.textContaining('Live Chat'), findsNothing);
      expect(find.text('Visit Cotrainr website'), findsOneWidget);
    });

    testWidgets('search filters and shows no-results state', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'password');
      await tester.pumpAndSettle();
      expect(find.text('Search results'), findsOneWidget);
      expect(find.textContaining('password'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'xyzzy-no-match-12345');
      await tester.pumpAndSettle();
      expect(find.text('No help articles found'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('FAQ expands and deep link opens Change Password',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('How do I change my password?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Settings → Change Password'), findsOneWidget);
      expect(find.text('Change Password'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Change Password'));
      await tester.pumpAndSettle();
      expect(find.text('Change Password'), findsWidgets);
    });

    testWidgets('Privacy Policy deep link opens canonical page', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Where can I read the Privacy Policy?'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Where can I read the Privacy Policy?'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Open Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyPage), findsOneWidget);
      expect(find.text('Your data. Your choices.'), findsOneWidget);
    });

    testWidgets('light and dark themes build', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            themeMode: mode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: const HelpCenterPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Help Center'), findsWidgets);
      }
    });

    testWidgets('large text does not crash', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const MaterialApp(home: HelpCenterPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Help Center'), findsWidgets);
    });
  });
}
