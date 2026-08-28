import 'dart:io';

import 'package:cotrainr/repositories/messages_repository.dart';
import 'package:cotrainr/utils/chat_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the shape `MessagesRepository.fetchConversations` returns.
Map<String, dynamic> conv(
  String id, {
  String? lastMessageAt,
  String? lastMessageCreatedAt,
  String? updatedAt,
  String? createdAt,
  String content = 'hi',
  String? deletedForEveryoneAt,
}) {
  return {
    'id': id,
    'conversation': {
      'id': id,
      'created_at': createdAt ?? '2020-01-01T00:00:00Z',
      'updated_at': updatedAt,
      'last_message_at': lastMessageAt,
    },
    'lastMessage': lastMessageCreatedAt == null
        ? null
        : {
            'id': 'm-$id',
            'content': content,
            'created_at': lastMessageCreatedAt,
            'deleted_for_everyone_at': deletedForEveryoneAt,
          },
    'unreadCount': 0,
    'otherUser': const {'full_name': 'Other'},
    'updatedAt': updatedAt,
    'lastMessageAt': lastMessageAt,
  };
}

List<String> idsOf(List<Map<String, dynamic>> list) =>
    list.map((c) => c['id'] as String).toList();

String readSource(String relativePath) =>
    File(relativePath).readAsStringSync();

