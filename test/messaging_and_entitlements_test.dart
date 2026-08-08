import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/services/leads_models.dart';
import 'package:cotrainr/services/messaging_policy_service.dart';
import 'package:cotrainr/services/entitlement_service.dart';

void main() {
  group('MessagingPolicyService conversation shape', () {
    test('provider–client conversation is allowed shape', () {
      expect(
        MessagingPolicyService.isProviderClientConversation({
          'client_id': 'c1',
          'provider_id': 'p1',
          'other_user_id': null,
        }),
        isTrue,
      );
    });

    test('legacy CoCircle other_user_id conversation is excluded', () {
      expect(
        MessagingPolicyService.isProviderClientConversation({
          'client_id': 'c1',
          'provider_id': null,
          'other_user_id': 'u2',
        }),
        isFalse,
      );
      expect(
        MessagingPolicyService.isProviderClientConversation({
          'client_id': 'c1',
          'provider_id': 'p1',
          'other_user_id': 'u2',
        }),
        isFalse,
      );
    });

    test('otherParticipantUserId resolves peer', () {
      expect(
        MessagingPolicyService.otherParticipantUserId({
          'client_id': 'c1',
          'provider_id': 'p1',
        }, 'c1'),
        'p1',
      );
      expect(
        MessagingPolicyService.otherParticipantUserId({
          'client_id': 'c1',
          'provider_id': 'p1',
        }, 'p1'),
        'c1',
      );
      expect(
        MessagingPolicyService.otherParticipantUserId({
          'client_id': 'c1',
          'provider_id': 'p1',
        }, 'x'),
        isNull,
      );
    });
  });

  group('CreateLeadResult / entitlements parsing', () {
    test('unlimited premium result has null remaining/limit', () {
      final r = CreateLeadResult.fromJson({
        'lead_id': 'l1',
        'status': 'requested',
        'remaining': null,
        'limit': null,
        'unlimited': true,
      });
      expect(r.unlimited, isTrue);
      expect(r.remaining, isNull);
      expect(r.limit, isNull);
      expect(r.status, 'requested');
    });

    test('free result parses remaining ints', () {
      final r = CreateLeadResult.fromJson({
        'lead_id': 'l2',
        'remaining': 2,
        'limit': 5,
        'unlimited': false,
      });
      expect(r.status, 'requested');
      expect(r.remaining, 2);
      expect(r.limit, 5);
    });

    test('Entitlements.fromJson monthly unlimited', () {
      final e = Entitlements.fromJson({
        'plan': 'premium',
        'status': 'active',
        'month_start': '2026-08-01',
        'limits': {
          'requests': null,
          'requests_unlimited': true,
          'nutritionist_allowed': true,
        },
        'used': {'requests': 0},
        'remaining': {
          'requests': null,
          'requests_unlimited': true,
        },
      });
      expect(e.plan, 'premium');
      expect(e.limits.requestsUnlimited, isTrue);
      expect(e.limits.requests, isNull);
      expect(e.remaining.requests, isNull);
      expect(e.weekStart, '2026-08-01');
    });

    test('Entitlements.fromJson free monthly', () {
      final e = Entitlements.fromJson({
        'plan': 'free',
        'status': 'active',
        'week_start': '2026-08-01',
        'limits': {
          'requests': 5,
          'requests_unlimited': false,
          'nutritionist_allowed': false,
        },
        'used': {'requests': 3},
        'remaining': {
          'requests': 2,
          'requests_unlimited': false,
        },
      });
      expect(e.monthStart, '2026-08-01');
      expect(e.limits.requests, 5);
      expect(e.used.requests, 3);
      expect(e.remaining.requests, 2);
      expect(e.limits.nutritionistAllowed, isFalse);
    });
  });
}
