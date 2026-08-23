import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/services/active_conversation_tracker.dart';
import 'package:cotrainr/utils/chat_message_reconciler.dart';

void main() {
  group('migration SQL contracts', () {
    late String sql;

    setUpAll(() {
      sql = File('supabase/migrations/20260825_messaging_release.sql')
          .readAsStringSync();
    });

    test('send policy uses can_send_message_in_conversation', () {
      expect(sql.contains('Participants can send messages'), isTrue);
      expect(sql.contains('can_send_message_in_conversation'), isTrue);
      expect(sql.contains('conversation_has_accepted_lead'), isTrue);
    });

    test('mark_conversation_messages_read RPC exists', () {
      expect(
        sql.contains(
          'CREATE OR REPLACE FUNCTION public.mark_conversation_messages_read',
        ),
        isTrue,
      );
      expect(sql.contains('p_conversation_id uuid'), isTrue);
    });

    test('notify_on_new_message trigger and preference', () {
      expect(
        sql.contains('CREATE OR REPLACE FUNCTION public.notify_on_new_message'),
        isTrue,
      );
      expect(sql.contains('trg_notify_on_new_message'), isTrue);
      expect(sql.contains("'type', 'message'"), isTrue);
    });

    test('unique client-provider index', () {
      expect(
        sql.contains('conversations_unique_client_provider_mvp'),
        isTrue,
      );
      expect(sql.contains('CREATE UNIQUE INDEX'), isTrue);
    });

    test('notification_messages preference column', () {
      expect(sql.contains('notification_messages'), isTrue);
      expect(
        sql.contains(
          'ADD COLUMN IF NOT EXISTS notification_messages BOOLEAN NOT NULL DEFAULT true',
        ),
        isTrue,
      );
    });
  });

  group('ActiveConversationTracker', () {
    tearDown(() {
      ActiveConversationTracker.instance.clear();
    });

    test('setActive / isActive / clear', () {
      final t = ActiveConversationTracker.instance;
      expect(t.activeConversationId, isNull);
      expect(t.isActive('c1'), isFalse);

      t.setActive('c1');
      expect(t.activeConversationId, 'c1');
      expect(t.isActive('c1'), isTrue);
      expect(t.isActive('c2'), isFalse);

      t.clear();
      expect(t.activeConversationId, isNull);
      expect(t.isActive('c1'), isFalse);
    });

    test('setActive null clears', () {
      final t = ActiveConversationTracker.instance;
      t.setActive('x');
      t.setActive(null);
      expect(t.activeConversationId, isNull);
    });
  });

  group('reconciler readAt', () {
    test('applyReadAt updates Seen', () {
      final r = ChatMessageReconciler();
      r.upsertCanonical(
        messageId: 'm1',
        text: 'hello',
        isSent: true,
        time: '10:00',
      );
      final at = DateTime.parse('2026-08-23T10:01:00Z');
      expect(r.applyReadAt('m1', at), isTrue);
      expect(r.messages.single.isSeen, isTrue);
      expect(r.messages.single.readAt, at);
    });
  });

  group('chat_screen double-send contract', () {
    test('contains _textSending guard', () {
      final src = File('lib/pages/messaging/chat_screen.dart').readAsStringSync();
      expect(src.contains('bool _textSending = false'), isTrue);
      expect(src.contains('if (_textSending) return'), isTrue);
      expect(src.contains('_textSending = true'), isTrue);
      expect(src.contains('_textSending = false'), isTrue);
    });
  });

  group('messaging_page fake delete absent', () {
    test('no long-press delete / undo snackbar', () {
      final src =
          File('lib/pages/messaging/messaging_page.dart').readAsStringSync();
      expect(src.contains('_deleteConversation'), isFalse);
      expect(src.contains('_deletedConversation'), isFalse);
      expect(src.contains('Conversation deleted'), isFalse);
      expect(src.contains('onLongPress'), isFalse);
      expect(src.contains('No messages yet'), isTrue);
    });
  });

  group('message preference in notifications_page', () {
    test('Message notifications toggle wired', () {
      final src = File('lib/pages/profile/settings/notifications_page.dart')
          .readAsStringSync();
      expect(src.contains('Message notifications'), isTrue);
      expect(src.contains('messageNotifications'), isTrue);
      expect(
        src.contains('Alerts when you receive a chat message'),
        isTrue,
      );
      expect(src.contains('registerToken'), isTrue);
    });

    test('FitnessNotificationPreferences has messageNotifications', () {
      final src =
          File('lib/services/fitness_notification_preferences_service.dart')
              .readAsStringSync();
      expect(src.contains('messageNotifications'), isTrue);
      expect(src.contains('notification_messages') || src.contains('messages:'),
          isTrue);
    });

    test('ProfileRepository maps notification_messages', () {
      final src =
          File('lib/repositories/profile_repository.dart').readAsStringSync();
      expect(src.contains('notification_messages'), isTrue);
      expect(src.contains("'messages'"), isTrue);
    });
  });

  group('timestamp outside bubble contract', () {
    test('metadata · Seen outside bubble', () {
      final src = File('lib/pages/messaging/chat_screen.dart').readAsStringSync();
      expect(src.contains(' · Seen'), isTrue);
      expect(src.contains('AnimatedSwitcher'), isTrue);
      expect(src.contains('bool get isSeen'), isTrue);
      expect(src.contains('DateTime? readAt'), isTrue);
    });
  });

  group('push_deliver message pref skip', () {
    test('skips when notification_messages false', () {
      final src =
          File('supabase/functions/_shared/push_deliver.ts').readAsStringSync();
      expect(src.contains('notification_messages === false'), isTrue);
      expect(src.contains('user_disabled_message_push'), isTrue);
      expect(src.contains("type === \"message\""), isTrue);
    });
  });

  group('push_notification_service message type', () {
    test('handles type message with ActiveConversationTracker skip', () {
      final src = File('lib/services/push_notification_service.dart')
          .readAsStringSync();
      expect(src.contains('MessageNotificationActions'), isTrue);
      expect(src.contains('ActiveConversationTracker'), isTrue);
      expect(src.contains('isMessageType'), isTrue);
      expect(src.contains('isActive'), isTrue);
    });

    test('MessagePendingNavigation + local router message routes', () {
      final pending =
          File('lib/services/message_pending_navigation.dart').readAsStringSync();
      expect(pending.contains('pending_message_conversation_route'), isTrue);
      expect(pending.contains('/messaging/chat/'), isTrue);

      final router =
          File('lib/services/local_notification_router.dart').readAsStringSync();
      expect(router.contains('MessageNotificationActions'), isTrue);

      final cleanup =
          File('lib/services/notification_session_cleanup.dart').readAsStringSync();
      expect(cleanup.contains('MessagePendingNavigation.clear'), isTrue);
      expect(cleanup.contains('ActiveConversationTracker'), isTrue);
    });

    test('messages repository uses mark-read and create RPCs', () {
      final src =
          File('lib/repositories/messages_repository.dart').readAsStringSync();
      expect(src.contains('mark_conversation_messages_read'), isTrue);
      expect(
        src.contains('create_or_find_provider_client_conversation'),
        isTrue,
      );
      expect(src.contains('subscribeToMessageUpdates'), isTrue);
      expect(src.contains('rethrow'), isTrue);
    });
  });
}
