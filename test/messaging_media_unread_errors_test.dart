import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/services/chat_media_storage.dart';
import 'package:cotrainr/utils/messaging_error_messages.dart';

/// Contract tests for the three messaging production bugs:
/// chat attachment storage, unread read-state persistence, and raw backend
/// errors reaching the UI.
void main() {
  String read(String path) => File(path).readAsStringSync();

  late String chatScreen;
  late String repo;
  late String messagingPage;
  late String storageService;
  late String bucketSql;

  setUpAll(() {
    chatScreen = read('lib/pages/messaging/chat_screen.dart');
    repo = read('lib/repositories/messages_repository.dart');
    messagingPage = read('lib/pages/messaging/messaging_page.dart');
    storageService = read('lib/services/storage_service.dart');
    bucketSql =
        read('supabase/migrations/20260815_chat_attachments_private_bucket.sql');
  });

  // ------------------------------------------------------------------
  // MEDIA
  // ------------------------------------------------------------------
  group('chat media storage', () {
    test('1. uploads target the private chat-attachments bucket', () {
      expect(ChatMediaStorage.bucket, 'chat-attachments');
      expect(storageService.contains('ChatMediaStorage.bucket'), isTrue);
    });

    test('1b. chat media never falls back to the public posts bucket', () {
      final upload = storageService.substring(
        storageService.indexOf('Future<String?> uploadChatMedia'),
        storageService.indexOf('String _guessChatContentType'),
      );
      expect(
        upload.contains("'posts'"),
        isFalse,
        reason: 'private chat media must never be written to a public bucket',
      );
    });

    test('1c. the bucket is created private with a mime allow-list', () {
      expect(bucketSql.contains("'chat-attachments'"), isTrue);
      final insert = bucketSql.substring(
        bucketSql.indexOf('INSERT INTO storage.buckets'),
        bucketSql.indexOf('ON CONFLICT'),
      );
      expect(insert.contains('false'), isTrue);
      expect(bucketSql.contains('public = false'), isTrue);
      expect(bucketSql.contains('allowed_mime_types'), isTrue);
    });

    test('2. a successful upload stores a chat:// ref, not a public URL', () {
      expect(ChatMediaStorage.storedRefForPath('u/chat/c/f.jpg'),
          'chat://u/chat/c/f.jpg');
      expect(ChatMediaStorage.isPrivateRef('chat://u/chat/c/f.jpg'), isTrue);
      expect(
        ChatMediaStorage.isPrivateRef('https://x/object/public/posts/a.jpg'),
        isFalse,
      );
      expect(storageService.contains('ChatMediaStorage.storedRefForPath'),
          isTrue);
    });

    test('3. retry reuses the optimistic bubble id, so no duplicate row', () {
      final retry = chatScreen.substring(
        chatScreen.indexOf('Future<void> _retryUpload'),
        chatScreen.indexOf('Future<void> _pickGallery'),
      );
      expect(retry.contains('existingLocalId: localId'), isTrue);
      // Retry must go through the same send path, not a second insert.
      expect(retry.contains('_sendAttachmentMessage'), isTrue);
      expect(retry.contains('.insert('), isFalse);
    });

    test('4 + 5. documents and video use the same private upload path', () {
      expect(storageService.contains("mediaKind == 'document'"), isTrue);
      expect(bucketSql.contains('application/pdf'), isTrue);
      expect(bucketSql.contains('video/mp4'), isTrue);
      expect(chatScreen.contains('documentPath'), isTrue);
      expect(chatScreen.contains('videoPath'), isTrue);
    });

    test('6. storage policies restrict reads to conversation participants', () {
      final selectPolicy = bucketSql.substring(
        bucketSql.indexOf('"Participants can read chat attachments"'),
      );
      expect(selectPolicy.contains('TO authenticated'), isTrue);
      expect(selectPolicy.contains('FROM public.conversations c'), isTrue);
      expect(selectPolicy.contains('c.client_id = auth.uid()'), isTrue);
      expect(selectPolicy.contains('c.provider_id = auth.uid()'), isTrue);
      // Path segment 3 is the conversation id being authorized.
      expect(
        selectPolicy.contains('(storage.foldername(name))[3]'),
        isTrue,
      );
    });

    test('6b. uploads are confined to the sender\'s own folder', () {
      final insertPolicy = bucketSql.substring(
        bucketSql.indexOf('"Participants can upload chat attachments"'),
        bucketSql.indexOf('"Participants can read chat attachments"'),
      );
      expect(
        insertPolicy.contains('(storage.foldername(name))[1] = auth.uid()::text'),
        isTrue,
      );
    });

    test('7. deleted-for-everyone media is never resolved', () {
      expect(
        chatScreen.contains(
          '// Server already redacted the row; never resolve or render its media.',
        ),
        isTrue,
      );
      // resolveMessageMedia only signs private refs.
      final resolve = read('lib/services/chat_media_storage.dart');
      expect(resolve.contains('!isPrivateRef(url)) return message'), isTrue);
    });

    test('8. a failed upload keeps the bubble in a retryable state', () {
      expect(chatScreen.contains('uploadStatus: ChatUploadStatus.failed'),
          isTrue);
      expect(chatScreen.contains('onRetry: message.uploadStatus == ChatUploadStatus.failed'),
          isTrue);
    });

    test('9. a successful retry confirms the optimistic bubble', () {
      expect(chatScreen.contains('_reconciler.confirmOptimistic('), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // UNREAD
  // ------------------------------------------------------------------
  group('unread read-state', () {
    test('10 + 11. unread counts inbound messages with a null read_at', () {
      expect(repo.contains(".isFilter('read_at', null)"), isTrue);
      expect(repo.contains(".neq('sender_id', _currentUserId!)"), isTrue);
    });

    test('12. opening a conversation persists read state server-side', () {
      expect(repo.contains("'mark_conversation_messages_read'"), isTrue);
      expect(chatScreen.contains('_messagesRepo.markConversationRead('), isTrue);
    });

    test('13 + 14. returning to Chats awaits mark-read before refetching', () {
      final onTap = messagingPage.substring(
        messagingPage.indexOf('onTap: () async {'),
      );
      final markAt = onTap.indexOf('await _messagesRepo.markConversationRead(');
      final loadAt = onTap.indexOf('await _loadConversations(showLoading: false)');
      expect(markAt, greaterThan(-1));
      expect(loadAt, greaterThan(-1));
      expect(
        markAt,
        lessThan(loadAt),
        reason: 'refetching first re-reads pre-mark state and the badge returns',
      );
    });

    test('15. the badge is derived from the server, never local-only', () {
      // The list renders whatever the server fetch produced.
      expect(messagingPage.contains("convData['unreadCount'] as int? ?? 0"),
          isTrue);
      expect(
        messagingPage.contains('setState(unreadCount = 0)'),
        isFalse,
      );
    });

    test('16. a sender never counts their own message as unread', () {
      expect(repo.contains(".neq('sender_id', _currentUserId!)"), isTrue);
      final sql = read('supabase/migrations/20260825_messaging_release.sql');
      expect(
        sql.contains('m.sender_id IS DISTINCT FROM v_uid'),
        isTrue,
      );
    });

    test('17. mark-read only clears already-unread inbound rows', () {
      final sql = read('supabase/migrations/20260825_messaging_release.sql');
      final fn = sql.substring(
        sql.indexOf('CREATE OR REPLACE FUNCTION public.mark_conversation_messages_read'),
      );
      expect(fn.contains('AND m.read_at IS NULL'), isTrue);
      expect(fn.contains('SET read_at = NOW()'), isTrue);
    });

    test('18. realtime never increments a counter, it refetches', () {
      // Counts are always a fresh server read, so duplicate events cannot
      // inflate them.
      expect(messagingPage.contains('_loadConversations(showLoading: false)'),
          isTrue);
      expect(messagingPage.contains('unreadCount++'), isFalse);
      expect(messagingPage.contains('unreadCount +='), isFalse);
    });

    test('19. deleted-for-everyone messages cannot hold a badge open', () {
      expect(
        repo.contains(".isFilter('deleted_for_everyone_at', null)"),
        isTrue,
      );
      // Both the per-conversation badge and the global nav badge.
      final matches = RegExp(r"isFilter\('deleted_for_everyone_at', null\)")
          .allMatches(repo)
          .length;
      expect(matches, greaterThanOrEqualTo(2));
    });

    test('20. a failed mark-read is distinguishable from success', () {
      expect(repo.contains('enum MarkReadOutcome'), isTrue);
      expect(repo.contains('MarkReadOutcome.unsupported'), isTrue);
      expect(repo.contains('MarkReadOutcome.failed'), isTrue);
      expect(repo.contains('MarkReadOutcome.success'), isTrue);
    });

    test('20b. missing-RPC detection does not swallow auth errors', () {
      final fn = repo.substring(
        repo.indexOf('bool _isMissingRpc'),
      );
      expect(
        fn.contains("code.startsWith('PGRST')"),
        isFalse,
        reason: 'PGRST301 (expired JWT) must not be read as "already read"',
      );
      expect(fn.contains("e.code == 'PGRST202'"), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // ERROR UX
  // ------------------------------------------------------------------
  group('sanitized error UX', () {
    const leaky = [
      'StorageException',
      'PostgrestException',
      'AuthException',
      'statusCode',
      'chat-attachments',
      'mark_conversation_messages_read',
      'delete_message_for_everyone',
      'Bucket not found',
    ];

    /// Lines that build user-visible text.
    List<String> uiTextLines(String src) {
      return src
          .split('\n')
          .where((l) => l.contains('Text(') || l.contains('SnackBar('))
          .toList();
    }

    test('21-24. no messaging UI line renders a backend identifier', () {
      for (final src in [chatScreen, messagingPage]) {
        for (final line in uiTextLines(src)) {
          for (final term in leaky) {
            expect(
              line.contains(term),
              isFalse,
              reason: 'user-visible line leaks "$term": ${line.trim()}',
            );
          }
        }
      }
    });

    test('23b. no messaging UI line interpolates a raw exception', () {
      final bad = RegExp(r"Text\([^)]*(\$e\b|\$error\b|\.toString\(\))");
      for (final src in [chatScreen, messagingPage]) {
        for (final line in uiTextLines(src)) {
          expect(
            bad.hasMatch(line),
            isFalse,
            reason: 'raw exception rendered: ${line.trim()}',
          );
        }
      }
    });

    test('24b. the migration filename is no longer thrown to the client', () {
      expect(
        storageService.contains('20260815_chat_attachments_private_bucket.sql'),
        isFalse,
      );
    });

    test('25-28. each media kind and text get their own sanitized copy', () {
      expect(
        MessagingErrorMessages.forMediaSend(ChatMediaKind.image, Exception('x')),
        'Image sending failed. Tap Retry.',
      );
      expect(
        MessagingErrorMessages.forMediaSend(ChatMediaKind.video, Exception('x')),
        'Video sending failed. Tap Retry.',
      );
      expect(
        MessagingErrorMessages.forMediaSend(
            ChatMediaKind.document, Exception('x')),
        'File sending failed. Tap Retry.',
      );
      expect(
        MessagingErrorMessages.forTextSend(Exception('x')),
        "Message couldn't be sent. Tap Retry.",
      );
    });

    test('25b. the failed bubble label matches the media kind', () {
      expect(MessagingErrorMessages.bubbleLabelFor(ChatMediaKind.image),
          'Image sending failed');
      expect(MessagingErrorMessages.bubbleLabelFor(ChatMediaKind.video),
          'Video sending failed');
      expect(MessagingErrorMessages.bubbleLabelFor(ChatMediaKind.document),
          'File sending failed');
      expect(chatScreen.contains('MessagingErrorMessages.bubbleLabelFor(kind)'),
          isTrue);
    });

    test('network failures map to the connectivity message', () {
      final sock = const SocketException('failed host lookup: xyz.supabase.co');
      expect(MessagingErrorMessages.isNetworkError(sock), isTrue);
      expect(
        MessagingErrorMessages.forMediaSend(ChatMediaKind.image, sock),
        'No internet connection. Check your connection and try again.',
      );
      expect(
        MessagingErrorMessages.forTextSend(TimeoutException('x')),
        'No internet connection. Check your connection and try again.',
      );
    });

    test('media access and delete failures are sanitized', () {
      expect(MessagingErrorMessages.forMediaAccess(Exception('404')),
          'Unable to load this attachment.');
      expect(MessagingErrorMessages.forDelete(Exception('rls')),
          "Couldn't delete message. Try again.");
      expect(MessagingErrorMessages.mediaUnavailable,
          'This attachment is no longer available.');
    });

    test('no mapped message echoes the underlying error text', () {
      const secret = 'Bucket not found chat-attachments 404';
      final produced = <String>[
        MessagingErrorMessages.forMediaSend(ChatMediaKind.image, secret),
        MessagingErrorMessages.forMediaSend(ChatMediaKind.video, secret),
        MessagingErrorMessages.forMediaSend(ChatMediaKind.document, secret),
        MessagingErrorMessages.forTextSend(secret),
        MessagingErrorMessages.forMediaAccess(secret),
        MessagingErrorMessages.forDelete(secret),
        MessagingErrorMessages.forGeneric(secret),
      ];
      for (final msg in produced) {
        expect(msg.contains('Bucket'), isFalse);
        expect(msg.contains('404'), isFalse);
        expect(msg.contains('chat-attachments'), isFalse);
      }
    });

    test('29. retry remains available after a sanitized failure', () {
      final catchBlock = chatScreen.substring(
        chatScreen.indexOf("MessagingErrorMessages.logMessagingError('sendAttachment'"),
      );
      expect(
        catchBlock.contains('uploadStatus: ChatUploadStatus.failed'),
        isTrue,
        reason: 'the bubble must stay retryable',
      );
      expect(chatScreen.contains('onPressed: widget.onRetry'), isTrue);
    });

    test('technical detail is logged only in debug builds', () {
      final util = read('lib/utils/messaging_error_messages.dart');
      expect(util.contains('if (!kDebugMode) return;'), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // REGRESSION GUARDS
  // ------------------------------------------------------------------
  group('regression guards', () {
    test('the notification/push pipeline is untouched by these files', () {
      final sql = read('supabase/migrations/20260825_messaging_release.sql');
      expect(sql.contains('trg_notify_on_new_message'), isTrue);
      // No client-side FCM or dispatcher changes in messaging UI.
      expect(chatScreen.contains('send-push-notification'), isFalse);
      expect(repo.contains('send-push-notification'), isFalse);
    });

    test('conversation ordering by activity is preserved', () {
      expect(repo.contains('sortConversationsByActivity'), isTrue);
      expect(repo.contains('conversationActivityAt'), isTrue);
      expect(messagingPage.contains('activityAt'), isTrue);
    });

    test('the optimistic badge clear preserves the sort key', () {
      final onTap = messagingPage.substring(
        messagingPage.indexOf('onTap: () async {'),
      );
      final clear = onTap.substring(0, onTap.indexOf('await Navigator.push'));
      expect(
        clear.contains('activityAt:'),
        isTrue,
        reason: 'dropping activityAt sends the conversation to the bottom',
      );
    });

    test('delete-for-me and delete-for-everyone RPCs still used', () {
      expect(repo.contains("'delete_message_for_everyone'"), isTrue);
      expect(repo.contains("'hide_message_for_me'"), isTrue);
    });
  });
}
