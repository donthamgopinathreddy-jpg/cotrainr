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
        'ok': true,
        'plan': 'premium',
        'plan_display_name': 'Ultimate',
        'subscription_status': 'active',
        'period_key': 'cal:2026-08',
        'period_kind': 'calendar_month',
        'period_start': '2026-08-01T00:00:00Z',
        'period_end': '2026-09-01T00:00:00Z',
        'limit': null,
        'unlimited': true,
        'used': 0,
        'remaining': null,
        'nutritionist_allowed': true,
      });
      expect(e.plan, 'premium');
      expect(e.planDisplayName, 'Ultimate');
      expect(e.subscriptionStatus, 'active');
      expect(e.periodKey, 'cal:2026-08');
      expect(e.periodKind, 'calendar_month');
      expect(e.limit, isNull);
      expect(e.unlimited, isTrue);
      expect(e.used, 0);
      expect(e.remaining, isNull);
      expect(e.nutritionistAllowed, isTrue);
      expect(e.periodStart, isNotNull);
      expect(e.periodEnd, isNotNull);
      expect(e.periodStart!.toUtc(), DateTime.utc(2026, 8, 1));
      expect(e.periodEnd!.toUtc(), DateTime.utc(2026, 9, 1));
    });

    test('Entitlements.fromJson free monthly', () {
      final e = Entitlements.fromJson({
        'ok': true,
        'plan': 'free',
        'plan_display_name': 'Free',
        'subscription_status': 'active',
        'period_key': 'cal:2026-08',
        'period_kind': 'calendar_month',
        'period_start': '2026-08-01T00:00:00Z',
        'period_end': '2026-09-01T00:00:00Z',
        'limit': 5,
        'unlimited': false,
        'used': 3,
        'remaining': 2,
        'nutritionist_allowed': false,
      });
      expect(e.plan, 'free');
      expect(e.planDisplayName, 'Free');
      expect(e.subscriptionStatus, 'active');
      expect(e.periodKey, 'cal:2026-08');
      expect(e.periodKind, 'calendar_month');
      expect(e.limit, 5);
      expect(e.unlimited, isFalse);
      expect(e.used, 3);
      expect(e.remaining, 2);
      expect(e.nutritionistAllowed, isFalse);
      expect(e.periodStart, isNotNull);
      expect(e.periodEnd, isNotNull);
      expect(e.periodStart!.toUtc(), DateTime.utc(2026, 8, 1));
      expect(e.periodEnd!.toUtc(), DateTime.utc(2026, 9, 1));
    });

    test('Entitlements.fromJson rejects ok false', () {
      expect(
        () => Entitlements.fromJson({
          'ok': false,
          'plan': 'free',
        }),
        throwsA(isA<Exception>()),
      );
    });
  });
}
