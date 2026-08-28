import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/legal/legal_document_meta.dart';
import 'package:cotrainr/pages/profile/settings/info_pages.dart';
import 'package:cotrainr/utils/launch_utils.dart';

void main() {
  testWidgets('Privacy Policy uses support contact, not noreply',
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
    expect(find.textContaining(LegalDocumentMeta.version), findsWidgets);
    expect(find.text('noreply@cotrainr.com'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(LaunchUtils.supportEmail),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(LaunchUtils.supportEmail), findsWidgets);
  });

  testWidgets('Terms uses support contact, not noreply', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: TermsOfServicePage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.text('noreply@cotrainr.com'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(LaunchUtils.supportEmail),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(LaunchUtils.supportEmail), findsWidgets);
  });
}