void main() {
  group('conversation ordering', () {
    test('incoming message moves its conversation to position 1', () {
      // `old` was created most recently but `fresh` just received a message.
      final sorted = MessagesRepository.sortConversationsByActivity([
        conv('old',
            createdAt: '2026-08-28T12:00:00Z',
            lastMessageAt: '2026-08-28T10:00:00Z',
            lastMessageCreatedAt: '2026-08-28T10:00:00Z'),
        conv('fresh',
            createdAt: '2020-01-01T00:00:00Z',
            lastMessageAt: '2026-08-28T11:30:00Z',
            lastMessageCreatedAt: '2026-08-28T11:30:00Z'),
      ]);

      expect(idsOf(sorted), ['fresh', 'old']);
    });

    test('outgoing message moves its conversation to position 1', () {
      final before = MessagesRepository.sortConversationsByActivity([
        conv('a', lastMessageAt: '2026-08-28T09:00:00Z'),
        conv('b', lastMessageAt: '2026-08-28T08:00:00Z'),
      ]);
      expect(idsOf(before), ['a', 'b']);

      // User sends into `b`; the trigger bumps last_message_at.
      final after = MessagesRepository.sortConversationsByActivity([
        conv('a', lastMessageAt: '2026-08-28T09:00:00Z'),
        conv('b', lastMessageAt: '2026-08-28T09:05:00Z'),
      ]);
      expect(idsOf(after), ['b', 'a']);
    });

    test('a repeated realtime event does not duplicate a conversation', () {
      final sorted = MessagesRepository.sortConversationsByActivity([
        conv('a', lastMessageAt: '2026-08-28T09:00:00Z'),
        conv('a', lastMessageAt: '2026-08-28T09:00:00Z'),
        conv('b', lastMessageAt: '2026-08-28T08:00:00Z'),
      ]);

      expect(idsOf(sorted), ['a', 'b']);
    });

    test('never sorts by conversation created_at', () {
      // Newest created_at, oldest activity: must sort last.
      final sorted = MessagesRepository.sortConversationsByActivity([
        conv('newest_created',
            createdAt: '2026-08-28T23:00:00Z',
            lastMessageAt: '2020-01-01T00:00:00Z'),
        conv('active', lastMessageAt: '2026-08-28T09:00:00Z'),
      ]);

      expect(idsOf(sorted), ['active', 'newest_created']);
    });

    test('falls back to the last message timestamp when last_message_at is '
        'missing (pre-migration deployments)', () {
      final sorted = MessagesRepository.sortConversationsByActivity([
        conv('stale',
            updatedAt: '2026-08-28T07:00:00Z',
            lastMessageCreatedAt: '2026-08-28T07:00:00Z'),
        conv('recent',
            updatedAt: '2026-08-28T06:00:00Z',
            lastMessageCreatedAt: '2026-08-28T12:00:00Z'),
      ]);

      expect(idsOf(sorted), ['recent', 'stale']);
    });

    test('conversations with no activity sort last rather than crashing', () {
      final sorted = MessagesRepository.sortConversationsByActivity([
        conv('empty'),
        conv('active', lastMessageAt: '2026-08-28T09:00:00Z'),
      ]);

      expect(idsOf(sorted), ['active', 'empty']);
    });

    test('identical timestamps break the tie on id descending', () {
      const at = '2026-08-28T09:00:00Z';
      final forward = MessagesRepository.sortConversationsByActivity([
        conv('aaa', lastMessageAt: at),
        conv('ccc', lastMessageAt: at),
        conv('bbb', lastMessageAt: at),
      ]);
      final reversed = MessagesRepository.sortConversationsByActivity([
        conv('bbb', lastMessageAt: at),
        conv('ccc', lastMessageAt: at),
        conv('aaa', lastMessageAt: at),
      ]);

      expect(idsOf(forward), ['ccc', 'bbb', 'aaa']);
      expect(idsOf(forward), idsOf(reversed),
          reason: 'input order must not affect the result');
    });

    test('conversations with no activity are ordered deterministically', () {
      final sorted = MessagesRepository.sortConversationsByActivity([
        conv('aaa'),
        conv('bbb'),
      ]);

      expect(idsOf(sorted), ['bbb', 'aaa']);
    });
  });

  group('delete for everyone — client state', () {
    ChatMessageReconciler seeded() {
      return ChatMessageReconciler()
        ..replaceAll(const [
          ReconciledChatMessage(
            text: 'secret plan',
            isSent: true,
            time: '10:00',
            messageId: 'm1',
            imageUrl: 'https://example.test/private.jpg',
            documentUrl: 'https://example.test/private.pdf',
            documentName: 'private.pdf',
          ),
          ReconciledChatMessage(
            text: 'ok',
            isSent: false,
            time: '10:01',
            messageId: 'm2',
          ),
        ]);
    }

    test('sender UI shows the tombstone instead of the original', () {
      final r = seeded();
      expect(r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28)), isTrue);

      final m = r.messages.firstWhere((m) => m.messageId == 'm1');
      expect(m.isDeletedForEveryone, isTrue);
      expect(m.text, kDeletedMessageText);
      expect(m.text, 'This message was deleted');
      expect(r.messages.length, 2, reason: 'row remains, content does not');
    });

    test('recipient UI shows the tombstone when the realtime UPDATE arrives',
        () {
      final r = ChatMessageReconciler()
        ..replaceAll(const [
          ReconciledChatMessage(
            text: 'secret plan',
            isSent: false,
            time: '10:00',
            messageId: 'm1',
          ),
        ]);

      expect(r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28)), isTrue);
      expect(r.messages.single.text, kDeletedMessageText);
      expect(r.messages.single.isSent, isFalse);
    });

    test('attachments are dropped so the chat UI cannot open them', () {
      final r = seeded();
      r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28));

      final m = r.messages.firstWhere((m) => m.messageId == 'm1');
      expect(m.imageUrl, isNull);
      expect(m.videoUrl, isNull);
      expect(m.documentUrl, isNull);
      expect(m.documentName, isNull);
      expect(m.isDocument, isFalse);
    });

    test('original content is unrecoverable from client state', () {
      final r = seeded();
      r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28));

      final serialized = r.messages
          .map((m) => '${m.text}|${m.imageUrl}|${m.documentUrl}')
          .join('\n');
      expect(serialized.contains('secret plan'), isFalse);
      expect(serialized.contains('private.jpg'), isFalse);
    });

    test('marking twice is idempotent', () {
      final r = seeded();
      expect(r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28)), isTrue);
      expect(r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 29)), isFalse);
      expect(r.messages.length, 2);
    });

    test('a refetch that returns the redacted row keeps the tombstone', () {
      final r = seeded();
      r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28));

      // Refresh: server returns content='' plus deleted_for_everyone_at.
      r.replaceAll([
        ReconciledChatMessage(
          text: kDeletedMessageText,
          isSent: true,
          time: '10:00',
          messageId: 'm1',
          deletedForEveryoneAt: DateTime.utc(2026, 8, 28),
        ),
      ]);

      expect(r.messages.single.isDeletedForEveryone, isTrue);
      expect(r.messages.single.text, kDeletedMessageText);
    });
  });

  group('delete for me — client state', () {
    test('removes the bubble and releases the id for a later refetch', () {
      final r = ChatMessageReconciler()
        ..replaceAll(const [
          ReconciledChatMessage(
              text: 'a', isSent: true, time: '10:00', messageId: 'm1'),
          ReconciledChatMessage(
              text: 'b', isSent: false, time: '10:01', messageId: 'm2'),
        ]);

      expect(r.removeCanonical('m1'), isTrue);
      expect(r.messages.map((m) => m.messageId), ['m2']);
      expect(r.canonicalIds.contains('m1'), isFalse);
    });

    test('does not mark the message deleted for everyone', () {
      final r = ChatMessageReconciler()
        ..replaceAll(const [
          ReconciledChatMessage(
              text: 'a', isSent: true, time: '10:00', messageId: 'm1'),
        ]);

      r.removeCanonical('m1');
      expect(r.messages, isEmpty);
      expect(r.markDeletedForEveryone('m1', DateTime.utc(2026, 8, 28)), isFalse);
    });
  });

  group('server contract — migration', () {
    late String sql;

    setUpAll(() {
      sql = readSource(
        'supabase/migrations/20260828143000_messaging_ordering_and_delete.sql',
      );
    });

    test('ordering is maintained by a trigger, not by the client', () {
      expect(sql, contains('ADD COLUMN IF NOT EXISTS last_message_at'));
      expect(sql, contains('CREATE TRIGGER trg_messages_touch_conversation'));
      expect(sql, contains('AFTER INSERT ON public.messages'));
      expect(sql, contains('touch_conversation_last_message'));
    });

    test('the ordering trigger cannot roll back a message send', () {
      expect(sql, contains('EXCEPTION WHEN OTHERS THEN'));
      // RAISE WARNING (not EXCEPTION) keeps the transaction alive.
      expect(sql, contains("RAISE WARNING 'touch_conversation_last_message"));
      expect(sql, contains('SQLERRM, SQLSTATE'));
    });

    test('the trigger log leaks no message content', () {
      final fn = sql.substring(
        sql.indexOf('CREATE OR REPLACE FUNCTION '
            'public.touch_conversation_last_message()'),
      );
      final body = fn.substring(0, fn.indexOf(r'$$;'));
      expect(body.contains('NEW.content'), isFalse);
      expect(body.contains('NEW.media_url'), isFalse);
    });

    test('ordering is deterministic on ties', () {
      expect(
        sql,
        contains('ON public.conversations (last_message_at DESC NULLS LAST, '
            'id DESC)'),
      );
      expect(sql, contains('ALTER COLUMN last_message_at SET DEFAULT NOW()'));
    });

    test('concurrent deletes of the same message are serialised', () {
      expect(
        sql,
        contains('SELECT * INTO m FROM public.messages '
            'WHERE id = p_message_id FOR UPDATE'),
      );
    });

    test('the archive keeps its foreign key to messages', () {
      expect(
        sql,
        contains('message_id UUID PRIMARY KEY REFERENCES public.messages(id) '
            'ON DELETE CASCADE'),
      );
    });

    test('the ordering trigger is separate from the push notification writer',
        () {
      // Only the executable body matters; the header comment names the
      // pipeline it deliberately leaves alone.
      final body = sql.substring(sql.indexOf('BEGIN;'));
      expect(body.contains('notify_on_new_message'), isFalse);
      expect(body.contains('net.http_post'), isFalse);
      expect(body.contains('send-push-notification'), isFalse);
    });

    test('delete-for-everyone is a SECURITY DEFINER RPC, not a client update',
        () {
      expect(sql, contains('CREATE OR REPLACE FUNCTION '
          'public.delete_message_for_everyone(p_message_id UUID)'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
    });

    test('only the sender may delete for everyone', () {
      expect(sql, contains('m.sender_id IS DISTINCT FROM v_uid'));
      expect(sql, contains('not_message_sender'));
    });

    test('a non-participant is rejected', () {
      expect(sql, contains('user_is_conversation_participant(c, v_uid)'));
      expect(sql, contains('not_conversation_participant'));
    });

    test('the recipient cannot fetch the original content afterwards', () {
      // The row is redacted in place, so a normal SELECT returns nothing.
      expect(sql, contains("SET content                 = ''"));
      expect(sql, contains('media_url               = NULL'));
      expect(sql, contains('media_kind              = NULL'));
      expect(sql, contains('media_file_name         = NULL'));
      expect(sql, contains('deleted_for_everyone_at = NOW()'));
    });

    test('the original is archived out of client reach for audit', () {
      expect(sql, contains('public.message_content_archive'));
      expect(
        sql,
        contains('ALTER TABLE public.message_content_archive '
            'ENABLE ROW LEVEL SECURITY'),
      );
      expect(
        sql,
        contains('REVOKE ALL ON public.message_content_archive '
            'FROM PUBLIC, anon, authenticated'),
      );
    });

    test('delete-for-me is private to the acting user', () {
      expect(sql, contains('CREATE TABLE IF NOT EXISTS public.message_hidden'));
      expect(sql,
          contains('ALTER TABLE public.message_hidden ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('USING (user_id = auth.uid())'));
      // Never grants a client the ability to hide a message for someone else.
      expect(sql.contains('GRANT INSERT ON public.message_hidden'), isFalse);
    });

    test('delete-for-me does not touch the shared message row', () {
      final hideFn = sql.substring(sql.indexOf('public.hide_message_for_me'));
      expect(hideFn.contains('UPDATE public.messages'), isFalse);
      expect(hideFn, contains('INSERT INTO public.message_hidden'));
    });

    test('anon cannot execute either delete RPC', () {
      expect(
        sql,
        contains('REVOKE ALL ON FUNCTION '
            'public.delete_message_for_everyone(UUID) FROM PUBLIC, anon'),
      );
      expect(
        sql,
        contains('REVOKE ALL ON FUNCTION '
            'public.hide_message_for_me(UUID) FROM PUBLIC, anon'),
      );
    });

    test('does not weaken existing messaging RLS', () {
      expect(sql.contains('DROP POLICY IF EXISTS "Participants'), isFalse);
      expect(sql.contains('DISABLE ROW LEVEL SECURITY'), isFalse);
      expect(sql.contains('DROP TABLE'), isFalse);
      expect(sql.contains('DELETE FROM public.messages'), isFalse);
    });
  });

  group('source contract — no local-only deletion', () {
    test('chat screen deletes through the repository, not by list mutation',
        () {
      final src = readSource('lib/pages/messaging/chat_screen.dart');
      expect(src.contains('_messages.removeAt(index)'), isFalse,
          reason: 'delete must not be a local list mutation');
      expect(src, contains('_messagesRepo.deleteMessageForEveryone'));
      expect(src, contains('_messagesRepo.hideMessageForMe'));
      expect(src, contains('markDeletedForEveryone'));
    });

    test('the repository calls the secure RPCs', () {
      final src = readSource('lib/repositories/messages_repository.dart');
      expect(src, contains("'delete_message_for_everyone'"));
      expect(src, contains("'hide_message_for_me'"));
      expect(src, contains("params: {'p_message_id': messageId}"));
    });

    test('the chats list no longer orders by the unmaintained updated_at bump',
        () {
      final src = readSource('lib/repositories/messages_repository.dart');
      expect(src, contains("order('last_message_at', ascending: false"));
      expect(src, contains("order('id', ascending: false)"),
          reason: 'server ordering must match the in-memory tiebreaker');
      // The client-side conversations UPDATE was a silent no-op under RLS.
      expect(
        src.contains("update({'updated_at': DateTime.now().toIso8601String()})"),
        isFalse,
      );
    });
  });
}
