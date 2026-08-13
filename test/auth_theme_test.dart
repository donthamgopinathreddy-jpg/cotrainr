import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/pages/auth/login_page.dart';
import 'package:cotrainr/theme/auth_theme.dart';
import 'package:cotrainr/theme/design_tokens.dart';
import 'package:cotrainr/widgets/auth/auth_ui.dart';
import 'package:cotrainr/widgets/auth/onboarding_role_goals.dart';
import 'package:cotrainr/widgets/auth/onboarding_shell.dart';
import 'package:cotrainr/widgets/auth/onboarding_success.dart';
import 'package:cotrainr/widgets/branding/cotrainr_loader.dart';

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF9F1A),
        brightness: brightness,
      ),
    );

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
}) {
  return MaterialApp(
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode:
        brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration: Duration.zero,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: true,
        platformBrightness: brightness,
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthTheme tokens', () {
    testWidgets('light mode is warm off-white, not hospital white',
        (tester) async {
      late Color bg;
      late Color field;
      late Color title;
      late Color secondary;
      await tester.pumpWidget(
        _app(
          Builder(builder: (context) {
            bg = AuthTheme.background(context);
            field = AuthTheme.fieldSurface(context);
            title = AuthTheme.primaryText(context);
            secondary = AuthTheme.secondaryText(context);
            return const SizedBox.shrink();
          }),
          brightness: Brightness.light,
        ),
      );
      expect(bg, isNot(Colors.white));
      expect(bg, isNot(const Color(0xFFFFFFFF)));
      expect(field, isNot(bg));
      expect(title.computeLuminance(), lessThan(0.2));
      expect(secondary.computeLuminance(), greaterThan(0.12));
      expect(secondary.computeLuminance(), lessThan(0.55));
    });

    testWidgets('dark mode stays near-black with readable secondary',
        (tester) async {
      late Color bg;
      late Color field;
      late Color title;
      late Color secondary;
      await tester.pumpWidget(
        _app(
          Builder(builder: (context) {
            bg = AuthTheme.background(context);
            field = AuthTheme.fieldSurface(context);
            title = AuthTheme.primaryText(context);
            secondary = AuthTheme.secondaryText(context);
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(bg.computeLuminance(), lessThan(0.05));
      expect(field, isNot(bg));
      expect(title.computeLuminance(), greaterThan(0.8));
      expect(secondary.computeLuminance(), greaterThan(0.35));
    });

    test('primary gradient is Discover', () {
      expect(AuthTheme.primaryGradient, DesignTokens.discoverGradient);
      expect(CotrainrGradients.primary, DesignTokens.discoverGradient);
    });

    testWidgets('selection surfaces differ by theme', (tester) async {
      late Color lightSel;
      late Color darkSel;
      await tester.pumpWidget(
        _app(
          Builder(builder: (context) {
            lightSel = AuthTheme.selectionSurface(context);
            return const SizedBox.shrink();
          }),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpWidget(
        _app(
          Builder(builder: (context) {
            darkSel = AuthTheme.selectionSurface(context);
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(lightSel.computeLuminance(), greaterThan(0.7));
      expect(darkSel.computeLuminance(), lessThan(0.12));
    });
  });

  group('Login light/dark', () {
    testWidgets('light login uses shared CTA and readable copy', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: ThemeMode.light,
          home: const LoginPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to continue training.'), findsOneWidget);
      expect(find.byType(AuthPrimaryButton), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('dark login uses shared CTA', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const LoginPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(AuthPrimaryButton), findsWidgets);
    });
  });

  group('Role display vs backend', () {
    testWidgets('Member is display-only; Client is internal', (tester) async {
      String? lastRole;
      await tester.pumpWidget(
        _app(
          OnboardingRoleStep(
            role: 'Client',
            selectedSpecialtyIds: {},
            customSpecialty: TextEditingController(),
            onRoleChanged: (v) => lastRole = v,
            onToggleSpecialty: (_) {},
          ),
          brightness: Brightness.light,
        ),
      );
      expect(find.text('MEMBER'), findsOneWidget);
      expect(find.text('CLIENT'), findsNothing);
      expect(find.textContaining('Train, track and connect'), findsOneWidget);
      expect(find.text('TRAINER'), findsOneWidget);
      expect(find.text('NUTRITIONIST'), findsOneWidget);
      await tester.tap(find.text('MEMBER'));
      expect(lastRole, 'Client');
    });

    test('signup wizard still stores Client', () {
      final wizard =
          File('lib/pages/auth/signup_wizard_page.dart').readAsStringSync();
      final roles =
          File('lib/widgets/auth/onboarding_role_goals.dart').readAsStringSync();
      expect(wizard.contains("String _role = 'Client'"), isTrue);
      expect(roles.contains("onRoleChanged('Client')"), isTrue);
      expect(roles.contains("role == 'Client'"), isTrue);
    });
  });

  group('Onboarding light/dark widgets', () {
    testWidgets('gender and back/next theme in light', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AuthGenderSelector(value: 'Male', onChanged: (_) {}),
              OnboardingBottomActions(
                step: 2,
                isLast: false,
                onNext: () {},
                onBack: () {},
              ),
            ],
          ),
          brightness: Brightness.light,
        ),
      );
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.byType(AuthPrimaryButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('goals and terms readable in light', (tester) async {
      await tester.pumpWidget(
        _app(
          OnboardingGoalsStep(
            selectedGoalIds: {'lose_weight'},
            agreedLegal: true,
            onToggleGoal: (_) {},
            onAgreedLegalChanged: (_) {},
            onOpenTerms: () {},
            onOpenPrivacy: () {},
          ),
          brightness: Brightness.light,
          size: const Size(360, 780),
        ),
      );
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('All Set and loader render in both themes', (tester) async {
      for (final b in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          _app(OnboardingAllSetView(onContinue: () {}), brightness: b),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text("YOU'RE ALL SET"), findsOneWidget);
        expect(find.text("Let's get started"), findsOneWidget);

        await tester.pumpWidget(
          _app(const CotrainrLoader.compact(), brightness: b),
        );
        expect(find.text('Getting you ready…'), findsOneWidget);
      }
    });
  });
}
