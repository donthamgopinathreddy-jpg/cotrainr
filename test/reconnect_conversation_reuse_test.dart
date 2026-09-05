import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/utils/current_relationship_state.dart';

void main() {
  Map<String, dynamic> lead({
    required String id,
    required String status,
    String clientId = 'c1',
    String providerId = 'p1',
  }) => {
    'id': id,
    'client_id': clientId,
    'provider_id': providerId,
    'status': status,
  };

  group('currentRelationshipForPair', () {
    test('A. ended historical lead only → reconnectable (Connect)', () {
      final rel = currentRelationshipForPair(
        leads: [
          lead(id: 'l1', status: 'ended'),
          lead(id: 'l0', status: 'cancelled'),
          lead(id: 'ld', status: 'declined'),
        ],
        clientId: 'c1',
        providerId: 'p1',
      );
      expect(rel.kind, CurrentRelationshipKind.none);
      expect(rel.showConnect, isTrue);
      expect(rel.showMessage, isFalse);
      expect(rel.showPending, isFalse);
      expect(isHistoricalLeadStatus('ended'), isTrue);
    });

    test('B. new requested lead after ended → Pending', () {
      final rel = currentRelationshipForPair(
        leads: [
          lead(id: 'l1', status: 'ended'),
          lead(id: 'l2', status: 'requested'),
        ],
        clientId: 'c1',
        providerId: 'p1',
      );
      expect(rel.kind, CurrentRelationshipKind.pending);
      expect(rel.leadId, 'l2');
      expect(rel.showPending, isTrue);
      expect(rel.showConnect, isFalse);
    });

    test('C. new accepted lead after ended → Connected / Message', () {
      final rel = currentRelationshipForPair(
        leads: [
          lead(id: 'l1', status: 'ended'),
          lead(id: 'l2', status: 'accepted'),
        ],
        clientId: 'c1',
        providerId: 'p1',
      );
      expect(rel.kind, CurrentRelationshipKind.accepted);
      expect(rel.leadId, 'l2');
      expect(rel.showMessage, isTrue);
      expect(rel.showConnect, isFalse);
    });

    test('accepted wins over requested if both present', () {
      final rel = currentRelationshipForPair(
        leads: [
          lead(id: 'lr', status: 'requested'),
          lead(id: 'la', status: 'accepted'),
        ],
        clientId: 'c1',
        providerId: 'p1',
      );
      expect(rel.kind, CurrentRelationshipKind.accepted);
      expect(rel.leadId, 'la');
    });

    test('other pairs are ignored', () {
      final rel = currentRelationshipForPair(
        leads: [
          lead(id: 'x', status: 'accepted', providerId: 'other'),
          lead(id: 'y', status: 'ended'),
        ],
        clientId: 'c1',
        providerId: 'p1',
      );
      expect(rel.kind, CurrentRelationshipKind.none);
    });
  });

  group('reconnect SQL + Flutter contracts', () {
    late String reconnectSql;
    late String messagingSql;
    late String createLeadSql;
    late String discover;
    late String profile;
    late String myClients;
    late String leadsService;
    late String chatScreen;

    setUpAll(() {
      reconnectSql = File(
        'supabase/migrations/20260905_reconnect_conversation_reuse.sql',
      ).readAsStringSync();
      messagingSql = File(
        'supabase/migrations/20260825_messaging_release.sql',
      ).readAsStringSync();
      createLeadSql = File(
        'supabase/migrations/20260808_lead_request_notification_payload.sql',
      ).readAsStringSync();
      discover = File(
        'lib/pages/discover/discover_page.dart',
      ).readAsStringSync();
      profile = File(
        'lib/pages/profile/public_profile_readonly_page.dart',
      ).readAsStringSync();
      myClients = File(
        'lib/pages/provider/provider_my_clients_page.dart',
      ).readAsStringSync();
      leadsService = File('lib/services/leads_service.dart').readAsStringSync();
      chatScreen = File(
        'lib/pages/messaging/chat_screen.dart',
      ).readAsStringSync();
    });

    test('D. create_lead_tx inserts a NEW lead (does not resurrect ended)', () {
      expect(createLeadSql.contains('INSERT INTO public.leads'), isTrue);
      expect(
        createLeadSql.contains("status IN ('requested', 'accepted')"),
        isTrue,
      );
      // Blocks only live statuses — ended history allowed.
      expect(createLeadSql.contains('UPDATE public.leads'), isFalse);
    });

    test('E. existing conversation reused by (client_id, provider_id)', () {
      expect(
        messagingSql.contains('conversations_unique_client_provider_mvp'),
        isTrue,
      );
      expect(
        reconnectSql.contains('client_id = v_lead_record.client_id'),
        isTrue,
      );
      expect(
        reconnectSql.contains('provider_id = v_lead_record.provider_id'),
        isTrue,
      );
      expect(reconnectSql.contains('SET lead_id = p_lead_id'), isTrue);
      // Recover path must not only look up by the new lead_id.
      final acceptBlock = reconnectSql.substring(
        reconnectSql.indexOf("IF p_status = 'accepted' THEN"),
        reconnectSql.indexOf("ELSIF p_status = 'declined' THEN"),
      );
      expect(acceptBlock.contains('AND other_user_id IS NULL'), isTrue);
    });

    test('F/G. chat history kept; composer gates on current accepted', () {
      expect(chatScreen.contains('itemCount: _messages.length'), isTrue);
      expect(chatScreen.contains('shouldShowMessageComposer'), isTrue);
      expect(chatScreen.contains('_loadConversationAccess'), isTrue);
      // Pair-based accepted unlock (no stale lead_id binding).
      expect(reconnectSql.contains('AND l.client_id = c.client_id'), isTrue);
      expect(
        reconnectSql.contains('AND l.provider_id = c.provider_id'),
        isTrue,
      );
      expect(reconnectSql.contains('OR l.id = c.lead_id'), isFalse);
    });

    test('H/I. active lists use accepted only + dedupe', () {
      expect(myClients.contains("l.status == 'accepted'"), isTrue);
      expect(myClients.contains('seenClients'), isTrue);
      expect(leadsService.contains(".eq('status', 'accepted')"), isTrue);
      expect(leadsService.contains('seen.add(p.providerId)'), isTrue);
    });

    test('J. double-action guards present', () {
      expect(discover.contains('_submittingProviders'), isTrue);
      expect(profile.contains('_actionBusy'), isTrue);
      expect(myClients.contains('_busyLeadId'), isTrue);
      expect(
        myClients.contains('if (leadId == null || _busyLeadId != null)'),
        isTrue,
      );
    });

    test('Discover / Public Profile use current-relationship helper', () {
      expect(discover.contains('currentRelationshipFromLeadModels'), isTrue);
      expect(profile.contains('currentRelationshipFromLeadModels'), isTrue);
      expect(profile.contains('CurrentRelationshipKind.accepted'), isTrue);
    });
  });
}
