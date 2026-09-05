/// Builds the `messages` INSERT map for [MessagesRepository.sendMessage].
///
/// Text-only messages must never include empty-string placeholders for optional
/// media columns (`media_kind` is a Postgres enum — `""` is invalid).
Map<String, dynamic> buildMessageInsertPayload({
  required String conversationId,
  required String senderId,
  required String content,
  String? mediaUrl,
  String? mediaKind,
  String? mediaFileName,
  String? mediaMimeType,
  int? mediaSizeBytes,
}) {
  final payload = <String, dynamic>{
    'conversation_id': conversationId,
    'sender_id': senderId,
    'content': content,
  };

  final url = _meaningfulString(mediaUrl);
  if (url == null) {
    // Text-only: omit all optional media fields (SQL NULL via omission).
    return payload;
  }

  payload['media_url'] = url;

  final kind = _meaningfulString(mediaKind);
  if (kind != null) {
    payload['media_kind'] = kind;
  }

  final fileName = _meaningfulString(mediaFileName);
  if (fileName != null) {
    payload['media_file_name'] = fileName;
  }

  final mime = _meaningfulString(mediaMimeType);
  if (mime != null) {
    payload['media_mime_type'] = mime;
  }

  if (mediaSizeBytes != null) {
    payload['media_size_bytes'] = mediaSizeBytes;
  }

  return payload;
}

String? _meaningfulString(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}
