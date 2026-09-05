import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/services/messaging_policy_service.dart';
import 'package:cotrainr/utils/messaging_error_messages.dart';

void main() {
  late String chatScreen;
  late String policy;
  late String messagingSql;

  setUpAll(() {
    chatScreen = File(
      'lib/pages/messaging/chat_screen.dart',
    ).readAsStringSync();
    policy = File(
      'lib/services/messaging_policy_service.dart',
    ).readAsStringSync();
    messagingSql = File(
      'supabase/migrations/20260825_messaging_release.sql',
    ).readAsStringSync();
  });

  group('MessagingPolicyService ended / active composer gates', () {
    test('A. accepted relationship -> composer available', () {
      expect(
        MessagingPolicyService.shouldShowMessageComposer(
          canSend: true,
          eitherBlocked: false,
        ),
        isTrue,
      );
      expect(
        MessagingPolicyService.shouldShowEndedConnectionBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: true,
          eitherBlocked: false,
        ),
        isFalse,
      );
    });

    test('B/C. ended -> history path keeps banner; composer unavailable', () {
      expect(
        MessagingPolicyService.shouldShowMessageComposer(
          canSend: false,
          eitherBlocked: false,
        ),
        isFalse,
      );
      expect(
        MessagingPolicyService.shouldShowEndedConnectionBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: false,
          eitherBlocked: false,
        ),
        isTrue,
      );
    });

    test('blocked pair does not look like ended connection', () {
      expect(
        MessagingPolicyService.shouldShowEndedConnectionBanner(
          hasConversationRow: true,
          isProviderClient: true,
          canSend: false,
          eitherBlocked: true,
        ),
        isFalse,
      );
      expect(
        MessagingPolicyService.shouldShowMessageComposer(
          canSend: false,
          eitherBlocked: true,
        ),
        isFalse,
      );
    });

    test(
      'J. no conversation row -> no ended banner (empty/history still ok)',
      () {
        expect(
          MessagingPolicyService.shouldShowEndedConnectionBanner(
            hasConversationRow: false,
            isProviderClient: true,
            canSend: false,
            eitherBlocked: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('symmetric send eligibility (D–G)', () {
    test('policy no longer short-circuits providers by role alone', () {
      expect(policy.contains('if (me == providerId) return true'), isFalse);
      expect(
        policy.contains('Both **member and provider** require') ||
            policy.contains('providers must also have a current accepted lead'),
        isTrue,
      );
      expect(policy.contains('can_send_message_in_conversation'), isTrue);
      expect(policy.contains('hasAcceptedLead('), isTrue);
    });

    test('server RPC gates both roles on conversation_has_accepted_lead', () {
      expect(messagingSql.contains('can_send_message_in_conversation'), isTrue);
      expect(messagingSql.contains('conversation_has_accepted_lead'), isTrue);
      final fn = messagingSql.substring(
        messagingSql.indexOf(
          'CREATE OR REPLACE FUNCTION public.can_send_message_in_conversation',
        ),
        messagingSql.indexOf(
          'REVOKE ALL ON FUNCTION public.can_send_message_in_conversation',
        ),
      );
      expect(fn.contains('conversation_has_accepted_lead'), isTrue);
      // No role-based early allow for provider.
      expect(
        fn.toLowerCase().contains('provider_id = p_user_id then return true'),
        isFalse,
      );
    });
  });

  group('ChatScreen ended UX + stale send (H/I)', () {
    test('ended banner copy and composer removed when not allowed', () {
      expect(chatScreen.contains('Connection ended'), isTrue);
      expect(
        chatScreen.contains('You can still view your previous messages.'),
        isTrue,
      );
      expect(chatScreen.contains('shouldShowMessageComposer'), isTrue);
      expect(chatScreen.contains('_isEndedConnection'), isTrue);
      expect(chatScreen.contains('WidgetsBindingObserver'), isTrue);
      expect(chatScreen.contains('didChangeAppLifecycleState'), isTrue);
      expect(chatScreen.contains('_handleSendDeniedMaybeEnded'), isTrue);
      expect(
        chatScreen.contains('MessagingErrorMessages.connectionEnded'),
        isTrue,
      );
      // Disabled readOnly composer path removed in favor of full replacement.
      expect(
        chatScreen.contains("hintText: _canSend ? 'Type a message...'"),
        isFalse,
      );
      expect(
        chatScreen.contains(
          'Viewing only: messaging is available after this provider accepts',
        ),
        isFalse,
      );
    });

    test('I. connectionEnded never embeds raw backend exception text', () {
      expect(
        MessagingErrorMessages.connectionEnded.contains('Postgrest'),
        isFalse,
      );
      expect(
        MessagingErrorMessages.connectionEnded.contains('Exception'),
        isFalse,
      );
      expect(MessagingErrorMessages.connectionEnded.contains('RLS'), isFalse);
      expect(
        MessagingErrorMessages.looksLikeEndedConnectionDenial(
          Exception('no_accepted_lead'),
        ),
        isTrue,
      );
      expect(
        MessagingErrorMessages.looksLikeEndedConnectionDenial(
          Exception(
            'new row violates row-level security policy for table messages',
          ),
        ),
        isTrue,
      );
      expect(
        MessagingErrorMessages.looksLikeEndedConnectionDenial(
          Exception('SocketException: Failed host lookup'),
        ),
        isFalse,
      );
      // Heuristic inspects error but UI constant stays sanitized.
      const raw = 'PostgrestException(message: no_accepted_lead, code: PGRST)';
      expect(
        MessagingErrorMessages.looksLikeEndedConnectionDenial(raw),
        isTrue,
      );
      expect(MessagingErrorMessages.connectionEnded.contains(raw), isFalse);
      expect(
        MessagingErrorMessages.connectionEnded,
        'This connection has ended. You can still view previous messages.',
      );
    });

    test('H. send-null / catch paths re-check eligibility', () {
      expect(chatScreen.contains('_handleSendDeniedMaybeEnded'), isTrue);
      expect(chatScreen.contains('await _loadConversationAccess()'), isTrue);
      final handler = chatScreen.substring(
        chatScreen.indexOf('Future<bool> _handleSendDeniedMaybeEnded'),
        chatScreen.indexOf('Future<void> _loadConversationAccess'),
      );
      expect(handler.contains('_loadConversationAccess'), isTrue);
      expect(
        handler.contains('MessagingErrorMessages.connectionEnded'),
        isTrue,
      );
    });

    test('message list / history still rendered regardless of canSend', () {
      // History is the _messages ListView; composer gating is separate.
      expect(chatScreen.contains('itemCount: _messages.length'), isTrue);
      expect(chatScreen.contains('_ChatBubble'), isTrue);
      expect(chatScreen.contains('media_url'), isTrue);
    });
  });

  group('conversation list Ended badge', () {
    test('not implemented via N+1 accepted-lead queries', () {
      final page = File(
        'lib/pages/messaging/messaging_page.dart',
      ).readAsStringSync();
      expect(page.contains("status', 'accepted'"), isFalse);
      expect(page.contains('hasAcceptedLead'), isFalse);
      expect(page.contains("'Ended'"), isFalse);
    });
  });
}
