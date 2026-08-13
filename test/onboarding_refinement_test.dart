import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/core/auth/signup_error_mapper.dart';
import 'package:cotrainr/core/auth/username_availability.dart';
import 'package:cotrainr/models/fitness_goal_taxonomy.dart';
import 'package:cotrainr/models/onboarding_specialty_options.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/auth/auth_ui.dart';
import 'package:cotrainr/widgets/auth/onboarding_role_goals.dart';
import 'package:cotrainr/widgets/auth/onboarding_shell.dart';
import 'package:cotrainr/widgets/auth/onboarding_success.dart';
import 'package:cotrainr/widgets/branding/cotrainr_loader.dart';

Widget _wrap(Widget child, {bool reduceMotion = false, Size size = const Size(390, 844)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsernameAvailability', () {
    test('empty', () {
      expect(
        UsernameAvailability.statusFor(raw: '', remote: null),
        UsernameAvailabilityStatus.empty,
      );
      expect(UsernameAvailability.helperText(UsernameAvailabilityStatus.empty), isNull);
    });

    test('too short / invalid chars', () {
      expect(UsernameAvailability.isValidFormat('ab'), isFalse);
      expect(UsernameAvailability.isValidFormat('bad-id'), isFalse);
      expect(
        UsernameAvailability.statusFor(raw: 'ab', remote: null),
        UsernameAvailabilityStatus.invalid,
      );
      expect(
        UsernameAvailability.helperText(UsernameAvailabilityStatus.invalid),
        'Use 3–20 letters, numbers or underscores.',
      );
    });

    test('normalize lowercase, uppercase, leading @', () {
      expect(UsernameAvailability.normalize('  GOPI_26 '), 'GOPI_26');
      expect(UsernameAvailability.normalize('@gopi_26'), 'gopi_26');
      expect(UsernameAvailability.isValidFormat('GOPI_26'), isTrue);
      expect(UsernameAvailability.isValidFormat('gopi_26'), isTrue);
    });

    test('checking / available / taken helpers', () {
      expect(
        UsernameAvailability.helperText(UsernameAvailabilityStatus.checking),
        'Checking User ID…',
      );
      expect(
        UsernameAvailability.helperText(UsernameAvailabilityStatus.available),
        '✓ User ID available',
      );
      expect(
        UsernameAvailability.helperText(UsernameAvailabilityStatus.taken),
        'That User ID is already taken.',
      );
    });

    test('RPC failure never becomes available', () {
      expect(UsernameAvailability.fromRpc(null), UsernameAvailabilityStatus.error);
      expect(UsernameAvailability.fromRpc('nope'), UsernameAvailabilityStatus.error);
      expect(UsernameAvailability.fromRpc(true), UsernameAvailabilityStatus.available);
      expect(UsernameAvailability.fromRpc(false), UsernameAvailabilityStatus.taken);
      expect(
        UsernameAvailability.canAdvance(UsernameAvailabilityStatus.error),
        isFalse,
      );
      expect(
        UsernameAvailability.canAdvance(UsernameAvailabilityStatus.checking),
        isFalse,
      );
    });
  });

  group('Email duplicate mapping', () {
    test('maps existing-account without raw backend text', () {
      final mapped = SignupErrorMapper.map(
        Exception('AuthApiException user already registered statusCode 400'),
      );
      expect(mapped, SignupErrorMapper.emailConflict);
      expect(mapped.display.contains('AuthApiException'), isFalse);
      expect(mapped.display.contains('statusCode'), isFalse);
      expect(mapped.title, 'An account already exists with this email.');
    });

    test('does not invent a live email availability RPC', () {
      expect(SignupErrorMapper.emailConflict.title.contains('available'), isFalse);
    });

    test('malformed vs valid format copy is format-only', () {
      expect(
        File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync(),
        contains('Enter a valid email address.'),
      );
      expect(
        File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync(),
        isNot(contains('Email available')),
      );
    });

    test('duplicate-account copy is inline and routes to Sign in instead', () {
      final src = File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync();
      expect(src, contains('An account already exists with this email.'));
      expect(src, contains('Sign in instead'));
      expect(src, contains("context.go('/auth/login')"));
      expect(src, contains('emailConflict'));
      expect(src, contains('SignupErrorMapper.emailConflict'));
    });

    test('no public auth.users lookup or email-availability RPC', () {
      const paths = [
        'lib/pages/auth/signup_wizard_page.dart',
        'lib/core/auth/username_availability.dart',
        'lib/core/auth/signup_error_mapper.dart',
      ];
      for (final path in paths) {
        final src = File(path).readAsStringSync();
        expect(src.contains('is_email_available'), isFalse, reason: path);
        expect(src.contains('auth.users'), isFalse, reason: path);
      }
      final wizard = File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync();
      expect(wizard, contains('is_username_available'));
    });

    test('social OAuth path does not run email availability lookup', () {
      final src = File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync();
      expect(src.contains('isSocial'), isTrue);
      expect(src.contains('is_email_available'), isFalse);
    });

    test('anti-enumeration: generic auth failure is not treated as existing account', () {
      final mapped = SignupErrorMapper.map(
        const AuthException('Unable to validate email address'),
      );
      expect(mapped, isNot(SignupErrorMapper.emailConflict));
      expect(mapped.display.toLowerCase().contains('authapiexception'), isFalse);
    });
  });

  group('Fitness goals persistence', () {
    test('legacy labels map to stable ids', () {
      expect(FitnessGoalTaxonomy.idFromStorage('Weight Loss'), 'lose_weight');
      expect(FitnessGoalTaxonomy.idFromStorage('Muscle Gain'), 'build_muscle');
      expect(FitnessGoalTaxonomy.idFromStorage('Strength'), 'get_stronger');
      expect(FitnessGoalTaxonomy.idFromStorage('Nutrition'), 'improve_nutrition');
    });

    test('storage values preserve known consumers', () {
      expect(
        FitnessGoalTaxonomy.toStorage(['lose_weight', 'build_muscle']),
        ['Weight Loss', 'Muscle Gain'],
      );
    });

    test('primary and secondary split', () {
      expect(FitnessGoalTaxonomy.primary, hasLength(4));
      expect(FitnessGoalTaxonomy.secondary, hasLength(4));
    });
  });

  group('Onboarding specialties', () {
    test('trainer specialties are individually selectable disciplines', () {
      expect(
        OnboardingSpecialtyOptions.trainer.map((e) => e.label).toList(),
        [
          'Fitness Trainer',
          'Strength & Conditioning',
          'Yoga',
          'Pilates',
          'Boxing',
          'Calisthenics',
          'Other',
        ],
      );
      expect(
        OnboardingSpecialtyOptions.trainer.map((e) => e.id).toSet().length,
        OnboardingSpecialtyOptions.trainer.length,
      );
    });

    test('nutritionist specialties are individually selectable disciplines', () {
      expect(
        OnboardingSpecialtyOptions.nutritionist.map((e) => e.label).toList(),
        [
          'General Nutrition',
          'Sports Nutrition',
          'Weight Management',
          'Clinical Nutrition',
          'Diet Planning',
          'Other',
        ],
      );
    });

    test('Other requires text to persist', () {
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'other'},
          otherText: '',
        ),
        isEmpty,
      );
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'other'},
          otherText: '  CrossFit  ',
        ),
        isNotEmpty,
      );
    });

    test('Yoga and Pilates persist independently', () {
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'yoga'},
        ),
        ['yoga'],
      );
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'pilates'},
        ),
        ['pilates'],
      );
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'yoga', 'pilates'},
        ),
        containsAll(['yoga', 'pilates']),
      );
    });

    test('Boxing and Calisthenics persist independently', () {
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'boxing'},
        ),
        ['boxing'],
      );
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Trainer',
          selectedIds: {'calisthenics'},
        ),
        ['calisthenics'],
      );
    });

    test('Diet Planning maps to stable meal_planning id', () {
      expect(
        OnboardingSpecialtyOptions.persistSelection(
          role: 'Nutritionist',
          selectedIds: {'diet_planning'},
        ),
        ['meal_planning'],
      );
    });
  });

  group('Role / goals widgets', () {
    testWidgets('role tiles render Member Trainer Nutritionist', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingRoleStep(
            role: 'Client',
            selectedSpecialtyIds: {},
            customSpecialty: TextEditingController(),
            onRoleChanged: (_) {},
            onToggleSpecialty: (_) {},
          ),
        ),
      );
      expect(find.text('MEMBER'), findsOneWidget);
      expect(find.text('CLIENT'), findsNothing);
      expect(find.textContaining('Train, track and connect'), findsOneWidget);
      expect(find.text('TRAINER'), findsOneWidget);
      expect(find.textContaining('Coach members'), findsOneWidget);
      expect(find.text('NUTRITIONIST'), findsOneWidget);
      expect(find.textContaining('Guide members'), findsOneWidget);
      expect(find.text('Choose your path'), findsOneWidget);
    });

    testWidgets('trainer selection expands separate disciplines', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingRoleStep(
            role: 'Trainer',
            selectedSpecialtyIds: {},
            customSpecialty: TextEditingController(),
            onRoleChanged: (_) {},
            onToggleSpecialty: (_) {},
          ),
        ),
      );
      expect(find.text('Fitness Trainer'), findsOneWidget);
      expect(find.text('Strength & Conditioning'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
      expect(find.text('Pilates'), findsOneWidget);
      expect(find.text('Boxing'), findsOneWidget);
      expect(find.text('Calisthenics'), findsOneWidget);
      expect(find.text('Yoga / Pilates'), findsNothing);
      expect(find.text('Boxing / Calisthenics'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Enter your specialty'), findsNothing);
    });

    testWidgets('nutritionist specialties are separate', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingRoleStep(
            role: 'Nutritionist',
            selectedSpecialtyIds: {},
            customSpecialty: TextEditingController(),
            onRoleChanged: (_) {},
            onToggleSpecialty: (_) {},
          ),
        ),
      );
      expect(find.text('General Nutrition'), findsOneWidget);
      expect(find.text('Sports Nutrition'), findsOneWidget);
      expect(find.text('Weight Management'), findsOneWidget);
      expect(find.text('Clinical Nutrition'), findsOneWidget);
      expect(find.text('Diet Planning'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('Other reveals specialty field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingRoleStep(
            role: 'Nutritionist',
            selectedSpecialtyIds: {'other'},
            customSpecialty: TextEditingController(),
            onRoleChanged: (_) {},
            onToggleSpecialty: (_) {},
          ),
        ),
      );
      expect(find.text('Other specialty'), findsOneWidget);
    });

    testWidgets('goals redesigned components render', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingGoalsStep(
            selectedGoalIds: {'lose_weight', 'build_muscle'},
            agreedLegal: false,
            onToggleGoal: (_) {},
            onAgreedLegalChanged: (_) {},
            onOpenTerms: () {},
            onOpenPrivacy: () {},
          ),
        ),
      );
      expect(find.text('BUILD MUSCLE'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Endurance'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('narrow width does not overflow role cards', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingRoleStep(
            role: 'Trainer',
            selectedSpecialtyIds: {'fitness_trainer'},
            customSpecialty: TextEditingController(),
            onRoleChanged: (_) {},
            onToggleSpecialty: (_) {},
          ),
          size: const Size(360, 640),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nutritionist Other on short device does not overflow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingRoleStep(
            role: 'Nutritionist',
            selectedSpecialtyIds: {'other'},
            customSpecialty: TextEditingController(),
            onRoleChanged: (_) {},
            onToggleSpecialty: (_) {},
          ),
          size: const Size(360, 640),
        ),
      );
      expect(find.text('Other specialty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Color system', () {
    test('primary gradient is the Discover source of truth', () {
      expect(CotrainrGradients.primary, DesignTokens.discoverGradient);
      expect(CotrainrGradients.focus, DesignTokens.discoverOrange);
    });

    testWidgets('Login/Next/Finish share AuthPrimaryButton', (tester) async {
      await tester.pumpWidget(
        _wrap(AuthPrimaryButton(label: 'Sign In', onPressed: () {})),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final deco = container.decoration as BoxDecoration;
      expect(deco.gradient, CotrainrGradients.primary);

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
      expect(find.byType(AuthPrimaryButton), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      final back = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(back.style?.backgroundColor?.resolve({}), isNotNull);

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
      expect(find.byType(AuthPrimaryButton), findsOneWidget);
    });

    testWidgets('unit toggle source uses Discover gradient', (tester) async {
      final src =
          File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync();
      expect(src.contains('gradient: CotrainrGradients.primary'), isTrue);
      expect(src.contains('color: DesignTokens.accentOrange'), isFalse);
    });
  });

  group('Height / Weight spacing', () {
    test('measure gap never drops below 16', () {
      expect(onboardingMeasureControlGap, isA<Function>());
    });

    testWidgets('progress to value-control gap is ~24 on typical height',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Column(
                children: [
                  OnboardingHeader(
                    title: 'Height',
                    subtitle: 'Set your height.',
                    step: 3,
                    totalSteps: 7,
                    afterProgress: onboardingMeasureControlGap(context),
                  ),
                  Container(key: const Key('value-control'), height: 64),
                ],
              );
            },
          ),
          size: const Size(390, 844),
        ),
      );
      final progressBottom =
          tester.getBottomLeft(find.byType(OnboardingProgress));
      final valueTop = tester.getTopLeft(find.byKey(const Key('value-control')));
      expect(valueTop.dy - progressBottom.dy, closeTo(48, 1));
    });

    testWidgets('short devices keep at least 16dp after progress',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Column(
                children: [
                  OnboardingHeader(
                    title: 'Weight',
                    subtitle: 'Set your current weight.',
                    step: 4,
                    totalSteps: 7,
                    afterProgress: onboardingMeasureControlGap(context),
                  ),
                  Container(key: const Key('value-control'), height: 64),
                ],
              );
            },
          ),
          size: const Size(360, 620),
        ),
      );
      final progressBottom =
          tester.getBottomLeft(find.byType(OnboardingProgress));
      final valueTop = tester.getTopLeft(find.byKey(const Key('value-control')));
      expect(valueTop.dy - progressBottom.dy, greaterThanOrEqualTo(16));
      expect(tester.takeException(), isNull);
    });

    test('cm/ft-in and kg/lb conversion source is unchanged', () {
      final src =
          File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync();
      expect(src, contains('/ 2.54'));
      expect(src, contains('* 2.2046226218'));
      expect(src, contains('* 0.45359237'));
      expect(src, contains("left: 'cm'"));
      expect(src, contains("right: 'ft/in'"));
      expect(src, contains("left: 'kg'"));
      expect(src, contains("right: 'lb'"));
    });
  });

  group('Loader and success', () {
    testWidgets('logo assembly fullscreen renders', (tester) async {
      await tester.pumpWidget(
        _wrap(const CotrainrLoader.fullscreen()),
      );
      expect(find.byType(LogoAssemblyMark), findsOneWidget);
      expect(find.text('Getting you ready…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('reduced-motion loader is static assembled logo', (tester) async {
      await tester.pumpWidget(
        _wrap(const CotrainrLoader.compact(), reduceMotion: true),
      );
      await tester.pump();
      expect(find.byType(LogoAssemblyMark), findsOneWidget);
    });

    testWidgets('All Set screen renders', (tester) async {
      var continued = false;
      await tester.pumpWidget(
        _wrap(OnboardingAllSetView(onContinue: () => continued = true)),
      );
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.text("YOU'RE ALL SET"), findsOneWidget);
      expect(find.text('Your Cotrainr profile is ready.'), findsOneWidget);
      await tester.tap(find.text("Let's get started"));
      expect(continued, isTrue);
    });
  });

  group('Transitions reduced motion', () {
    testWidgets('AuthStepTransition reduced-motion uses fade only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AuthStepTransition(
            animation: const AlwaysStoppedAnimation(1),
            child: const Text('step'),
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text('step'), findsOneWidget);
    });
  });
}
