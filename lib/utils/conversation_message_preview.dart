import 'package:flutter/material.dart';

import '../repositories/messages_repository.dart';
import 'chat_attachment_rules.dart';

/// Kind of last-message preview shown in the conversation list.
enum ConversationPreviewKind {
  text,
  photo,
  video,
  document,
  voice,
  attachment,
  empty,
  deleted,
}

/// One-line preview for a conversation's latest message (no file downloads).
class ConversationMessagePreview {
  final String label;
  final ConversationPreviewKind kind;
  final bool isFromCurrentUser;

  const ConversationMessagePreview({
    required this.label,
    required this.kind,
    this.isFromCurrentUser = false,
  });

  String get displayText {
    if (kind == ConversationPreviewKind.empty) return label;
    if (isFromCurrentUser && kind != ConversationPreviewKind.deleted) {
      return 'You: $label';
    }
    return label;
  }

  /// Subtle leading icon for attachment previews; null for plain text.
  IconData? get icon {
    return switch (kind) {
      ConversationPreviewKind.photo => Icons.image_outlined,
      ConversationPreviewKind.video => Icons.videocam_outlined,
      ConversationPreviewKind.document => Icons.description_outlined,
      ConversationPreviewKind.voice => Icons.mic_none,
      ConversationPreviewKind.attachment => Icons.attach_file,
      ConversationPreviewKind.text ||
      ConversationPreviewKind.empty ||
      ConversationPreviewKind.deleted =>
        null,
    };
  }

  /// Build from a `messages` row already loaded for the conversation list.
  factory ConversationMessagePreview.fromMessage(
    Map<String, dynamic>? message, {
    String? currentUserId,
  }) {
    if (message == null) {
      return const ConversationMessagePreview(
        label: 'No messages yet',
        kind: ConversationPreviewKind.empty,
      );
    }

    if (MessagesRepository.isDeletedForEveryone(message)) {
      return ConversationMessagePreview(
        label: MessagesRepository.deletedMessagePlaceholder,
        kind: ConversationPreviewKind.deleted,
        isFromCurrentUser: _isFromCurrentUser(message, currentUserId),
      );
    }

    final content = (message['content'] as String?)?.trim() ?? '';
    final fromMe = _isFromCurrentUser(message, currentUserId);

    // Prefer non-empty caption/text even when an attachment is present.
    if (content.isNotEmpty) {
      return ConversationMessagePreview(
        label: content,
        kind: ConversationPreviewKind.text,
        isFromCurrentUser: fromMe,
      );
    }

    final mediaUrl = (message['media_url'] as String?)?.trim() ?? '';
    if (mediaUrl.isEmpty) {
      return ConversationMessagePreview(
        label: '',
        kind: ConversationPreviewKind.text,
        isFromCurrentUser: fromMe,
      );
    }

    final kind = _attachmentKind(message);
    return ConversationMessagePreview(
      label: _labelForKind(kind),
      kind: kind,
      isFromCurrentUser: fromMe,
    );
  }

  static bool _isFromCurrentUser(
    Map<String, dynamic> message,
    String? currentUserId,
  ) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return message['sender_id'] == currentUserId;
  }

  static ConversationPreviewKind _attachmentKind(Map<String, dynamic> message) {
    final mediaKind = (message['media_kind'] as String?)?.toLowerCase().trim();
    final mediaMime = (message['media_mime_type'] as String?)?.toLowerCase();
    final mediaUrl = (message['media_url'] as String?) ?? '';
    final mediaFileName = message['media_file_name'] as String?;
    final nameHint = mediaFileName ?? mediaUrl;

    if (mediaKind == 'image') return ConversationPreviewKind.photo;
    if (mediaKind == 'video') return ConversationPreviewKind.video;
    if (mediaKind == 'document') return ConversationPreviewKind.document;
    if (mediaKind == 'audio' || mediaKind == 'voice') {
      return ConversationPreviewKind.voice;
    }

    if (mediaMime != null && mediaMime.startsWith('image/')) {
      return ConversationPreviewKind.photo;
    }
    if (mediaMime != null && mediaMime.startsWith('video/')) {
      return ConversationPreviewKind.video;
    }
    if (mediaMime != null && mediaMime.startsWith('audio/')) {
      return ConversationPreviewKind.voice;
    }

    final looksLikeDoc = ChatAttachmentRules.isAllowedDocument(
      nameHint,
      mimeType: mediaMime,
    );
    final looksLikeImage = ChatAttachmentRules.isAllowedImage(
      nameHint,
      mimeType: mediaMime,
    );

    if (looksLikeImage) return ConversationPreviewKind.photo;
    if (looksLikeDoc) return ConversationPreviewKind.document;

    final lowerUrl = mediaUrl.toLowerCase();
    if (lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.webm')) {
      return ConversationPreviewKind.video;
    }

    // Unknown media with a URL — keep a neutral attachment label.
    return ConversationPreviewKind.attachment;
  }

  static String _labelForKind(ConversationPreviewKind kind) {
    return switch (kind) {
      ConversationPreviewKind.photo => 'Photo',
      ConversationPreviewKind.video => 'Video',
      ConversationPreviewKind.document => 'Document',
      ConversationPreviewKind.voice => 'Voice message',
      ConversationPreviewKind.attachment => 'Attachment',
      ConversationPreviewKind.text ||
      ConversationPreviewKind.empty ||
      ConversationPreviewKind.deleted =>
        '',
    };
  }
}
