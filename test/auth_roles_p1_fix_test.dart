import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/config/feature_flags.dart';
import 'package:cotrainr/core/auth/account_status.dart';
import 'package:cotrainr/core/auth/auth_error_mapper.dart';
import 'package:cotrainr/core/auth/user_role.dart';
import 'package:cotrainr/core/auth/verification_error_messages.dart';
import 'package:cotrainr/core/startup/go_router_auth_refresh.dart';
import 'package:cotrainr/providers/profile_role_provider.dart';
import 'package:cotrainr/repositories/verification_repository.dart';
import 'package:cotrainr/widgets/provider/provider_verification_card.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('role normalization (P2)', () {
    test('canonical values parse', () {
      expect(UserRoleParser.parse('client'), UserRole.client);
      expect(UserRoleParser.parse('trainer'), UserRole.trainer);
      expect(UserRoleParser.parse('nutritionist'), UserRole.nutritionist);
    });

    test('casing and whitespace are normalized safely', () {
      expect(UserRoleParser.parse('  Trainer '), UserRole.trainer);
      expect(UserRoleParser.parse('NUTRITIONIST'), UserRole.nutritionist);
      expect(UserRoleParser.normalize(' Client'), 'client');
    });

    test('unknown role fails closed — never client or trainer', () {
      for (final value in [
        null,
        '',
        '   ',
        'admin',
        'coach',
        'provider',
        'dietitian',
        'user',
        'partner',
      ]) {
        expect(UserRoleParser.parse(value), isNull, reason: 'value=$value');
        expect(UserRoleParser.normalize(value), isNull);
        expect(UserRoleParser.isProviderRole(value), isFalse);
      }
    });

    test('CurrentUser exposes no capability for unknown role', () {
      final unknown = CurrentUser.fromJson({'id': 'u1', 'role': 'admin'});
      expect(unknown.role, isNull);
      expect(unknown.roleValue, isNull);
      expect(unknown.isClient, isFalse);
      expect(unknown.isTrainer, isFalse);
      expect(unknown.isNutritionist, isFalse);
      expect(unknown.isProvider, isFalse);

      final trainer = CurrentUser.fromJson({'id': 'u2', 'role': 'Trainer'});
      expect(trainer.isTrainer, isTrue);
      expect(trainer.isProvider, isTrue);
      expect(trainer.roleValue, 'trainer');
    });
  });

  group('account moderation state (P1)', () {
    test('active by default and for unknown values', () {
      expect(
        AccountStatusParser.fromProfile({'account_status': 'active'})
            .isRestricted,
        isFalse,
      );
      expect(AccountStatusParser.fromProfile(null).isRestricted, isFalse);
      expect(
        AccountStatusParser.fromProfile({'account_status': 'weird'})
            .isRestricted,
        isFalse,
      );
    });

    test('banned and suspended are restricted', () {
      expect(
        AccountStatusParser.fromProfile({'account_status': 'banned'}).status,
        AccountStatus.banned,
      );
      expect(
        AccountStatusParser.fromProfile({'account_status': ' Suspended '})
            .status,
        AccountStatus.suspended,
      );
    });

    test('expired suspension resolves to active (matches SQL semantics)', () {
      final past = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final future = DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String();

      expect(
        AccountStatusParser.fromProfile({
          'account_status': 'suspended',
          'suspended_until': past,
        }).isRestricted,
        isFalse,
      );
      expect(
        AccountStatusParser.fromProfile({
          'account_status': 'suspended',
          'suspended_until': future,
        }).isRestricted,
        isTrue,
      );
      // A ban never expires.
      expect(
        AccountStatusParser.fromProfile({
          'account_status': 'banned',
          'suspended_until': past,
        }).isRestricted,
        isTrue,
      );
    });

    test('user-facing copy exposes no internal moderation notes', () {
      final restriction = AccountStatusParser.fromProfile({
        'account_status': 'banned',
        'moderation_reason': 'spam ring #4412 flagged by admin bob',
      });
      expect(restriction.title, 'Account closed');
      expect(restriction.message.contains('spam ring'), isFalse);
      expect(restriction.message.contains('4412'), isFalse);
      expect(restriction.message.contains('bob'), isFalse);
    });

    test('banned/suspended users are routed away from /home', () {
      final source = _read('lib/core/auth/post_auth_destination.dart');
      final gateIndex = source.indexOf('AccountStatusParser.fromProfile');
      final homeIndex = source.indexOf("return '/home'");
      expect(gateIndex, greaterThan(0));
      expect(homeIndex, greaterThan(gateIndex));
      expect(source.contains(PostAuthDestinationRoutes.restricted), isTrue);
      // Unreadable profile must not fall through to /home.
      expect(source.contains("if (profile == null) return '/auth/continue';"),
          isTrue);
    });
  });

  group('self-unban / admin field mutation (P1)', () {
    final sql = _read(
      'supabase/manual/20260830_profiles_moderation_hardening.sql',
    );

    test('moderation fields are frozen for client updates', () {
      expect(sql.contains('NEW.account_status := OLD.account_status'), isTrue);
      expect(sql.contains('NEW.suspended_until := OLD.suspended_until'), isTrue);
      expect(
        sql.contains('NEW.moderation_reason := OLD.moderation_reason'),
        isTrue,
      );
      expect(sql.contains('NEW.role := OLD.role'), isTrue);
      expect(sql.contains('NEW.email := OLD.email'), isTrue);
      expect(sql.contains('NEW.id := OLD.id'), isTrue);
    });

    test('service_role / postgres paths keep moderation control', () {
      expect(sql.contains("v_jwt_role = 'service_role'"), isTrue);
      expect(sql.contains('GRANT ALL ON TABLE public.profiles TO service_role'),
          isTrue);
    });

    test('column-level UPDATE excludes administrative columns only', () {
      expect(
        sql.contains('REVOKE UPDATE ON TABLE public.profiles FROM authenticated'),
        isTrue,
      );
      expect(sql.contains('GRANT UPDATE (%s) ON TABLE public.profiles'), isTrue);
      for (final protected in [
        "'id'",
        "'role'",
        "'email'",
        "'account_status'",
        "'suspended_until'",
        "'moderation_reason'",
      ]) {
        expect(sql.contains(protected), isTrue, reason: protected);
      }
      // Normal editable fields must not be excluded.
      for (final editable in [
        'full_name',
        'date_of_birth',
        'gender',
        'height_cm',
        'weight_kg',
        'avatar_url',
      ]) {
        expect(
          sql.contains("      '$editable'"),
          isFalse,
          reason: '$editable must stay updatable',
        );
      }
    });

    test('manual SQL is non-destructive', () {
      // Only executable statements matter; the header documents what is absent.
      final statements = sql
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('--'))
          .join('\n');
      for (final forbidden in [
        'DROP TABLE',
        'TRUNCATE',
        'DELETE FROM public.profiles',
        'DROP COLUMN',
        'CASCADE',
      ]) {
        expect(statements.contains(forbidden), isFalse, reason: forbidden);
      }
      expect(sql.contains('BEGIN;'), isTrue);
      expect(sql.contains('COMMIT;'), isTrue);
    });

    test('client cannot become trainer through normal profile edit', () {
      // Server RPC used by profile editing strips role/email/id.
      final rpc = _read('supabase/migrations/20250713_coach_client_access_fix.sql');
      expect(
        rpc.contains("p_updates := p_updates - 'role' - 'email' - 'id'"),
        isTrue,
      );
      // Client no longer submits privileged fields either.
      final page = _read('lib/pages/profile/edit_profile_page.dart');
      expect(page.contains("'email': _emailController.text.trim()"), isFalse);
      expect(page.contains("'role':"), isFalse);
      // Client-side profile creation from auth metadata is gone.
      final roleService = _read('lib/services/profile_role_service.dart');
      expect(roleService.contains("from('profiles').insert"), isFalse);
      expect(roleService.contains("userMetadata?['role']"), isFalse);
    });
  });

  group('provider verification is server-authoritative (P1)', () {
    test('nutritionist profile no longer reads client-writable metadata', () {
      final page =
          _read('lib/pages/nutritionist/nutritionist_profile_page.dart');
      expect(page.contains("userMetadata?['verification_status']"), isFalse);
      expect(page.contains('getProviderVerificationStatus'), isTrue);
      expect(page.contains('ProviderVerificationCard'), isTrue);
      expect(page.contains('ProviderVerificationErrorCard'), isTrue);
    });

    test('repository does not swallow verification lookup failures', () {
      final repo = _read('lib/repositories/verification_repository.dart');
      expect(repo.contains("return 'trainer';"), isFalse);
      expect(repo.contains('VerificationRoleUnresolved'), isTrue);
      // No blanket catch that downgrades an error to notSubmitted.
      expect(
        repo.contains('} catch (_) {\n      return null;\n    }'),
        isFalse,
      );
    });

    test('failed role lookup does not fall back to trainer', () {
      final page = _read('lib/pages/trainer/verification_submission_page.dart');
      expect(page.contains("String? _providerRole;"), isTrue);
      expect(page.contains("_providerRole = 'trainer'"), isFalse);
      expect(page.contains("metaRole == 'nutritionist'"), isFalse);
      expect(page.contains('_roleResolved'), isTrue);
    });

    testWidgets('pending state renders pending copy', (tester) async {
      await tester.pumpWidget(_host(
        ProviderVerificationCard(
          status: ProviderVerificationStatus.pending,
          role: 'nutritionist',
          onTap: () {},
        ),
      ));
      expect(find.text('Verification Pending'), findsOneWidget);
    });

    testWidgets('rejected state offers resubmission feedback', (tester) async {
      await tester.pumpWidget(_host(
        ProviderVerificationCard(
          status: ProviderVerificationStatus.rejected,
          role: 'nutritionist',
          onTap: () {},
        ),
      ));
      expect(find.text('Verification Rejected'), findsOneWidget);
      expect(
        find.text('Tap to review feedback and submit new documents.'),
        findsOneWidget,
      );
    });

    testWidgets('not-submitted state asks for documents', (tester) async {
      await tester.pumpWidget(_host(
        ProviderVerificationCard(
          status: ProviderVerificationStatus.notSubmitted,
          role: 'nutritionist',
          onTap: () {},
        ),
      ));
      expect(find.text('Verify Your Nutritionist Account'), findsOneWidget);
    });

    testWidgets('approved nutritionist sees no verification prompt',
        (tester) async {
      // The page hides the card entirely when verified.
      final page =
          _read('lib/pages/nutritionist/nutritionist_profile_page.dart');
      expect(
        page.contains(
          '_verificationStatus != ProviderVerificationStatus.verified',
        ),
        isTrue,
      );
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(find.text('Verify Your Nutritionist Account'), findsNothing);
    });

    testWidgets('network error shows retry, never "unverified"',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(_host(
        ProviderVerificationErrorCard(onRetry: () => retries++),
      ));
      expect(find.text('Verification status unavailable'), findsOneWidget);
      expect(find.text('Verify Your Nutritionist Account'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('routing authority (P1)', () {
    test('verification submission cannot bypass the post-auth gate', () {
      final page = _read('lib/pages/trainer/verification_submission_page.dart');
      expect(page.contains("context.go('/home')"), isFalse);
      expect(page.contains('_leaveThroughPostAuthGate'), isTrue);
      expect(page.contains('PostAuthDestination.resolve'), isTrue);
    });

    test('completed user cannot deep-link into onboarding', () {
      final page = _read('lib/pages/auth/complete_profile_page.dart');
      expect(page.contains('OnboardingStateService.fetch'), isTrue);
      expect(page.contains('state.isComplete'), isTrue);
      expect(page.contains('PostAuthDestination.resolve'), isTrue);
      // The wizard is only reached after the completeness check.
      final guardIndex = page.indexOf('state.isComplete');
      final wizardIndex = page.indexOf('SignupWizardPage(mode:');
      expect(guardIndex, greaterThan(0));
      expect(wizardIndex, greaterThan(guardIndex));
    });

    test('onboarding resume hydrates persisted values', () {
      final wizard = _read('lib/pages/auth/signup_wizard_page.dart');
      expect(wizard.contains('_hydrateExistingProfileValues'), isTrue);
      for (final field in [
        "profile['date_of_birth']",
        "profile['gender']",
        "profile['height_cm']",
        "profile['weight_kg']",
      ]) {
        expect(wizard.contains(field), isTrue, reason: field);
      }
    });

    test('logout leaves protected routes without user navigation', () {
      final router = _read('lib/router/app_router.dart');
      expect(router.contains('refreshListenable: goRouterAuthRefresh'), isTrue);
      expect(router.contains('goRouterAuthRefresh.bindAuthIfReady()'), isTrue);
    });

    test('auth refresh listenable binds lazily without throwing', () {
      final refresh = GoRouterAuthRefresh();
      // Supabase is not initialized in tests: must not throw, must not bind.
      refresh.bindAuthIfReady();
      expect(refresh.isBound, isFalse);
      refresh.dispose();
    });

    test('/ai-planner is gated and unreachable by deep link', () {
      expect(FeatureFlags.enableAiPlanner, isFalse);
      final router = _read('lib/router/app_router.dart');
      final routeIndex = router.indexOf("path: '/ai-planner'");
      expect(routeIndex, greaterThan(0));
      final block = router.substring(routeIndex, routeIndex + 600);
      expect(block.contains('FeatureFlags.enableAiPlanner'), isTrue);
      expect(block.contains("return '/home'"), isTrue);
      // Code/data intentionally retained.
      expect(File('lib/pages/ai_planner/ai_planner_page.dart').existsSync(),
          isTrue);
    });

    test('account-restricted route exists', () {
      final router = _read('lib/router/app_router.dart');
      expect(router.contains("path: '/account-restricted'"), isTrue);
      expect(router.contains('AccountRestrictedPage'), isTrue);
    });
  });

  group('error sanitization (P1/P2)', () {
    test('verification failures map to human copy', () {
      const storage = StorageException(
        'Bucket not found',
        statusCode: '404',
        error: 'Bucket not found',
      );
      final postgrest = PostgrestException(
        message: 'permission denied for table verification_submissions',
        code: '42501',
      );

      for (final message in [
        VerificationErrorMessages.forSubmit(storage),
        VerificationErrorMessages.forSubmit(postgrest),
        VerificationErrorMessages.forLoadStatus(postgrest),
        VerificationErrorMessages.forSaveProfessional(postgrest),
        VerificationErrorMessages.forLogout(postgrest),
      ]) {
        for (final leak in [
          'StorageException',
          'PostgrestException',
          'Bucket not found',
          '404',
          '42501',
          'permission denied',
          'verification_submissions',
        ]) {
          expect(message.contains(leak), isFalse, reason: '$leak in $message');
        }
        expect(message.endsWith('try again.') || message.endsWith('Try again.'),
            isTrue);
      }
    });

    test('network failures get connection copy', () {
      const socket = SocketException('Failed host lookup');
      expect(VerificationErrorMessages.forSubmit(socket),
          VerificationErrorMessages.network);
      expect(VerificationErrorMessages.forLogout(socket),
          VerificationErrorMessages.network);
    });

    test('raw errors are not rendered in the audited auth/provider UI', () {
      final files = {
        'lib/pages/trainer/verification_submission_page.dart': [
          r"Text('$e",
          'e.toString()',
        ],
        'lib/pages/profile/provider_certifications_page.dart': [
          r"Could not load: $e",
        ],
        'lib/pages/profile/settings_page.dart': [
          r"Logout failed: $e",
        ],
      };
      files.forEach((path, forbidden) {
        final source = _read(path);
        for (final pattern in forbidden) {
          expect(source.contains(pattern), isFalse,
              reason: '$pattern in $path');
        }
      });
    });

    test('release print() removed from audited auth/profile pages', () {
      for (final path in [
        'lib/pages/profile/edit_profile_page.dart',
        'lib/pages/auth/permissions_page.dart',
      ]) {
        final source = _read(path);
        expect(
          RegExp(r'(^|[^a-zA-Z.])print\(').hasMatch(source),
          isFalse,
          reason: 'print( in $path',
        );
      }
    });
  });

  group('email verification (P1)', () {
    test('email-not-confirmed is distinct from wrong credentials', () {
      final mapped = AuthErrorMapper.map(AuthException('Email not confirmed'));
      expect(mapped.kind, AuthUserErrorKind.emailNotConfirmed);
      expect(mapped.title, 'Please verify your email before signing in.');
      expect(mapped.title, isNot(AuthErrorMapper.invalidCredentials.title));
    });

    test('email_not_confirmed code variant maps too', () {
      final mapped = AuthErrorMapper.map(
        AuthException('Bad request', code: 'email_not_confirmed'),
      );
      expect(mapped.kind, AuthUserErrorKind.emailNotConfirmed);
    });

    test('wrong password still maps to non-enumerating copy', () {
      final mapped =
          AuthErrorMapper.map(AuthException('Invalid login credentials'));
      expect(mapped.kind, AuthUserErrorKind.invalidCredentials);
    });

    test('password reset never reveals confirmation state', () {
      final mapped = AuthErrorMapper.mapPasswordResetFailure(
        AuthException('Email not confirmed'),
      );
      expect(mapped, AuthErrorMapper.passwordResetFailed);
    });
  });
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

/// Route names asserted by the moderation routing contract.
abstract final class PostAuthDestinationRoutes {
  static const restricted = '/account-restricted';
}
