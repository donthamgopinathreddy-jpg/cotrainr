import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cotrainr/core/startup/startup_router_bridge.dart';
import 'package:cotrainr/core/startup/startup_state.dart';
import 'package:cotrainr/pages/splash_page.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/startup/startup_status_panel.dart';

void main() {
  testWidgets('CotrainrSplashScreen shows black scaffold', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CotrainrSplashScreen(runStartupNavigation: false),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);
    expect(DesignTokens.accentOrange, const Color(0xFFFF8A00));
    expect(find.byType(CotrainrSplashScreen), findsOneWidget);
  });

  testWidgets('StartupStatusPanel shows retry', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: StartupStatusPanel(
            title: 'You’re offline',
            body: 'Connect to the internet to finish setting up Cotrainr.',
            onRetry: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    expect(tapped, isTrue);
  });

  test('router bridge mirrors authenticated destination', () {
    StartupRouterBridge.update(
      const StartupState(
        phase: StartupPhase.authenticated,
        role: 'trainer',
        destination: '/verification',
        onboardingComplete: false,
      ),
    );
    expect(StartupRouterBridge.state.destination, '/verification');
    expect(StartupRouterBridge.state.onboardingComplete, isFalse);

    StartupRouterBridge.update(StartupState.initial);
  });

  testWidgets('reset-password route name is registered in a mini router',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/auth/reset-password',
      routes: [
        GoRoute(
          path: '/auth/reset-password',
          builder: (_, __) => const Scaffold(body: Text('reset')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('reset'), findsOneWidget);
  });
}
