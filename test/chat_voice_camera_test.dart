import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/utils/chat_voice_rules.dart';
import 'package:cotrainr/utils/conversation_message_preview.dart';
import 'package:cotrainr/utils/message_insert_payload.dart';

void main() {
  group('ChatVoiceRules', () {
    test('fileNameForDuration encodes and durationMsFromFileName parses', () {
      final name = ChatVoiceRules.fileNameForDuration(12345);
      expect(name, 'voice_12345ms.m4a');
      expect(ChatVoiceRules.durationMsFromFileName(name), 12345);
      expect(ChatVoiceRules.durationMsFromFileName('other.m4a'), isNull);
    });

    test('clamps filename duration to max', () {
      final name = ChatVoiceRules.fileNameForDuration(
        ChatVoiceRules.maxDurationMs + 5000,
      );
      expect(
        ChatVoiceRules.durationMsFromFileName(name),
        ChatVoiceRules.maxDurationMs,
      );
    });

    test('too short and max helpers', () {
      expect(ChatVoiceRules.isTooShort(999), isTrue);
      expect(ChatVoiceRules.isTooShort(1000), isFalse);
      expect(ChatVoiceRules.isAtMax(ChatVoiceRules.maxDurationMs), isTrue);
      expect(ChatVoiceRules.isAtMax(ChatVoiceRules.maxDurationMs - 1), isFalse);
    });

    test('formatDuration', () {
      expect(
        ChatVoiceRules.formatDuration(const Duration(seconds: 65)),
        '1:05',
      );
      expect(ChatVoiceRules.formatDuration(Duration.zero), '0:00');
    });
  });

  group('buildMessageInsertPayload audio', () {
    test('audio kind payload has non-empty media_kind', () {
      final payload = buildMessageInsertPayload(
        conversationId: 'c1',
        senderId: 'u1',
        content: '',
        mediaUrl: 'chat://u/chat/c/voice_1500ms.m4a',
        mediaKind: ChatVoiceRules.mediaKind,
        mediaFileName: ChatVoiceRules.fileNameForDuration(1500),
        mediaMimeType: ChatVoiceRules.mimeType,
        mediaSizeBytes: 4096,
      );

      expect(payload['media_kind'], 'audio');
      expect(payload['media_kind'], isNot(equals('')));
      expect(payload['media_file_name'], 'voice_1500ms.m4a');
      expect(payload['media_mime_type'], 'audio/mp4');
      expect(payload['media_url'], isNotEmpty);
      expect(payload['content'], '');
    });

    test('text-only still omits media', () {
      final payload = buildMessageInsertPayload(
        conversationId: 'c1',
        senderId: 'u1',
        content: 'hello',
      );
      expect(payload.containsKey('media_kind'), isFalse);
      expect(payload.containsKey('media_url'), isFalse);
    });

    test('image payload unchanged', () {
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
      expect(payload['media_kind'], 'image');
      expect(payload['media_file_name'], 'f.jpg');
      expect(payload['media_mime_type'], 'image/jpeg');
    });
  });

  group('ConversationMessagePreview voice', () {
    test('media_kind audio yields Voice message label', () {
      final preview = ConversationMessagePreview.fromMessage({
        'content': '',
        'media_url': 'chat://x/voice_2000ms.m4a',
        'media_kind': 'audio',
        'media_mime_type': 'audio/mp4',
        'media_file_name': 'voice_2000ms.m4a',
        'sender_id': 'other',
      });
      expect(preview.kind, ConversationPreviewKind.voice);
      expect(preview.label, 'Voice message');
      expect(preview.displayText, 'Voice message');
    });
  });

  group('chat_screen source contract', () {
    test('contains ImageSource.camera and ChatVoiceRules.mediaKind', () {
      final src = File(
        'lib/pages/messaging/chat_screen.dart',
      ).readAsStringSync();
      expect(src.contains('ImageSource.camera'), isTrue);
      expect(src.contains('ChatVoiceRules.mediaKind'), isTrue);
      expect(src.contains('[MSG_VOICE_START]'), isTrue);
      expect(src.contains('[MSG_CAMERA_START]'), isTrue);
    });
  });
}
