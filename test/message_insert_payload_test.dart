import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/utils/message_insert_payload.dart';

void main() {
  group('buildMessageInsertPayload', () {
    test('text-only omits media fields and never emits empty media_kind', () {
      final payload = buildMessageInsertPayload(
        conversationId: 'c1',
        senderId: 'u1',
        content: 'hello',
      );

      expect(payload.keys.toList(), [
        'conversation_id',
        'sender_id',
        'content',
      ]);
      expect(payload.containsKey('media_kind'), isFalse);
      expect(payload.containsKey('media_url'), isFalse);
      expect(payload.containsKey('media_file_name'), isFalse);
      expect(payload.containsKey('media_mime_type'), isFalse);
      expect(payload.containsKey('media_size_bytes'), isFalse);
      expect(payload.values.whereType<String>().contains(''), isFalse);
    });

    test('empty-string media placeholders are omitted (not sent as "")', () {
      final payload = buildMessageInsertPayload(
        conversationId: 'c1',
        senderId: 'u1',
        content: 'hello',
        mediaUrl: '',
        mediaKind: '',
        mediaFileName: '   ',
        mediaMimeType: '',
        mediaSizeBytes: null,
      );

      expect(payload.containsKey('media_kind'), isFalse);
      expect(payload['media_kind'], isNot(equals('')));
      expect(payload.containsKey('media_url'), isFalse);
      expect(payload.keys, ['conversation_id', 'sender_id', 'content']);
    });

    test('valid image/media payload keeps media fields', () {
      final payload = buildMessageInsertPayload(
        conversationId: 'c1',
        senderId: 'u1',
        content: '',
        mediaUrl: 'chat://u/chat/c/f.jpg',
        mediaKind: 'image',
        mediaFileName: 'f.jpg',
        mediaMimeType: 'image/jpeg',
        mediaSizeBytes: 1200,
      );

      expect(payload['media_url'], 'chat://u/chat/c/f.jpg');
      expect(payload['media_kind'], 'image');
      expect(payload['media_file_name'], 'f.jpg');
      expect(payload['media_mime_type'], 'image/jpeg');
      expect(payload['media_size_bytes'], 1200);
      expect(payload['media_kind'], isNot(equals('')));
    });

    test('media url with empty kind omits media_kind only', () {
      final payload = buildMessageInsertPayload(
        conversationId: 'c1',
        senderId: 'u1',
        content: 'cap',
        mediaUrl: 'chat://x',
        mediaKind: '',
      );
      expect(payload['media_url'], 'chat://x');
      expect(payload.containsKey('media_kind'), isFalse);
    });
  });

  group('notify trigger COALESCE contract', () {
    test('fix migration casts media_kind to text before coalesce', () {
      final sql = File(
        'supabase/migrations/20260905_fix_notify_on_new_message_media_kind.sql',
      ).readAsStringSync();
      expect(sql.contains('NEW.media_kind::text'), isTrue);
      // Executable assignment must cast before coalesce (comments may mention the bug).
      expect(
        sql.contains("v_kind := COALESCE(NEW.media_kind::text, '');"),
        isTrue,
      );
      expect(
        sql.contains("v_kind := COALESCE(NEW.media_kind, '');"),
        isFalse,
      );
    });
  });
}
