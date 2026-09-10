import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/services/messaging_policy_service.dart';
import 'package:cotrainr/utils/messaging_error_messages.dart';

void main() {
  group('MessagingAccessStatus / backend codes', () {
    test('maps allowed / not accepted / subscription / blocked', () {
      expect(
        MessagingPolicyService.statusFromBackendCode('allowed'),
        MessagingAccessStatus.allowed,
      );
      expect(
        MessagingPolicyService.statusFromBackendCode('no_accepted_lead'),
        MessagingAccessStatus.notAccepted,
      );
      expect(
        MessagingPolicyService.statusFromBackendCode('subscription_required'),
        MessagingAccessStatus.subscriptionRequired,
      );
      expect(
        MessagingPolicyService.statusFromBackendCode('users_blocked'),
        MessagingAccessStatus.blocked,
      );
    });

    test('unknown / empty codes are unavailable — never allowed', () {
      expect(
        MessagingPolicyService.statusFromBackendCode(null),
        MessagingAccessStatus.unavailable,
      );
      expect(
        MessagingPolicyService.statusFromBackendCode(''),
        MessagingAccessStatus.unavailable,
      );
      expect(
        MessagingPolicyService.statusFromBackendCode('weird'),
        MessagingAccessStatus.unavailable,
      );
    });

    test('PostgrestException classification', () {
      expect(
        MessagingPolicyService.statusFromPostgrestException(
          PostgrestException(message: 'subscription_required'),
        ),
        MessagingAccessStatus.subscriptionRequired,
      );
      expect(
        MessagingPolicyService.statusFromPostgrestException(
          PostgrestException(message: 'no_accepted_lead'),
        ),
        MessagingAccessStatus.notAccepted,
      );
      expect(
        MessagingPolicyService.statusFromPostgrestException(
          PostgrestException(message: 'network boom'),
        ),
        MessagingAccessStatus.unavailable,
      );
    });

    test('user copy never exposes raw exceptions', () {
      for (final status in MessagingAccessStatus.values) {
        final msg = MessagingPolicyService.userMessageFor(status);
        expect(msg.toLowerCase().contains('postgrest'), isFalse);
        expect(msg.toLowerCase().contains('supabase'), isFalse);
        expect(msg.contains('Exception'), isFalse);
      }
      expect(
        MessagingPolicyService.userMessageFor(
          MessagingAccessStatus.unavailable,
        ),
        contains("Couldn't verify messaging access"),
      );
      expect(
        MessagingPolicyService.userMessageFor(
          MessagingAccessStatus.subscriptionRequired,
        ),
        contains('membership'),
      );
    });
  });

  group('ended vs subscription banners', () {
    test('accepted + inactive subscription is NOT ended banner', () {
      expect(
        MessagingPolicyService.shouldShowEndedConnectionBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: false,
          eitherBlocked: false,
          denialStatus: MessagingAccessStatus.subscriptionRequired,
        ),
        isFalse,
      );
      expect(
        MessagingPolicyService.shouldShowSubscriptionRequiredBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: false,
          eitherBlocked: false,
          denialStatus: MessagingAccessStatus.subscriptionRequired,
        ),
        isTrue,
      );
    });

    test('lookup failure is NOT fake not-connected / ended', () {
      expect(
        MessagingPolicyService.shouldShowEndedConnectionBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: false,
          eitherBlocked: false,
          denialStatus: MessagingAccessStatus.unavailable,
        ),
        isFalse,
      );
    });

    test('not accepted still shows ended banner for history threads', () {
      expect(
        MessagingPolicyService.shouldShowEndedConnectionBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: false,
          eitherBlocked: false,
          denialStatus: MessagingAccessStatus.notAccepted,
        ),
        isTrue,
      );
    });

    test('error heuristics no longer treat can_send as ended', () {
      expect(
        MessagingErrorMessages.looksLikeEndedConnectionDenial(
          'violates can_send_message_in_conversation',
        ),
        isFalse,
      );
      expect(
        MessagingErrorMessages.looksLikeEndedConnectionDenial(
          'no_accepted_lead',
        ),
        isTrue,
      );
      expect(
        MessagingErrorMessages.looksLikeSubscriptionDenial(
          'subscription_required',
        ),
        isTrue,
      );
    });
  });

  group('source contracts — Wave 2 entitlement truthfulness', () {
    late String policy;
    late String migration;
    late String profile;
    late String shell;
    late String repo;
    late String cocircle;

    setUpAll(() {
      policy = File('lib/services/messaging_policy_service.dart').readAsStringSync();
      migration = File(
        'supabase/migrations/20260910120000_messaging_access_subscription_truth.sql',
      ).readAsStringSync();
      profile =
          File('lib/pages/profile/public_profile_readonly_page.dart').readAsStringSync();
      shell = File(
        'lib/pages/client_monitoring/client_detail_shell.dart',
      ).readAsStringSync();
      repo = File('lib/repositories/messages_repository.dart').readAsStringSync();
      cocircle =
          File('lib/pages/cocircle/user_profile_page.dart').readAsStringSync();
    });

    test('migration adds access RPC + subscription gate on create', () {
      expect(
        migration.contains('provider_client_messaging_access'),
        isTrue,
      );
      expect(
        migration.contains('client_has_active_messaging_subscription'),
        isTrue,
      );
      expect(migration.contains('subscription_required'), isTrue);
      expect(
        migration.contains('conversation_has_accepted_lead'),
        isTrue,
      );
      final createFn = migration.substring(
        migration.indexOf(
          'CREATE OR REPLACE FUNCTION public.create_or_find_provider_client_conversation',
        ),
      );
      // Existing thread returned before subscription gate; new insert gated.
      expect(
        createFn.indexOf('IF v_id IS NOT NULL'),
        lessThan(createFn.indexOf('subscription_required')),
      );
    });

    test('policy reuses access RPC and fails closed on subscription', () {
      expect(policy.contains('provider_client_messaging_access'), isTrue);
      expect(policy.contains('clientHasActiveMessagingSubscription'), isTrue);
      expect(policy.contains('evaluateMessagingWithOtherUser'), isTrue);
      expect(
        policy.contains('Fail closed when subscription state cannot be confirmed'),
        isTrue,
      );
      // Fail-open accountMayMessage removed.
      expect(
        policy.contains('Fail open for older backends without the RPC'),
        isFalse,
      );
    });

    test('client public profile Message CTA uses messaging access status', () {
      expect(profile.contains('evaluateMessagingWithOtherUser'), isTrue);
      expect(profile.contains('createOrFindConversationDetailed'), isTrue);
      expect(profile.contains('_messagingAccess'), isTrue);
      expect(profile.contains('_messageBusy'), isTrue);
    });

    test('provider client detail Message CTA gates on access', () {
      expect(shell.contains('evaluateMessagingWithOtherUser'), isTrue);
      expect(shell.contains('createOrFindConversationDetailed'), isTrue);
      expect(shell.contains('messageEnabled'), isTrue);
      expect(shell.contains('_messagingBusy'), isTrue);
    });

    test('createOrFind returns typed denial — not silent null alone', () {
      expect(repo.contains('createOrFindConversationDetailed'), isTrue);
      expect(repo.contains('CreateConversationResult'), isTrue);
      expect(repo.contains('statusFromPostgrestException'), isTrue);
    });

    test('CoCircle Message remains flag-gated off by default', () {
      expect(cocircle.contains('allowMessagingAndFollow'), isTrue);
      expect(
        cocircle.contains('this.allowMessagingAndFollow = false'),
        isTrue,
      );
    });

    test('CoCircle general DM create is not wired from shipping homes', () {
      final trainerHome =
          File('lib/pages/trainer/trainer_home_page.dart').readAsStringSync();
      final nutritionistHome = File(
        'lib/pages/nutritionist/nutritionist_home_page.dart',
      ).readAsStringSync();
      final clientHome =
          File('lib/pages/home/home_page_v3.dart').readAsStringSync();
      for (final src in [trainerHome, nutritionistHome, clientHome]) {
        expect(src.contains('UserProfilePage('), isFalse);
        expect(src.contains('allowMessagingAndFollow: true'), isFalse);
      }
    });
  });

  group('CreateConversationResult', () {
    test('ok requires non-empty conversation id', () {
      expect(const CreateConversationResult.ok('c1').isOk, isTrue);
      expect(
        const CreateConversationResult.denied(
          MessagingAccessStatus.subscriptionRequired,
        ).isOk,
        isFalse,
      );
    });
  });
}
