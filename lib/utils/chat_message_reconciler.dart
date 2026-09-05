/// Pure reconciliation helpers for chat bubbles keyed by canonical DB message id.
///
/// Optimistic rows use [localId] until [confirmOptimistic] replaces them with
/// the server [messageId]. Realtime echoes for known ids are ignored.
class ChatMessageReconciler {
  ChatMessageReconciler();

  final List<ReconciledChatMessage> messages = [];
  final Set<String> _canonicalIds = {};
  final Set<String> _localIds = {};

  Set<String> get canonicalIds => Set.unmodifiable(_canonicalIds);

  void replaceAll(List<ReconciledChatMessage> loaded) {
    messages
      ..clear()
      ..addAll(loaded);
    _canonicalIds
      ..clear()
      ..addAll(
        loaded
            .map((m) => m.messageId)
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );
    _localIds.clear();
  }

  /// Append an optimistic bubble. Returns the local correlation id.
  String addOptimistic({
    required String text,
    required bool isSent,
    required String time,
    String? imagePath,
    String? videoPath,
    String? documentPath,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    String? audioPath,
    int? audioDurationMs,
    DateTime? readAt,
    ChatUploadStatus uploadStatus = ChatUploadStatus.none,
    String? localId,
  }) {
    final id =
        localId ??
        'local_${DateTime.now().microsecondsSinceEpoch}_${messages.length}';
    _localIds.add(id);
    messages.add(
      ReconciledChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        localId: id,
        imagePath: imagePath,
        videoPath: videoPath,
        documentPath: documentPath,
        documentName: documentName,
        documentMime: documentMime,
        documentSizeBytes: documentSizeBytes,
        audioPath: audioPath,
        audioDurationMs: audioDurationMs,
        readAt: readAt,
        uploadStatus: uploadStatus,
      ),
    );
    return id;
  }

  /// Replace optimistic [localId] with the canonical DB message.
  /// Idempotent if Realtime already inserted [messageId].
  bool confirmOptimistic({
    required String localId,
    required String messageId,
    required String text,
    required bool isSent,
    required String time,
    String? imageUrl,
    String? videoUrl,
    String? documentUrl,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    String? audioUrl,
    int? audioDurationMs,
    DateTime? readAt,
  }) {
    if (messageId.isEmpty) return false;
    _canonicalIds.add(messageId);
    _localIds.remove(localId);
    messages.removeWhere((m) => m.localId == localId);

    if (_hasMessageId(messageId)) {
      if (readAt != null) {
        applyReadAt(messageId, readAt);
      }
      return true;
    }

    messages.add(
      ReconciledChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        messageId: messageId,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        documentUrl: documentUrl,
        documentName: documentName,
        documentMime: documentMime,
        documentSizeBytes: documentSizeBytes,
        audioUrl: audioUrl,
        audioDurationMs: audioDurationMs,
        readAt: readAt,
        uploadStatus: ChatUploadStatus.none,
      ),
    );
    return true;
  }

  bool updateOptimistic(
    String localId, {
    ChatUploadStatus? uploadStatus,
    double? uploadProgress,
    String? imageUrl,
    String? documentUrl,
    String? audioUrl,
  }) {
    final index = messages.indexWhere((m) => m.localId == localId);
    if (index < 0) return false;
    final m = messages[index];
    messages[index] = m.copyWith(
      uploadStatus: uploadStatus,
      uploadProgress: uploadProgress,
      imageUrl: imageUrl,
      documentUrl: documentUrl,
      audioUrl: audioUrl,
    );
    return true;
  }

  /// Remove a specific optimistic bubble (safe failure path).
  bool removeOptimistic(String localId) {
    _localIds.remove(localId);
    final index = messages.indexWhere((m) => m.localId == localId);
    if (index < 0) return false;
    messages.removeAt(index);
    return true;
  }

  /// Apply a Realtime/server insert. Returns false if already known (no-op).
  bool upsertCanonical({
    required String messageId,
    required String text,
    required bool isSent,
    required String time,
    String? imageUrl,
    String? videoUrl,
    String? documentUrl,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    String? audioUrl,
    int? audioDurationMs,
    DateTime? readAt,
  }) {
    if (messageId.isEmpty) return false;
    if (_canonicalIds.contains(messageId) || _hasMessageId(messageId)) {
      if (readAt != null) {
        applyReadAt(messageId, readAt);
      }
      return false;
    }
    _canonicalIds.add(messageId);
    messages.add(
      ReconciledChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        messageId: messageId,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        documentUrl: documentUrl,
        documentName: documentName,
        documentMime: documentMime,
        documentSizeBytes: documentSizeBytes,
        audioUrl: audioUrl,
        audioDurationMs: audioDurationMs,
        readAt: readAt,
      ),
    );
    return true;
  }

  /// Apply a server "deleted for everyone" tombstone. Clears text and every
  /// attachment reference so the bubble can never render the original.
  bool markDeletedForEveryone(String messageId, DateTime deletedAt) {
    if (messageId.isEmpty) return false;
    final index = messages.indexWhere((m) => m.messageId == messageId);
    if (index < 0) return false;
    final m = messages[index];
    if (m.deletedForEveryoneAt != null) return false;
    messages[index] = m.asDeletedForEveryone(deletedAt);
    return true;
  }

  /// Drop a confirmed server message locally ("Delete for me"). The id is
  /// released so a later canonical fetch can legitimately re-add it.
  bool removeCanonical(String messageId) {
    if (messageId.isEmpty) return false;
    final index = messages.indexWhere((m) => m.messageId == messageId);
    _canonicalIds.remove(messageId);
    if (index < 0) return false;
    messages.removeAt(index);
    return true;
  }

  /// Apply `read_at` from a Realtime UPDATE (Seen indicator).
  bool applyReadAt(String messageId, DateTime readAt) {
    if (messageId.isEmpty) return false;
    final index = messages.indexWhere((m) => m.messageId == messageId);
    if (index < 0) return false;
    final m = messages[index];
    if (m.readAt != null) return false;
    messages[index] = m.copyWith(readAt: readAt);
    return true;
  }

  bool _hasMessageId(String messageId) =>
      messages.any((m) => m.messageId == messageId);
}

