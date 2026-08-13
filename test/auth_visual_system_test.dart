import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/core/auth/signup_mode.dart';
import 'package:cotrainr/pages/auth/complete_profile_page.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/auth/auth_screen_background.dart';
import 'package:cotrainr/widgets/auth/auth_ui.dart';
import 'package:cotrainr/widgets/auth/onboarding_shell.dart';
import 'package:cotrainr/widgets/branding/cotrainr_loader.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthScreenBackground', () {
    testWidgets('hero variant renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthScreenBackground(
            intensity: AuthBackgroundIntensity.hero,
            child: Text('hero'),
          ),
        ),
      );
      expect(find.byType(AuthScreenBackground), findsOneWidget);
      expect(find.text('hero'), findsOneWidget);
    });

    testWidgets('onboarding variant renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthScreenBackground(
            intensity: AuthBackgroundIntensity.onboarding,
            child: Text('onboarding'),
          ),
        ),
      );
      expect(find.byType(AuthScreenBackground), findsOneWidget);
      expect(find.text('onboarding'), findsOneWidget);
    });

    testWidgets('success variant renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthScreenBackground.success(child: Text('success')),
        ),
      );
      expect(find.byType(AuthScreenBackground), findsOneWidget);
      expect(find.text('success'), findsOneWidget);
    });

    testWidgets('loader variant renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthScreenBackground(
            intensity: AuthBackgroundIntensity.loader,
            showEnergyMotif: false,
            child: Text('loader'),
          ),
        ),
      );
      expect(find.byType(AuthScreenBackground), findsOneWidget);
      expect(find.text('loader'), findsOneWidget);
    });
  });

  group('CotrainrLoader', () {
    testWidgets('compact loader shows copy', (tester) async {
      await tester.pumpWidget(
        _wrap(const CotrainrLoader.compact(message: 'Getting you ready…')),
      );
      expect(find.text('Getting you ready…'), findsOneWidget);
      expect(find.byType(LogoAssemblyMark), findsOneWidget);
    });

    testWidgets('inline loader has loading semantics', (tester) async {
      await tester.pumpWidget(_wrap(const CotrainrLoader.inline()));
      expect(find.bySemanticsLabel('Loading Cotrainr'), findsWidgets);
    });

    testWidgets('reduced motion keeps static mark', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CotrainrLoader.compact(message: 'Getting you ready…'),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(find.text('Getting you ready…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('fullscreen error handoff shows retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          CotrainrLoader.fullscreen(
            error: 'Couldn’t finish loading.',
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text('Couldn’t finish loading.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });
  });

  group('Onboarding shell', () {
    testWidgets('first step has no Back', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingBottomActions(
            step: 0,
            isLast: false,
            onNext: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.text('Back'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('later steps have bottom Back', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingBottomActions(
            step: 2,
            isLast: false,
            onNext: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('header has no numeric step counter', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OnboardingHeader(
            title: 'Create your account',
            subtitle: 'Start training',
            step: 0,
            totalSteps: 7,
          ),
        ),
      );
      expect(find.text('1/7'), findsNothing);
      expect(find.text('Step 1 of 7'), findsNothing);
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(OnboardingProgress), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('progress changes with step', (tester) async {
      await tester.pumpWidget(
        _wrap(const OnboardingProgress(step: 0, totalSteps: 7)),
      );
      expect(find.byType(OnboardingProgress), findsOneWidget);
      expect(
        find.bySemanticsLabel('Onboarding progress, step 1 of 7'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _wrap(const OnboardingProgress(step: 3, totalSteps: 7)),
      );
      expect(
        find.bySemanticsLabel('Onboarding progress, step 4 of 7'),
        findsOneWidget,
      );
    });

    testWidgets('last step shows Finish with equal Back', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingBottomActions(
            step: 6,
            isLast: true,
            onNext: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('Next and Finish use shared primary CTA, Back stays outlined',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingBottomActions(
            step: 1,
            isLast: false,
            onNext: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.byType(AuthPrimaryButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      final cta = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(AuthPrimaryButton),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect((cta.decoration as BoxDecoration).gradient, CotrainrGradients.primary);
    });

    testWidgets('last social step shows Finish', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingBottomActions(
            step: 6,
            isLast: true,
            onNext: () {},
            onBack: () {},
            finishLabel: 'Finish',
          ),
        ),
      );
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('gender selection works', (tester) async {
      var value = 'Male';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return AuthGenderSelector(
                value: value,
                onChanged: (v) => setState(() => value = v),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Female'));
      await tester.pump();
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });
  });

  group('Signup modes', () {
    test('email and social remain distinct shared modes', () {
      expect(SignupMode.email, isNot(SignupMode.social));
      expect(SignupMode.values, containsAll([SignupMode.email, SignupMode.social]));
    });

    test('complete-profile is a thin shared social wizard wrapper', () {
      expect(const CompleteProfilePage(), isA<StatelessWidget>());
    });
  });
}
