import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/pages/splash_page.dart';
import 'package:cotrainr/theme/design_tokens.dart';

void main() {
  testWidgets('CotrainrSplashScreen shows black scaffold and loader',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CotrainrSplashScreen(runStartupNavigation: false),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);
    expect(DesignTokens.accentOrange, const Color(0xFFFF8A00));
    expect(find.byType(CotrainrSplashScreen), findsOneWidget);
  });

  testWidgets('CotrainrSplashScreen fits a narrow Android screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CotrainrSplashScreen(runStartupNavigation: false),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