enum ChatUploadStatus { none, uploading, failed }

/// Tombstone rendered in place of a message deleted for everyone.
const String kDeletedMessageText = 'This message was deleted';

class ReconciledChatMessage {
  final String text;
  final bool isSent;
  final String time;
  final String? messageId;
  final String? localId;
  final String? imagePath;
  final String? videoPath;
  final String? imageUrl;
  final String? videoUrl;
  final String? documentPath;
  final String? documentUrl;
  final String? documentName;
  final String? documentMime;
  final int? documentSizeBytes;
  final String? audioPath;
  final String? audioUrl;
  final int? audioDurationMs;
  final DateTime? readAt;
  final DateTime? deletedForEveryoneAt;
  final ChatUploadStatus uploadStatus;
  final double uploadProgress;

  const ReconciledChatMessage({
    required this.text,
    required this.isSent,
    required this.time,
    this.messageId,
    this.localId,
    this.imagePath,
    this.videoPath,
    this.imageUrl,
    this.videoUrl,
    this.documentPath,
    this.documentUrl,
    this.documentName,
    this.documentMime,
    this.documentSizeBytes,
    this.audioPath,
    this.audioUrl,
    this.audioDurationMs,
    this.readAt,
    this.deletedForEveryoneAt,
    this.uploadStatus = ChatUploadStatus.none,
    this.uploadProgress = 0,
  });

  bool get isSeen => readAt != null;

  bool get isDeletedForEveryone => deletedForEveryoneAt != null;

  /// Rebuild as a tombstone. Built from the constructor rather than [copyWith]
  /// so media references are actually cleared, not merged.
  ReconciledChatMessage asDeletedForEveryone(DateTime deletedAt) {
    return ReconciledChatMessage(
      text: kDeletedMessageText,
      isSent: isSent,
      time: time,
      messageId: messageId,
      localId: localId,
      readAt: readAt,
      deletedForEveryoneAt: deletedAt,
    );
  }

  bool get isAudio =>
      (audioUrl != null && audioUrl!.isNotEmpty) ||
      (audioPath != null && audioPath!.isNotEmpty);

  bool get isDocument =>
      (documentUrl != null && documentUrl!.isNotEmpty) ||
      (documentPath != null && documentPath!.isNotEmpty) ||
      (documentName != null &&
          documentName!.isNotEmpty &&
          imageUrl == null &&
          imagePath == null &&
          videoUrl == null &&
          videoPath == null &&
          audioUrl == null &&
          audioPath == null);

  ReconciledChatMessage copyWith({
    String? text,
    bool? isSent,
    String? time,
    String? messageId,
    String? localId,
    String? imagePath,
    String? videoPath,
    String? imageUrl,
    String? videoUrl,
    String? documentPath,
    String? documentUrl,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    String? audioPath,
    String? audioUrl,
    int? audioDurationMs,
    DateTime? readAt,
    DateTime? deletedForEveryoneAt,
    ChatUploadStatus? uploadStatus,
    double? uploadProgress,
  }) {
    return ReconciledChatMessage(
      text: text ?? this.text,
      isSent: isSent ?? this.isSent,
      time: time ?? this.time,
      messageId: messageId ?? this.messageId,
      localId: localId ?? this.localId,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      documentPath: documentPath ?? this.documentPath,
      documentUrl: documentUrl ?? this.documentUrl,
      documentName: documentName ?? this.documentName,
      documentMime: documentMime ?? this.documentMime,
      documentSizeBytes: documentSizeBytes ?? this.documentSizeBytes,
      audioPath: audioPath ?? this.audioPath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      readAt: readAt ?? this.readAt,
      deletedForEveryoneAt: deletedForEveryoneAt ?? this.deletedForEveryoneAt,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}
