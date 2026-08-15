import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/profile/settings/info_pages.dart';
import 'package:cotrainr/pages/profile/settings_page.dart';
import 'package:cotrainr/utils/launch_utils.dart';

void main() {
  testWidgets('Settings Legal shows non-interactive App Version',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var termsTaps = 0;
    var privacyTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsLegalSection(
            appVersion: '1.0.0',
            onOpenTerms: () => termsTaps++,
            onOpenPrivacy: () => privacyTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text(LaunchUtils.noReplyEmail), findsNothing);
    expect(find.text(LaunchUtils.supportEmail), findsNothing);

    // No chevron on App Version: Terms/Privacy each keep one.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));

    await tester.tap(find.text('App Version'));
    await tester.pump();
    expect(find.byType(TermsOfServicePage), findsNothing);
    expect(find.byType(PrivacyPolicyPage), findsNothing);
    expect(termsTaps, 0);
    expect(privacyTaps, 0);

    await tester.tap(find.text('Terms of Service'));
    await tester.pump();
    expect(termsTaps, 1);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();
    expect(privacyTaps, 1);
  });

  testWidgets('Settings Legal Terms and Privacy navigate when hosted',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: SettingsLegalSection(
                appVersion: '1.2.3',
                onOpenTerms: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsOfServicePage(),
                    ),
                  );
                },
                onOpenPrivacy: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.text('The rules for using Cotrainr.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Your data. Your choices.'), findsOneWidget);
  });

  testWidgets('Settings Legal App Version works in light and dark',
      (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: mode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: SettingsLegalSection(
              appVersion: '1.0.0',
              onOpenTerms: () {},
              onOpenPrivacy: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    }
  });
}
